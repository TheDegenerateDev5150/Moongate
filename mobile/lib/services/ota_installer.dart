import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// In-app updater: downloads a release APK with progress, then hands it to
/// Android's package installer (which still shows its own install confirmation —
/// a sideloaded app can't install silently). Android-only; callers must guard
/// with `Platform.isAndroid` and fall back to opening [UpdateInfo.apkUrl] in a
/// browser elsewhere (iOS can't sideload).
///
/// Integrity/authenticity is enforced by Android at install time: the new APK
/// must be signed with the same key as the installed one or the installer
/// rejects it, so a tampered download can't replace the app. (Publishing a
/// SHA-256 in the manifest to verify before launching the installer is a
/// possible future hardening.)
class OtaInstaller {
  static const _channel = MethodChannel('com.moongate.app/install');

  /// Stream [url] to `<cache>/moongate-update.apk`, reporting download progress
  /// as a 0..1 fraction (or a negative value while the total size is unknown).
  /// Returns the downloaded file's path. Throws on a network or HTTP error.
  static Future<String> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }

      final total = response.contentLength ?? 0;
      // A dedicated subdir of the cache dir, matched by the FileProvider's
      // <cache-path name="updates" path="updates/"> so the installer can read it.
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}/moongate-update.apk');
      final sink = file.openWrite();
      try {
        var received = 0;
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(total > 0 ? received / total : -1);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      onProgress(1.0);
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Ensure the "install unknown apps" grant for this app, then launch the
  /// system package installer on [filePath]. Returns false when the user
  /// declines the install-packages permission (the caller should then fall back
  /// to the browser). Throws [PlatformException] if the install intent fails.
  static Future<bool> installApk(String filePath) async {
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) return false;
    await _channel.invokeMethod('installApk', {'path': filePath});
    return true;
  }

  /// Delete the downloaded update APK left in the cache. Call it at startup, not
  /// straight after [installApk]: the system installer reads the file
  /// asynchronously (and shows its own confirmation), so deleting it too early
  /// would break the install. By the next launch the install has finished (or
  /// was declined), so the ~80 MB file is just dead weight, and users were
  /// seeing it as the app hogging storage. Best-effort; never throws.
  static Future<void> clearDownloadedApks() async {
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // A leftover file is harmless; cleanup must never break startup.
    }
  }
}
