import 'package:http/http.dart' as http;

import '../models/printer_config.dart';

/// Sends print control commands to the printer.
///
/// Strategy (same local-first, then tunnel as the status service):
///   1. Try the Moongate plugin endpoint — validates the JWT and proxies to Klipper.
///   2. Fall back to the native Moonraker REST API — works without the plugin.
///
/// Returns `true` as soon as any candidate accepts the command (HTTP 200).
class PrintControlService {
  final PrinterConfig config;

  PrintControlService(this.config);

  /// Send a print control action.
  /// [action] must be: `pause`, `resume`, `cancel`, or `firmware_restart`.
  /// Returns `true` if the command was accepted by any candidate.
  Future<bool> sendAction(String action) async {
    // Mirror the same candidate ordering used by PrinterStatusService so that
    // remote-first printers (preferRemote=true) don't waste a 10-second local
    // timeout before falling back to the tunnel for every control command.
    final candidates = (config.preferRemote && config.remoteHost != null)
        ? [config.remoteHost!, config.host]
        : [config.host, if (config.remoteHost != null) config.remoteHost!];

    for (final baseUrl in candidates) {
      if (await _tryMoongateControl(baseUrl, action)) return true;
      if (await _tryNativeControl(baseUrl, action)) return true;
    }
    return false;
  }

  // ── Moongate plugin endpoint ───────────────────────────────────────────────

  Future<bool> _tryMoongateControl(String baseUrl, String action) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/server/moongate/control'
        '?mg_token=${Uri.encodeComponent(config.token)}'
        '&action=${Uri.encodeComponent(action)}',
      );
      final response = await http.post(uri).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Native Moonraker API fallback ──────────────────────────────────────────

  Future<bool> _tryNativeControl(String baseUrl, String action) async {
    // Map Moongate action names → native Moonraker endpoints.
    final endpoint = switch (action) {
      'pause'            => '/printer/print/pause',
      'resume'           => '/printer/print/resume',
      'cancel'           => '/printer/print/cancel',
      'firmware_restart' => '/printer/firmware_restart',
      'emergency_stop'   => '/printer/emergency_stop',
      _                  => null,
    };
    if (endpoint == null) return false;

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(uri).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
