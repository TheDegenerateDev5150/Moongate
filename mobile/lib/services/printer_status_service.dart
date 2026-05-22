import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/printer_config.dart';
import 'printer_registry.dart';

/// Polls Moonraker's REST API to get current printer status.
/// One instance per printer tile; disposed when the tile leaves the tree.
///
/// Connection strategy (per candidate host — local first, then tunnel):
///   1. Try the Moongate plugin endpoint (/server/moongate/status).
///      Returns rich data: tunnel URL, webcam path, full print stats.
///   2. Fall back to the native Moonraker object query API.
///      Works even without the Moongate plugin installed.
///
/// This means tiles always show real status even if the plugin is missing,
/// and each tile is fully independent — it probes its own IPs/tokens.
class PrinterStatusService {
  final PrinterConfig config;
  final _controller          = StreamController<PrinterStatus>.broadcast();
  final _tunnelUrlController = StreamController<String>.broadcast();
  Timer? _timer;
  bool _disposed = false;

  PrinterStatusService(this.config);

  Stream<PrinterStatus> get stream => _controller.stream;

  /// Emits the updated tunnel URL whenever the Pi reports a URL that differs
  /// from what is stored in the config.  Subscribe in the webcam widget to
  /// immediately start using the fresh URL within the same session.
  Stream<String> get tunnelUrlUpdates => _tunnelUrlController.stream;

  void start({Duration interval = const Duration(seconds: 4)}) {
    _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
    _tunnelUrlController.close();
  }

  Future<void> _poll() async {
    if (_disposed) return;

    // Try local first, then the Cloudflare tunnel.
    // config.host  = full local URL:  "http://192.168.x.x:80"
    // config.remoteHost = tunnel URL: "https://xxxx.trycloudflare.com"
    final candidates = [
      config.host,
      if (config.remoteHost != null) config.remoteHost!,
    ];

    for (final baseUrl in candidates) {
      // ── 1. Moongate plugin endpoint (preferred) ──────────────────────────
      final moongate = await _tryMoongateEndpoint(baseUrl);
      if (moongate != null) {
        if (!_disposed) _controller.add(moongate);
        return;
      }

      // ── 2. Native Moonraker API fallback ─────────────────────────────────
      //   Works without the Moongate plugin so users still see real status
      //   even on printers where the plugin isn't installed or pairing failed.
      final native = await _tryNativeEndpoint(baseUrl);
      if (native != null) {
        if (!_disposed) _controller.add(native);
        return;
      }
    }

    // All candidates (both endpoints) failed — printer is unreachable.
    if (!_disposed) _controller.add(PrinterStatus.offline);
  }

  // ── Moongate plugin endpoint ───────────────────────────────────────────────

  Future<PrinterStatus?> _tryMoongateEndpoint(String baseUrl) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/server/moongate/status?mg_token=${Uri.encodeComponent(config.token)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return null;

      final body   = jsonDecode(response.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>;
      final status = result['status'] as Map<String, dynamic>;

      return _parseStatus(status: status, moongateResult: result, baseUrl: baseUrl);
    } catch (_) {
      return null;
    }
  }

  // ── Native Moonraker object query ──────────────────────────────────────────

  Future<PrinterStatus?> _tryNativeEndpoint(String baseUrl) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/printer/objects/query'
        '?print_stats&extruder&heater_bed&display_status',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return null;

      final body   = jsonDecode(response.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>;
      final status = result['status'] as Map<String, dynamic>;

      // No tunnel URL or webcam path available from native endpoint.
      return _parseStatus(status: status, moongateResult: null, baseUrl: baseUrl);
    } catch (_) {
      return null;
    }
  }

  // ── Shared parser ──────────────────────────────────────────────────────────

  PrinterStatus _parseStatus({
    required Map<String, dynamic> status,
    required Map<String, dynamic>? moongateResult,
    required String baseUrl,
  }) {
    final printStats    = status['print_stats']    as Map<String, dynamic>? ?? {};
    final extruder      = status['extruder']       as Map<String, dynamic>? ?? {};
    final heaterBed     = status['heater_bed']     as Map<String, dynamic>? ?? {};
    final displayStatus = status['display_status'] as Map<String, dynamic>? ?? {};

    final state = (printStats['state'] as String?) ?? 'offline';

    // Prefer display_status.progress (the real slicer %) over duration ratio.
    final double progress;
    if (displayStatus['progress'] != null) {
      progress = (displayStatus['progress'] as num).toDouble().clamp(0.0, 1.0);
    } else if (printStats['print_duration'] != null &&
        printStats['total_duration'] != null &&
        (printStats['total_duration'] as num) > 0) {
      progress = ((printStats['print_duration'] as num) /
              (printStats['total_duration'] as num))
          .clamp(0.0, 1.0)
          .toDouble();
    } else {
      progress = 0.0;
    }

    // Detect tunnel URL rotation — only the Moongate endpoint reports this.
    if (moongateResult != null && !_disposed) {
      final liveTunnelUrl = moongateResult['tunnel_url'] as String?;
      if (liveTunnelUrl != null &&
          liveTunnelUrl.isNotEmpty &&
          liveTunnelUrl != config.remoteHost) {
        _tunnelUrlController.add(liveTunnelUrl);
        PrinterRegistry.instance
            .updateRemoteHost(config.id, liveTunnelUrl)
            .ignore();
      }
    }

    final connection = (baseUrl == config.host)
        ? PrinterConnection.local
        : PrinterConnection.remote;

    return PrinterStatus(
      state:              state,
      progress:           progress,
      hotendTemp:         (extruder['temperature'] as num?)?.toDouble() ?? 0,
      hotendTarget:       (extruder['target']      as num?)?.toDouble() ?? 0,
      bedTemp:            (heaterBed['temperature'] as num?)?.toDouble() ?? 0,
      bedTarget:          (heaterBed['target']      as num?)?.toDouble() ?? 0,
      filename:           printStats['filename']             as String?,
      connection:         connection,
      webcamSnapshotPath: moongateResult?['webcam_snapshot_path'] as String?,
    );
  }
}
