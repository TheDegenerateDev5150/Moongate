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
///      Tries progressively simpler object sets to handle printers where
///      optional objects (heater_bed, display_status) are not configured.
///
/// A _polling guard prevents concurrent polls from stacking up when the
/// previous poll is still timing out on an unreachable host.
class PrinterStatusService {
  final PrinterConfig config;
  final _controller          = StreamController<PrinterStatus>.broadcast();
  final _tunnelUrlController = StreamController<String>.broadcast();
  Timer? _timer;
  bool _disposed = false;
  bool _polling  = false; // guard: skip tick if previous poll still running

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
    if (_disposed || _polling) return;
    _polling = true;
    try {
      await _doPoll();
    } finally {
      _polling = false;
    }
  }

  Future<void> _doPoll() async {
    // Try local first, then the Cloudflare tunnel.
    // config.host      = full local URL:  "http://192.168.x.x"
    // config.remoteHost = tunnel URL:     "https://xxxx.trycloudflare.com"
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
      //   Works even without the Moongate plugin.  Tries progressively
      //   simpler object sets to handle printers without a heated bed or
      //   other optional Klipper objects.
      final native = await _tryNativeEndpoint(baseUrl);
      if (native != null) {
        if (!_disposed) _controller.add(native);
        return;
      }
    }

    // All candidates failed — printer is unreachable.
    if (!_disposed) _controller.add(PrinterStatus.offline);
  }

  // ── Moongate plugin endpoint ───────────────────────────────────────────────

  Future<PrinterStatus?> _tryMoongateEndpoint(String baseUrl) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/server/moongate/status?mg_token=${Uri.encodeComponent(config.token)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 2));
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
  //
  // Moonraker returns HTTP 400 when you query an object that isn't registered
  // in the Klipper config (e.g. `heater_bed` on a printer without a heated
  // bed, or `display_status` on a printer without a display).  We try
  // progressively simpler object sets and stop at the first 200 response.
  // A timeout or any non-400 error causes an immediate bail-out.

  static const _nativeQueries = [
    'print_stats&extruder&heater_bed', // most Mainsail setups
    'print_stats&extruder',            // no heated bed
    'print_stats',                     // absolute minimum
  ];

  Future<PrinterStatus?> _tryNativeEndpoint(String baseUrl) async {
    for (final q in _nativeQueries) {
      try {
        final uri = Uri.parse('$baseUrl/printer/objects/query?$q');
        final response = await http.get(uri).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final body   = jsonDecode(response.body) as Map<String, dynamic>;
          final result = body['result'] as Map<String, dynamic>;
          final status = result['status'] as Map<String, dynamic>;
          return _parseStatus(status: status, moongateResult: null, baseUrl: baseUrl);
        }

        // 400 = object not found → try a simpler query set
        if (response.statusCode == 400) continue;

        // Any other non-200 (401, 403, 5xx …) → give up on this host
        return null;
      } catch (_) {
        // Timeout or network error → give up on this host immediately
        // (don't bother retrying simpler queries — the host is unreachable)
        return null;
      }
    }
    return null;
  }

  // ── Shared status parser ───────────────────────────────────────────────────

  PrinterStatus _parseStatus({
    required Map<String, dynamic> status,
    required Map<String, dynamic>? moongateResult,
    required String baseUrl,
  }) {
    final printStats = status['print_stats'] as Map<String, dynamic>? ?? {};
    final extruder   = status['extruder']    as Map<String, dynamic>? ?? {};
    final heaterBed  = status['heater_bed']  as Map<String, dynamic>? ?? {};

    // display_status.progress is the real slicer %; only available from the
    // Moongate endpoint (which includes the full Moonraker status object).
    final displayStatus = status['display_status'] as Map<String, dynamic>? ?? {};

    final state = (printStats['state'] as String?) ?? 'offline';

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

    // Detect tunnel URL rotation — only available from the Moongate endpoint.
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
