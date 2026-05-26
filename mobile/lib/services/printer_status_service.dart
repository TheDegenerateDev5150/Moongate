import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;

import '../models/printer_config.dart';
import 'printer_access_cache.dart';
import 'printer_registry.dart';
import 'supabase_service.dart';

/// Polls the Moongate plugin's /server/moongate/status endpoint for one
/// printer.
///
/// v0.3.0 changes from v0.2.x:
///   • There is no longer any local-IP / tunnel candidate logic. The Pi
///     is only reachable via the tunnel URL that Supabase hands out from
///     /printer-access. The plugin endpoint validates the EdDSA token we
///     attach.
///   • Before every poll the service asks [PrinterAccessCache] for a
///     fresh `{tunnel_url, access_token}`. The cache reuses the token
///     until ~30s before its 5-min TTL, then refreshes via Supabase.
///   • On 401 from the Pi we invalidate the access entry and retry once
///     — the token may be expired or revoked.
class PrinterStatusService {
  final PrinterConfig config;

  final _controller = StreamController<PrinterStatus>.broadcast();
  Timer? _timer;
  bool _disposed = false;
  bool _polling  = false;

  // ── Chamber sensor discovery (kept from v0.2.x — same logic) ─────────────
  String? _chamberKey;
  bool    _chamberDiscovered = false;

  // ── File-metadata cache for accurate progress (kept from v0.2.x) ─────────
  double? _estimatedPrintSeconds;
  String? _metadataFilename;

  PrinterStatusService(this.config);

  Stream<PrinterStatus> get stream => _controller.stream;

  // ── v0.2.x compat stubs (PrinterTile still subscribes to these) ─────────
  //
  // The dual-path "Loading Local…" / "Loading Tunnel…" UI no longer makes
  // sense in v0.3 since there's only one path (Supabase-mediated tunnel).
  // We expose empty streams so existing listeners don't crash.

  Stream<String> get probePhase       => const Stream<String>.empty();
  Stream<String> get tunnelUrlUpdates => const Stream<String>.empty();
  String?         get uiType          => null;

  void start({Duration interval = const Duration(seconds: 4)}) {
    _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
  }

  void _log(String msg) => dev.log(msg, name: 'MOONGATE/STATUS/${config.id.substring(0, 8)}');

  Future<void> _poll() async {
    if (_disposed || _polling) return;
    _polling = true;
    try {
      await _doPoll();
    } finally {
      _polling = false;
    }
  }

  Future<void> _doPoll() async {
    if (!SupabaseService.instance.ready) {
      // Supabase isn't authenticated yet (cold start, no network).
      if (!_disposed) _controller.add(PrinterStatus.offline);
      return;
    }

    // 1. Fresh access token + tunnel URL from Supabase
    PrinterAccess access;
    try {
      access = await PrinterAccessCache.instance.get(config.id);
    } on PrinterUnavailableException {
      // Pi hasn't sent its first heartbeat yet.
      if (!_disposed) _controller.add(PrinterStatus.startingUp);
      return;
    } on PrinterNotFoundException {
      _log('Printer not found in Supabase — emitting offline');
      if (!_disposed) _controller.add(PrinterStatus.offline);
      return;
    } catch (e) {
      _log('Access fetch failed: $e');
      if (!_disposed) _controller.add(PrinterStatus.offline);
      return;
    }

    // 2. Discover chamber sensor on first reach
    if (!_chamberDiscovered) {
      await _discoverChamberSensor(access);
    }

    // 3. Hit the Moongate plugin — one shot, no fallback path needed
    final status = await _tryMoongateEndpoint(access);
    if (status != null) {
      if (!_disposed) _controller.add(status);
      return;
    }

    // 4. Maybe the token got invalidated server-side. Drop cache and
    //    try once more with a fresh token before declaring offline.
    PrinterAccessCache.instance.invalidate(config.id);
    try {
      access = await PrinterAccessCache.instance.get(config.id);
    } catch (_) {
      if (!_disposed) _controller.add(PrinterStatus.offline);
      return;
    }
    final retry = await _tryMoongateEndpoint(access);
    if (!_disposed) _controller.add(retry ?? PrinterStatus.offline);
  }

  // ── Chamber sensor discovery (one call per service lifetime) ─────────────

  Future<void> _discoverChamberSensor(PrinterAccess access) async {
    try {
      final uri      = Uri.parse(
          '${access.tunnelUrl}/printer/objects/list');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body    = jsonDecode(response.body) as Map<String, dynamic>;
        final objects =
            (body['result']?['objects'] as List<dynamic>?) ?? [];
        for (final obj in objects) {
          final key = obj.toString();
          if ((key.startsWith('temperature_sensor ') ||
               key.startsWith('heater_generic ') ||
               key.startsWith('temperature_fan ')) &&
              key.toLowerCase().contains('chamber')) {
            _chamberKey = key;
            break;
          }
        }
      }
      _chamberDiscovered = true;
    } catch (_) {
      // Network blip — retry next poll.
    }
  }

  // ── File metadata for accurate progress (kept from v0.2.x) ───────────────

  Future<void> _fetchFileMetadata(
      String tunnelUrl, String? filename) async {
    if (filename == null || filename.isEmpty) return;
    if (filename == _metadataFilename) return;
    _estimatedPrintSeconds = null;
    _metadataFilename      = null;
    try {
      final encoded  = Uri.encodeComponent(filename);
      final uri      = Uri.parse(
          '$tunnelUrl/server/files/metadata?filename=$encoded');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body      = jsonDecode(response.body) as Map<String, dynamic>;
        final estimated =
            (body['result']?['estimated_time'] as num?)?.toDouble();
        if (estimated != null && estimated > 0) {
          _estimatedPrintSeconds = estimated;
          _metadataFilename      = filename;
        }
      }
    } catch (_) {}
  }

  // ── Moongate plugin endpoint ─────────────────────────────────────────────

  Future<PrinterStatus?> _tryMoongateEndpoint(PrinterAccess access) async {
    try {
      final uri = Uri.parse(
        '${access.tunnelUrl}/server/moongate/status?mg_token=${Uri.encodeComponent(access.accessToken)}',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 401) {
        // Plugin rejected the token — caller drops the cache and retries.
        return null;
      }
      if (response.statusCode != 200) return null;

      final body   = jsonDecode(response.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>;
      final status = Map<String, dynamic>.from(
          result['status'] as Map<String, dynamic>);

      // Supplementary queries for older plugin builds that don't include
      // chamber / display_status / virtual_sdcard in their status response.
      if (_chamberKey != null && status[_chamberKey!] == null) {
        await _supplementaryChamberQuery(access.tunnelUrl, status);
      }
      if (status['display_status'] == null ||
          status['virtual_sdcard'] == null) {
        await _supplementaryProgressQuery(access.tunnelUrl, status);
      }

      // Slicer estimated_time → progress = print_duration / estimated_time
      final stats = status['print_stats'] as Map<String, dynamic>? ?? {};
      if (stats['state'] == 'printing') {
        await _fetchFileMetadata(
            access.tunnelUrl, stats['filename'] as String?);
      }

      return _parseStatus(status: status, moongateResult: result);
    } catch (_) {
      return null;
    }
  }

  Future<void> _supplementaryChamberQuery(
      String tunnelUrl, Map<String, dynamic> status) async {
    try {
      final encoded  = Uri.encodeComponent(_chamberKey!);
      final uri      = Uri.parse(
          '$tunnelUrl/printer/objects/query?$encoded');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final s    = body['result']?['status'] as Map<String, dynamic>?;
        final data = s?[_chamberKey!];
        if (data != null) status[_chamberKey!] = data;
      }
    } catch (_) {}
  }

  Future<void> _supplementaryProgressQuery(
      String tunnelUrl, Map<String, dynamic> status) async {
    try {
      final uri = Uri.parse(
          '$tunnelUrl/printer/objects/query?display_status&virtual_sdcard');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final s    = body['result']?['status'] as Map<String, dynamic>?;
        if (s != null) {
          if (status['display_status'] == null && s['display_status'] != null) {
            status['display_status'] = s['display_status'];
          }
          if (status['virtual_sdcard'] == null && s['virtual_sdcard'] != null) {
            status['virtual_sdcard'] = s['virtual_sdcard'];
          }
        }
      }
    } catch (_) {}
  }

  // ── Shared status parser (unchanged from v0.2.x logic) ───────────────────

  PrinterStatus _parseStatus({
    required Map<String, dynamic> status,
    required Map<String, dynamic>? moongateResult,
  }) {
    final printStats = status['print_stats'] as Map<String, dynamic>? ?? {};
    final extruder   = status['extruder']    as Map<String, dynamic>? ?? {};
    final heaterBed  = status['heater_bed']  as Map<String, dynamic>? ?? {};

    Map<String, dynamic>? chamberSensor = _chamberKey != null
        ? status[_chamberKey!] as Map<String, dynamic>?
        : null;
    chamberSensor ??=
        (status['temperature_sensor chamber'] ??
         status['temperature_sensor CHAMBER'] ??
         status['temperature_sensor chamber_temp'] ??
         status['temperature_sensor CHAMBER_TEMP'] ??
         status['heater_generic chamber'] ??
         status['heater_generic CHAMBER'] ??
         status['temperature_fan chamber'] ??
         status['temperature_fan CHAMBER']) as Map<String, dynamic>?;

    final displayStatus = status['display_status'] as Map<String, dynamic>? ?? {};
    final virtualSdcard = status['virtual_sdcard'] as Map<String, dynamic>? ?? {};

    final state = (printStats['state'] as String?) ?? 'startup';

    final double printDuration =
        (printStats['print_duration'] as num?)?.toDouble() ?? 0.0;
    final double displayProg =
        (displayStatus['progress'] as num?)?.toDouble() ?? 0.0;
    final double sdcardProg =
        (virtualSdcard['progress'] as num?)?.toDouble() ?? 0.0;

    final double progress;
    if (_estimatedPrintSeconds != null &&
        _estimatedPrintSeconds! > 0 &&
        printDuration > 0 &&
        state == 'printing') {
      progress = (printDuration / _estimatedPrintSeconds!).clamp(0.0, 1.0);
    } else if (displayProg > 0.0) {
      progress = displayProg.clamp(0.0, 1.0);
    } else if (sdcardProg > 0.0) {
      progress = sdcardProg.clamp(0.0, 1.0);
    } else {
      progress = 0.0;
    }

    // Persist webcam transform info — keeps the tile correct on next launch.
    if (moongateResult != null) {
      final flipH    = (moongateResult['webcam_flip_horizontal'] as bool?) ?? false;
      final flipV    = (moongateResult['webcam_flip_vertical']   as bool?) ?? false;
      final rotation = (moongateResult['webcam_rotation']    as num?)?.toInt() ?? 0;
      final fps      = (moongateResult['webcam_target_fps']  as num?)?.toInt() ?? 15;
      PrinterRegistry.instance.updateWebcamInfo(
        config.id,
        flipH:     flipH,
        flipV:     flipV,
        rotation:  rotation,
        targetFps: fps,
      ).ignore();
    }

    return PrinterStatus(
      state:              state,
      progress:           progress,
      hotendTemp:         (extruder['temperature']       as num?)?.toDouble() ?? 0,
      hotendTarget:       (extruder['target']            as num?)?.toDouble() ?? 0,
      bedTemp:            (heaterBed['temperature']      as num?)?.toDouble() ?? 0,
      bedTarget:          (heaterBed['target']           as num?)?.toDouble() ?? 0,
      chamberTemp:        (chamberSensor?['temperature'] as num?)?.toDouble() ?? 0,
      chamberTarget:      (chamberSensor?['target']      as num?)?.toDouble() ?? 0,
      filename:           printStats['filename']         as String?,
      connection:         PrinterConnection.remote,
      webcamSnapshotPath: moongateResult?['webcam_snapshot_path'] as String?,
      webcamFlipH:     (moongateResult?['webcam_flip_horizontal'] as bool?) ?? false,
      webcamFlipV:     (moongateResult?['webcam_flip_vertical']   as bool?) ?? false,
      webcamRotation:  (moongateResult?['webcam_rotation']        as num?)?.toInt() ?? 0,
      webcamTargetFps: (moongateResult?['webcam_target_fps']      as num?)?.toInt() ?? 15,
    );
  }
}
