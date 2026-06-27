import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// One version's worth of "what's new" bullets.
class ChangelogEntry {
  final String version; // e.g. "v0.9.1"
  final List<String> bullets;
  const ChangelogEntry(this.version, this.bullets);

  factory ChangelogEntry.fromJson(Map<String, dynamic> j) => ChangelogEntry(
        j['version'] as String,
        (j['bullets'] as List<dynamic>).map((e) => e as String).toList(),
      );
}

/// Loads the user-facing changelog from a single source - `assets/changelog.json`
/// (newest first).
///
/// Two callers:
///   • [loadBundled] - the copy compiled into THIS build, for the offline
///     "What's new" dialog.
///   • [entriesSinceInstalled] - fetched fresh from `master`, so the update
///     banner can show every version BETWEEN the installed build and the latest.
///     The installed APK can't carry notes for a version newer than itself -
///     which is exactly why this has to fetch.
class ChangelogService {
  static const _bundledAsset = 'assets/changelog.json';
  static const _remoteUrl =
      'https://raw.githubusercontent.com/PEEKYPAUL/moongate/master/mobile/assets/changelog.json';

  /// The full changelog baked into this build. Always available (offline).
  static Future<List<ChangelogEntry>> loadBundled() async {
    return _parse(await rootBundle.loadString(_bundledAsset));
  }

  /// Changelog entries strictly NEWER than the installed version, fetched from
  /// `master` - for the "what's new in this update" overlay. Returns an empty
  /// list on any failure (no network, bad JSON, timeout) so the caller can fall
  /// back gracefully.
  static Future<List<ChangelogEntry>> entriesSinceInstalled() async {
    try {
      final installed =
          _parseVersion((await PackageInfo.fromPlatform()).version);
      final uri =
          Uri.parse('$_remoteUrl?cb=${DateTime.now().millisecondsSinceEpoch}');
      final resp = await http.get(
        uri,
        headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return const [];
      return _parse(resp.body)
          .where((e) => _compare(_parseVersion(e.version), installed) > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<ChangelogEntry> _parse(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ChangelogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "v0.9.1" / "0.9.1+67" → [0, 9, 1]. Tolerant of a leading 'v' and a
  /// trailing '+build'.
  static List<int> _parseVersion(String v) {
    final core = v
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .split('+')
        .first
        .trim();
    return core.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  }

  /// Component-wise numeric compare; missing trailing components count as 0.
  static int _compare(List<int> a, List<int> b) {
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }
}
