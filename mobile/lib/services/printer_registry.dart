import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_config.dart';

/// Persists the list of paired printers to SharedPreferences.
class PrinterRegistry {
  PrinterRegistry._();
  static final PrinterRegistry instance = PrinterRegistry._();

  static const _key = 'moongate_printers';

  List<PrinterConfig> _printers = [];

  List<PrinterConfig> get printers => List.unmodifiable(_printers);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      _printers = PrinterConfig.listFromJson(raw);
    } catch (_) {
      // Saved data is corrupted or from an incompatible old version.
      // Clear it so the app starts clean rather than crashing every launch.
      _printers = [];
      await prefs.remove(_key);
    }
  }

  Future<void> add(PrinterConfig printer) async {
    _printers = [..._printers, printer];
    await _save();
  }

  Future<void> remove(String printerId) async {
    _printers = _printers.where((p) => p.id != printerId).toList();
    await _save();
  }

  /// Silently update the Cloudflare tunnel URL for a printer.
  /// Called automatically when the status poll returns a fresher URL
  /// than the one stored (Quick Tunnels rotate when cloudflared restarts).
  Future<void> updateRemoteHost(String printerId, String newRemoteHost) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    if (_printers[idx].remoteHost == newRemoteHost) return;
    _printers = List.of(_printers)
      ..[idx] = _printers[idx].copyWith(remoteHost: newRemoteHost);
    await _save();
  }

  /// Persist which connection path worked last for this printer.
  /// Called by [PrinterStatusService] after each successful poll so the
  /// next app launch tries the right path first without wasting time on
  /// a guaranteed timeout (e.g. a remote-only printer's local IP).
  Future<void> updatePreferRemote(String printerId, {required bool preferRemote}) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    if (_printers[idx].preferRemote == preferRemote) return;
    _printers = List.of(_printers)
      ..[idx] = _printers[idx].copyWith(preferRemote: preferRemote);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, PrinterConfig.listToJson(_printers));
  }
}
