import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/printer_config.dart';
import 'lan_discovery_service.dart';
import 'printer_access_cache.dart';
import 'printer_registry.dart';
import 'supabase_service.dart';

/// Sends print-control commands to the Moongate plugin.
///
/// v0.3.0: each call fetches a fresh `{tunnel_url, access_token}` from
/// Supabase (via [PrinterAccessCache]) before hitting the Pi. The plugin
/// validates the EdDSA token and proxies the action through to Klipper.
class PrintControlService {
  final PrinterConfig config;
  PrintControlService(this.config);

  /// Send a print control action.
  /// [action]: `pause` | `resume` | `cancel` | `firmware_restart` | `emergency_stop`
  /// Returns `true` if the Pi accepted the command.
  Future<bool> sendAction(String action) async {
    if (!SupabaseService.instance.ready) return false;

    PrinterAccess access;
    try {
      access = await PrinterAccessCache.instance.get(config.id);
    } catch (_) {
      return false;
    }

    // v0.5.0: pick the freshest available LAN URL.
    //   1. A discovered URL from mDNS (= what the Pi is *currently*
    //      advertising on the LAN — survives DHCP IP changes).
    //   2. The registry-live lanUrl (what the status service most
    //      recently learned from a successful /status response). This
    //      read closes the v0.4.x bug where the control service captured
    //      `config.lanUrl` at construction and never re-read it, so an
    //      IP change picked up by the status service didn't propagate to
    //      pause/resume/cancel until the tile was rebuilt.
    //   3. Fall through to the construction-time config.lanUrl if the
    //      registry entry has vanished (race during printer removal).
    //
    // See docs/v0.5-lan-discovery-design.md §8.2 and §10.2.
    final discovered = LanDiscoveryService.instance.lookup(config.id);
    final live = PrinterRegistry.instance.printers
        .firstWhere(
          (p) => p.id == config.id,
          orElse: () => config,
        )
        .lanUrl;
    final lanUrl = discovered ?? live;
    if (lanUrl != null &&
        await _send(lanUrl, access.accessToken, action,
                    timeout: const Duration(seconds: 2))) {
      return true;
    }

    // Tunnel only when the cloud has reported one. v0.5.0: a freshly-paired
    // printer can be controlled over LAN before its tunnel exists, so a null
    // tunnel here is normal, not a failure.
    if (access.tunnelUrl != null &&
        await _send(access.tunnelUrl!, access.accessToken, action,
                    timeout: const Duration(seconds: 10))) {
      return true;
    }

    // 401 / network blip — drop the cache and retry tunnel once with a
    // fresh token. LAN already tried.
    PrinterAccessCache.instance.invalidate(config.id);
    try {
      access = await PrinterAccessCache.instance.get(config.id);
    } catch (_) {
      return false;
    }
    if (access.tunnelUrl == null) return false;
    return _send(access.tunnelUrl!, access.accessToken, action,
                 timeout: const Duration(seconds: 10));
  }

  Future<bool> _send(
    String baseUrl,
    String token,
    String action, {
    required Duration timeout,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/server/moongate/control'
        '?mg_token=${Uri.encodeComponent(token)}'
        '&action=${Uri.encodeComponent(action)}',
      );
      final response = await http.post(uri).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── G-code library: list stored files + start a print ─────────────────────
  //
  // These talk to Moonraker directly (not the plugin's /control endpoint),
  // mirroring how PrinterStatusService already pulls /printer/objects/query
  // and /server/files/metadata: on LAN no auth header (Moonraker trusts the
  // subnet), on the tunnel a Bearer token (the auth proxy gates it). So the
  // feature needs no plugin update — it rides the same transparent proxy.

  /// List the G-code files stored on the printer (Moonraker `gcodes` root),
  /// newest first. Returns null when every path failed (caller shows an
  /// error); an empty list means the printer simply has no files yet.
  Future<List<GcodeFile>?> listGcodes() =>
      _viaLanThenTunnel((base, token, isLan) async {
        try {
          final uri = Uri.parse('$base/server/files/list?root=gcodes');
          final resp = await http
              .get(uri,
                  headers: isLan ? null : {'Authorization': 'Bearer $token'})
              .timeout(Duration(seconds: isLan ? 4 : 12));
          if (resp.statusCode != 200) return null;
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final result = body['result'] as List<dynamic>? ?? const [];
          final files = result
              .whereType<Map<String, dynamic>>()
              .map(GcodeFile.fromJson)
              .where((f) => f.isGcode)
              .toList()
            ..sort((a, b) => b.modified.compareTo(a.modified));
          return files;
        } catch (_) {
          return null;
        }
      });

  /// Start printing a stored file by its `gcodes`-relative path. LAN-first,
  /// then tunnel; returns true once Moonraker accepts the start.
  Future<bool> startPrint(String filename) async {
    final ok = await _viaLanThenTunnel((base, token, isLan) async {
      try {
        final uri = Uri.parse('$base/printer/print/start'
            '?filename=${Uri.encodeComponent(filename)}');
        final resp = await http
            .post(uri,
                headers: isLan ? null : {'Authorization': 'Bearer $token'})
            .timeout(Duration(seconds: isLan ? 4 : 12));
        // null (not false) on a non-200 so the next path is still tried — a LAN
        // Moonraker that rejects an untrusted POST falls back to the tunnel.
        return resp.statusCode == 200 ? true : null;
      } catch (_) {
        return null;
      }
    });
    return ok ?? false;
  }

  /// Fetch a slicer-embedded thumbnail for [file] — the same PNG preview
  /// Mainsail/Fluidd show. Reads the file's metadata for the largest available
  /// thumbnail, then pulls it from the gcodes file store. Returns the image
  /// bytes, an empty list when the file has no embedded thumbnail, or null on
  /// failure. Both requests run against the same winning base (LAN or tunnel).
  Future<Uint8List?> fetchThumbnail(GcodeFile file) =>
      _viaLanThenTunnel((base, token, isLan) async {
        try {
          final headers = isLan ? null : {'Authorization': 'Bearer $token'};
          final metaUri = Uri.parse('$base/server/files/metadata'
              '?filename=${Uri.encodeComponent(file.path)}');
          final metaResp = await http
              .get(metaUri, headers: headers)
              .timeout(Duration(seconds: isLan ? 4 : 12));
          if (metaResp.statusCode != 200) return null;
          final thumbs = (jsonDecode(metaResp.body)['result']?['thumbnails']
                  as List<dynamic>?) ??
              const [];
          // Largest available — it downscales crisply into the small tile.
          Map<String, dynamic>? best;
          for (final t in thumbs.whereType<Map<String, dynamic>>()) {
            final w = (t['width'] as num?)?.toInt() ?? 0;
            if (best == null || w > ((best['width'] as num?)?.toInt() ?? 0)) {
              best = t;
            }
          }
          final rel = best?['relative_path'] as String?;
          if (rel == null) return Uint8List(0); // success: no embedded thumbnail
          // relative_path is relative to the gcode file's parent folder, so
          // prepend that folder to get the path within the gcodes root.
          final dir = file.folder;
          final thumbPath = dir == null ? rel : '$dir/$rel';
          final encoded =
              thumbPath.split('/').map(Uri.encodeComponent).join('/');
          final imgUri = Uri.parse('$base/server/files/gcodes/$encoded');
          final imgResp = await http
              .get(imgUri, headers: headers)
              .timeout(Duration(seconds: isLan ? 5 : 15));
          if (imgResp.statusCode != 200) return null;
          return imgResp.bodyBytes;
        } catch (_) {
          return null;
        }
      });

  /// Resolve the freshest LAN base then the tunnel, running [call] against each
  /// until one returns non-null. Mirrors [sendAction]'s path order — including
  /// the one-shot token refresh + tunnel retry — so a fresh-paired (tunnel-
  /// less) printer still works on LAN and a stale token self-heals.
  Future<T?> _viaLanThenTunnel<T>(
      Future<T?> Function(String base, String token, bool isLan) call) async {
    if (!SupabaseService.instance.ready) return null;

    PrinterAccess access;
    try {
      access = await PrinterAccessCache.instance.get(config.id);
    } catch (_) {
      return null;
    }

    final discovered = LanDiscoveryService.instance.lookup(config.id);
    final live = PrinterRegistry.instance.printers
        .firstWhere((p) => p.id == config.id, orElse: () => config)
        .lanUrl;
    final lanUrl = discovered ?? live;
    if (lanUrl != null) {
      final r = await call(lanUrl, access.accessToken, true);
      if (r != null) return r;
    }

    if (access.tunnelUrl != null) {
      final r = await call(access.tunnelUrl!, access.accessToken, false);
      if (r != null) return r;
    }

    // 401 / network blip — drop the cache, refresh the token, retry tunnel once.
    PrinterAccessCache.instance.invalidate(config.id);
    try {
      access = await PrinterAccessCache.instance.get(config.id);
    } catch (_) {
      return null;
    }
    if (access.tunnelUrl != null) {
      return call(access.tunnelUrl!, access.accessToken, false);
    }
    return null;
  }
}

/// A G-code file stored on the printer, parsed from Moonraker's
/// `/server/files/list?root=gcodes` response.
class GcodeFile {
  /// Path relative to the gcodes root, e.g. `calibration/benchy.gcode`.
  final String path;

  /// Last-modified time in unix seconds (0 when unknown).
  final double modified;

  /// File size in bytes (0 when unknown).
  final int size;

  const GcodeFile({
    required this.path,
    required this.modified,
    required this.size,
  });

  factory GcodeFile.fromJson(Map<String, dynamic> j) => GcodeFile(
        path:     (j['path'] as String?) ?? '',
        modified: (j['modified'] as num?)?.toDouble() ?? 0,
        size:     (j['size'] as num?)?.toInt() ?? 0,
      );

  bool get isGcode {
    final p = path.toLowerCase();
    return p.endsWith('.gcode') || p.endsWith('.gco') || p.endsWith('.g');
  }

  /// Just the filename, without any subdirectory prefix.
  String get name {
    final i = path.lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }

  /// The subdirectory the file lives in, or null when it sits at the root.
  String? get folder {
    final i = path.lastIndexOf('/');
    return i > 0 ? path.substring(0, i) : null;
  }

  DateTime? get modifiedAt => modified > 0
      ? DateTime.fromMillisecondsSinceEpoch((modified * 1000).round())
      : null;
}
