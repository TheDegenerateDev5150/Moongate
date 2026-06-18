import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The dashboard's optional custom background image.
///
/// State is the absolute path to a copy of the user's chosen image, kept in the
/// app's documents directory so it survives launches (file_picker only hands
/// back a cache path the OS may evict), or null when none is set. The dashboard
/// layers this image — centred and scaled-down — over the active theme's
/// background colour, so a transparent PNG (a logo) or a wrong-aspect image
/// still shows the theme colour around and behind it.
///
/// Device-bound: the path is local to this install, so it deliberately does NOT
/// travel in backups (SettingsBackup is an allow-list and this key is simply
/// absent). A fresh image is written under a unique, timestamped filename each
/// time so Flutter's path-keyed image cache always picks up the change.
class DashboardBackgroundNotifier extends Notifier<String?> {
  static const _key = 'dashboard_background_path';

  @override
  String? build() => null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);
    // Drop a stale pointer if the file is gone (e.g. app data partly cleared).
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      state = path;
    } else {
      state = null;
      if (path != null) await prefs.remove(_key);
    }
  }

  /// Copy [bytes] into app storage under a unique filename, replacing any
  /// previous background, and persist the new path. [extension] is the source
  /// file's extension (e.g. 'png', 'jpg'), kept only to make the saved file
  /// recognisable — decoding is by content, not name.
  Future<void> setFromBytes(Uint8List bytes, {String extension = 'img'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = extension.replaceAll('.', '').toLowerCase();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/dashboard_bg_$stamp.$ext');
    await file.writeAsBytes(bytes, flush: true);
    await _deleteFile(state); // remove the previous image (state still = old)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, file.path);
    state = file.path;
  }

  /// Remove the custom background and delete its file.
  Future<void> clear() async {
    await _deleteFile(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = null;
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // Best-effort cleanup — a leftover image file is harmless.
    }
  }
}

final dashboardBackgroundProvider =
    NotifierProvider<DashboardBackgroundNotifier, String?>(
  DashboardBackgroundNotifier.new,
);
