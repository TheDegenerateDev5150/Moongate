import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-printer heat-soak deadlines (epoch ms). The preheat sheet (on the UI
/// isolate) arms a deadline; the opt-in print-notification background isolate
/// reads it on each poll tick and fires a one-shot "Heat-soak complete" alert
/// once it passes, then clears it. Piggybacking that service is why a soak alert
/// only fires while print notifications are on - the preheat sheet warns up
/// front when they're off.
///
/// Stored as a JSON `{printerId: epochMs}` map under one key. Deliberately NOT
/// part of the settings backup - a soak timer is a live, here-and-now thing, not
/// a preference to carry across installs. SharedPreferences caches per-isolate,
/// so every method reload()s first to see the other isolate's writes.
class HeatsoakTimers {
  HeatsoakTimers._();

  static const String prefsKey = 'heatsoak_deadlines';

  /// Arm (or replace) a soak timer for [printerId], due at [atEpochMs].
  static Future<void> arm(String printerId, int atEpochMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final map = _decode(prefs.getString(prefsKey));
    map[printerId] = atEpochMs;
    await prefs.setString(prefsKey, jsonEncode(map));
  }

  /// Cancel any soak timer for [printerId] - also how the isolate clears one
  /// after it fires. No-op when none is armed.
  static Future<void> cancel(String printerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final map = _decode(prefs.getString(prefsKey));
    if (map.remove(printerId) != null) {
      await prefs.setString(prefsKey, jsonEncode(map));
    }
  }

  /// The current deadline map (printerId → epoch ms). Reloads first so a caller
  /// in the background isolate sees deadlines armed on the UI isolate.
  static Future<Map<String, int>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _decode(prefs.getString(prefsKey));
  }

  static Map<String, int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }
}
