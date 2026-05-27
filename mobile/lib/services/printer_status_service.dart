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

  // ── LAN-first state ──────────────────────────────────────────────────────
  // The printer's last-known LAN URL is fetched from /status (Pi reports
  // local_ip + http_port). When set, the service tries LAN before the
  // Cloudflare tunnel. After 3 consecutive LAN failures we back off for
  // 5 minutes so off-LAN polling doesn't waste 2s per cycle.
  //
  // `_currentLanUrl` is a mutable copy initialised from the PrinterConfig
  // snapshot. Subsequent /status responses update it in-place so the very
  // next poll uses the freshly-learned LAN URL. Without this the service
  // would be stuck on the construction-time snapshot forever.
  String?   _currentLanUrl;
  int       _lanFailureStreak = 0;
  DateTime? _skipLanUntil;

  PrinterStatusService(this.config) : _currentLanUrl = config.lanUrl;

  Stream<PrinterStatus> get stream => _controller.stream;

  // ── v0.2.x compat stubs (PrinterTile still subscribes to these) ─────────
  //
  // The dual-path "Loading Local…" / "Loading Tunnel…" UI no longer makes
  // sense in v0.3 since there's only one path (Supabase-mediated tunnel).
  // We expose empty streams so existing listeners don't crash.

  Stream<String> get probePhase       => const Stream<String>.empty();
  Stream<String> get tunnelUrlUpdates => const Stream<String>.empty();
  String?        get uiType           => _uiType;

  // ── UI-type detection (Mainsail vs Fluidd) ───────────────────────────────
  // The tile renders the appropriate logo as a webcam placeholder when no
  // camera is configured. Detected once per service lifetime by fetching
  // the root page and sniffing the HTML for "mainsail" or "fluidd".
  String? _uiType;
  bool    _uiTypeChecked = false;

  Future<void> _detectUiType(String baseUrl, String accessToken) async {
    _uiTypeChecked = true;
    try {
      final uri      = Uri.parse('$baseUrl/');
      // In v0.4 the tunnel-side Mainsail root is gated by the auth proxy;
      // we attach the EdDSA token. On LAN the header is ignored.
      final response = await _authedGet(
          uri, accessToken,
          timeout: const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        if (body.contains('mainsail')) {
          _uiType = 'mainsail';
        } else if (body.contains('fluidd')) {
          _uiType = 'fluidd';
        }
      }
    } catch (_) {
      // Detection failed — retry on next successful poll
      _uiTypeChecked = false;
    }
  }

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

    // 3. LAN-first when we have a cached URL and haven't been failing
    //    too hard. Same EdDSA token works on LAN or tunnel.
    final lanUrl = _currentLanUrl;
    final canTryLan = lanUrl != null &&
        (_skipLanUntil == null || DateTime.now().isAfter(_skipLanUntil!));
    if (canTryLan) {
      final lan = await _tryMoongateEndpoint(
          baseUrl: lanUrl, access: access, isLan: true);
      if (lan != null) {
        _lanFailureStreak = 0;
        _skipLanUntil     = null;
        if (!_disposed) _controller.add(lan);
        return;
      }
      _lanFailureStreak++;
      if (_lanFailureStreak >= 3) {
        _skipLanUntil = DateTime.now().add(const Duration(minutes: 5));
      }
    }

    // 4. Tunnel via Cloudflare
    final tunnelStatus =
        await _tryMoongateEndpoint(baseUrl: access.tunnelUrl, access: access, isLan: false);
    if (tunnelStatus != null) {
      if (!_disposed) _controller.add(tunnelStatus);
      return;
    }

    // 5. Maybe the token got invalidated server-side. Drop cache and
    //    try once more with a fresh token before declaring offline.
    PrinterAccessCache.instance.invalidate(config.id);
    try {
      access = await PrinterAccessCache.instance.get(config.id);
    } catch (_) {
      if (!_disposed) _controller.add(PrinterStatus.offline);
      return;
    }
    final retry =
        await _tryMoongateEndpoint(baseUrl: access.tunnelUrl, access: access, isLan: false);
    if (!_disposed) _controller.add(retry ?? PrinterStatus.offline);
  }

  // ── Authed GET helper ────────────────────────────────────────────────────
  // v0.4 puts an EdDSA auth proxy in front of Moonraker on the tunnel
  // side; un-authed calls to /printer/* and /server/* return 401. We
  // attach the access token as Authorization: Bearer on every tunnel-side
  // GET. On the LAN side the header is ignored — nginx and Moonraker
  // don't read it (Moonraker has its own ?token= mechanism and trusts the
  // LAN subnet by default).
  Future<http.Response> _authedGet(
    Uri uri,
    String accessToken, {
    required Duration timeout,
  }) {
    return http
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(timeout);
  }

  // ── Chamber sensor discovery (one call per service lifetime) ─────────────

  Future<void> _discoverChamberSensor(PrinterAccess access) async {
    try {
      final uri      = Uri.parse(
          '${access.tunnelUrl}/printer/objects/list');
      final response = await _authedGet(
          uri, access.accessToken,
          timeout: const Duration(seconds: 5));
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
      String baseUrl, String accessToken, String? filename) async {
    if (filename == null || filename.isEmpty) return;
    if (filename == _metadataFilename) return;
    _estimatedPrintSeconds = null;
    _metadataFilename      = null;
    try {
      final encoded  = Uri.encodeComponent(filename);
      final uri      = Uri.parse(
          '$baseUrl/server/files/metadata?filename=$encoded');
      final response = await _authedGet(
          uri, accessToken,
          timeout: const Duration(seconds: 5));
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

  Future<PrinterStatus?> _tryMoongateEndpoint({
    required String        baseUrl,
    required PrinterAccess access,
    required bool          isLan,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/server/moongate/status?mg_token=${Uri.encodeComponent(access.accessToken)}',
      );
      // LAN: fast-fail at 2s so off-LAN polling doesn't stall.
      // Tunnel: 8s for Cloudflare Quick Tunnel cold-start latency.
      final timeout = isLan
          ? const Duration(seconds: 2)
          : const Duration(seconds: 8);
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode == 401) return null;
      if (response.statusCode != 200) return null;

      final body   = jsonDecode(response.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>;
      final status = Map<String, dynamic>.from(
          result['status'] as Map<String, dynamic>);

      if (_chamberKey != null && status[_chamberKey!] == null) {
        await _supplementaryChamberQuery(baseUrl, access.accessToken, status);
      }
      if (status['display_status'] == null ||
          status['virtual_sdcard'] == null) {
        await _supplementaryProgressQuery(baseUrl, access.accessToken, status);
      }

      final stats = status['print_stats'] as Map<String, dynamic>? ?? {};
      if (stats['state'] == 'printing') {
        await _fetchFileMetadata(
            baseUrl, access.accessToken, stats['filename'] as String?);
      }

      // Fire-and-forget UI detection on the first successful connection so
      // the tile knows whether to show the Mainsail or Fluidd logo when no
      // webcam is configured.
      if (!_uiTypeChecked) _detectUiType(baseUrl, access.accessToken);

      return _parseStatus(status: status, moongateResult: result, isLan: isLan);
    } catch (_) {
      return null;
    }
  }

  Future<void> _supplementaryChamberQuery(
      String baseUrl, String accessToken, Map<String, dynamic> status) async {
    try {
      final encoded  = Uri.encodeComponent(_chamberKey!);
      final uri      = Uri.parse(
          '$baseUrl/printer/objects/query?$encoded');
      final response = await _authedGet(
          uri, accessToken,
          timeout: const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final s    = body['result']?['status'] as Map<String, dynamic>?;
        final data = s?[_chamberKey!];
        if (data != null) status[_chamberKey!] = data;
      }
    } catch (_) {}
  }

  Future<void> _supplementaryProgressQuery(
      String baseUrl, String accessToken, Map<String, dynamic> status) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/printer/objects/query?display_status&virtual_sdcard');
      final response = await _authedGet(
          uri, accessToken,
          timeout: const Duration(seconds: 5));
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
    required bool                 isLan,
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
    // Also pick up the Pi's local_ip if it surfaced, so future polls can
    // try LAN first.
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

      final lip  = moongateResult['local_ip']  as String?;
      final port = (moongateResult['http_port'] as num?)?.toInt() ?? 80;
      if (lip != null && lip.isNotEmpty && lip != 'localhost') {
        final newLanUrl = port == 80 ? 'http://$lip' : 'http://$lip:$port';
        // Update the service's mutable copy IMMEDIATELY so the very next
        // poll tries LAN first. Also persist to the registry for cold-start.
        _currentLanUrl = newLanUrl;
        PrinterRegistry.instance.updateLanUrl(config.id, newLanUrl).ignore();
      }
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
      connection:         isLan ? PrinterConnection.local : PrinterConnection.remote,
      webcamSnapshotPath: moongateResult?['webcam_snapshot_path'] as String?,
      webcamFlipH:     (moongateResult?['webcam_flip_horizontal'] as bool?) ?? false,
      webcamFlipV:     (moongateResult?['webcam_flip_vertical']   as bool?) ?? false,
      webcamRotation:  (moongateResult?['webcam_rotation']        as num?)?.toInt() ?? 0,
      webcamTargetFps: (moongateResult?['webcam_target_fps']      as num?)?.toInt() ?? 15,
    );
  }
}
