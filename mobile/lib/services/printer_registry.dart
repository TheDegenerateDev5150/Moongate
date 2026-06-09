import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_config.dart';
import 'supabase_service.dart';

/// In v0.3.0 the source of truth is the Supabase `printers` table. The
/// registry is a local cache of that table for this user, populated on
/// demand and persisted to SharedPreferences so the dashboard renders
/// immediately on cold start.
///
/// Cross-tenant isolation is enforced by Row-Level Security at the
/// database layer — `select my printers` policy filters every query to
/// `owner_user_id = auth.uid()`. There is no way to see another user's
/// printers from this code path.
class PrinterRegistry {
  PrinterRegistry._();
  static final PrinterRegistry instance = PrinterRegistry._();

  static const _key = 'moongate_printers';

  List<PrinterConfig> _printers = [];

  List<PrinterConfig> get printers => List.unmodifiable(_printers);

  void _log(String msg) => dev.log(msg, name: 'MOONGATE/REGISTRY');

  // ── Local persistence ────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      _printers = PrinterConfig.listFromJson(raw);
    } on FormatException catch (e) {
      // Legacy v0.2.x payload — drop it. The user will re-pair via the
      // new v=3 QR flow.
      _log('Dropping legacy persisted printers (${e.message})');
      _printers = [];
      await prefs.remove(_key);
    } catch (e) {
      _log('Corrupted printers JSON, dropping: $e');
      _printers = [];
      await prefs.remove(_key);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, PrinterConfig.listToJson(_printers));
  }

  /// Pulls the current user's printers from Supabase (RLS-scoped) and
  /// merges them into the local cache. Local-only additions made during
  /// the same session (e.g. just-claimed printers) are preserved.
  ///
  /// Called from the dashboard on launch and on pull-to-refresh.
  Future<void> refreshFromSupabase() async {
    if (!SupabaseService.instance.ready) {
      _log('Supabase not ready, skipping refresh');
      return;
    }
    try {
      final rows = await SupabaseService.instance.listMyPrinters();
      final newList = <PrinterConfig>[];
      for (final r in rows) {
        // Preserve cached webcam settings if we already know this printer.
        final existing = _printers.where((p) => p.id == r.id).firstOrNull;
        newList.add(existing != null
            ? existing.copyWith(name: r.name)
            : PrinterConfig(id: r.id, name: r.name));
      }
      _printers = newList;
      await _save();
      _log('Refreshed: ${_printers.length} printer(s) from Supabase');
    } catch (e) {
      _log('refreshFromSupabase failed: $e');
    }
  }

  /// Add a printer locally after a successful claim. The Supabase row
  /// already exists by the time this is called; this just caches it.
  Future<void> addClaimed(PrinterConfig printer) async {
    final exists = _printers.any((p) => p.id == printer.id);
    if (!exists) {
      _printers = [..._printers, printer];
      await _save();
    }
  }

  /// Legacy alias kept for import-config flow. Behaves like [addClaimed].
  Future<void> add(PrinterConfig printer) => addClaimed(printer);

  /// Opens the SAF document picker, parses a Moongate backup, and merges its
  /// printers into the local cache (existing kept, duplicates matched by id
  /// skipped). Returns the number of printers added, or null if the user
  /// cancelled the picker. Throws on a malformed / unreadable file so the
  /// caller can surface an error.
  ///
  /// Shared by the dashboard "Restore config" item and the first-launch
  /// pairing screen. A backup carries the printer list only, NOT the Supabase
  /// anon identity — restored printers stay offline until each Pi is re-paired
  /// (a reinstall gets a new cloud identity).
  Future<ImportOutcome?> importFromBackupFile() async {
    // withData:true returns bytes inline rather than a path we may not be able
    // to read under scoped storage. Accept any file type (Android often greys
    // out custom .json filters) and validate by parsing instead.
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a Moongate backup',
      withData: true,
    );
    if (picked == null) return null; // user cancelled
    final bytes = picked.files.single.bytes;
    if (bytes == null) throw const FormatException('unreadable_file');

    // Two shapes: a legacy bare array (printers only) or the v2 envelope
    // { backup_version, restore_code?, printers: [...] }.
    final decoded = jsonDecode(utf8.decode(bytes));
    final List<PrinterConfig> imported;
    String? restoreCode;
    if (decoded is List) {
      imported = decoded
          .map((e) => PrinterConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (decoded is Map<String, dynamic>) {
      final list = (decoded['printers'] as List<dynamic>?) ?? const [];
      imported = list
          .map((e) => PrinterConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      final code = decoded['restore_code'];
      if (code is String && code.isNotEmpty) restoreCode = code;
    } else {
      throw const FormatException('unrecognised_backup');
    }

    // Reclaim ownership FIRST so the just-added printers resolve online on
    // their first poll. Best-effort: an invalid/expired code or a network
    // error just leaves them offline until re-paired.
    var reconnected = false;
    if (restoreCode != null) {
      try {
        final reclaimed =
            await SupabaseService.instance.redeemRestoreGrant(restoreCode);
        reconnected = reclaimed != null;
      } catch (e) {
        _log('redeemRestoreGrant failed during import: $e');
      }
    }

    final existing = _printers.map((p) => p.id).toSet();
    var added = 0;
    for (final p in imported) {
      if (!existing.contains(p.id)) {
        await add(p);
        added++;
      }
    }
    return ImportOutcome(added: added, reconnected: reconnected);
  }

  /// Remove the local cache entry. Note: this does NOT delete the row
  /// from Supabase — for that, the user should run MOONGATE_RESET_OWNER
  /// on the Pi (it'll be cleaned up by the 6-week inactivity sweep
  /// thereafter, since no heartbeats can succeed once unpaired).
  Future<void> remove(String printerId) async {
    _printers = _printers.where((p) => p.id != printerId).toList();
    await _save();
  }

  /// Rename a printer locally. Note: the Supabase row's `name` field is
  /// left unchanged — the local rename is cosmetic only. Re-pairing would
  /// reset to whatever name was sent during the claim.
  Future<void> renamePrinter(String printerId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    if (_printers[idx].name == trimmed) return;
    _printers = List.of(_printers)
      ..[idx] = _printers[idx].copyWith(name: trimmed);
    await _save();
  }

  /// Update the cached LAN URL for a printer after a /status response
  /// surfaces it. Pass null to clear (e.g. when LAN starts failing).
  Future<void> updateLanUrl(String printerId, String? lanUrl) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    if (_printers[idx].lanUrl == lanUrl) return;
    _printers = List.of(_printers)
      ..[idx] = _printers[idx].copyWith(lanUrl: lanUrl);
    await _save();
  }

  /// Persist the detected web UI type ('mainsail' | 'fluidd') so the tile
  /// can render the right logo on a cold launch — including when the
  /// printer is currently offline (power-off, Pi rebooting, etc.).
  Future<void> updateUiType(String printerId, String uiType) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    if (_printers[idx].uiType == uiType) return;
    _printers = List.of(_printers)
      ..[idx] = _printers[idx].copyWith(uiType: uiType);
    await _save();
  }

  /// Update webcam transform info from a successful Moongate /status poll.
  Future<void> updateWebcamInfo(
    String printerId, {
    required bool flipH,
    required bool flipV,
    required int  rotation,
    required int  targetFps,
  }) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    final p = _printers[idx];
    if (p.webcamFlipH == flipH &&
        p.webcamFlipV == flipV &&
        p.webcamRotation == rotation &&
        p.webcamTargetFps == targetFps) {
      return;
    }
    _printers = List.of(_printers)
      ..[idx] = p.copyWith(
          webcamFlipH:     flipH,
          webcamFlipV:     flipV,
          webcamRotation:  rotation,
          webcamTargetFps: targetFps);
    await _save();
  }

  // ── v0.2.x compat stubs (kept so the UI doesn't break) ──────────────────

  /// Always returns true now — in v0.3.0 every printer is reached via the
  /// Supabase-mediated tunnel.
  bool? livePreferRemote(String printerId) => true;

  /// No-op in v0.3.0 — kept so PrinterStatusService doesn't break.
  void setLivePreferRemote(String printerId, bool preferRemote) {}

  /// No-op in v0.3.0 — Pi reports its tunnel URL to Supabase, and the
  /// app fetches the current one on every access call. There's nothing
  /// to persist client-side.
  Future<void> updateRemoteHost(String printerId, String newRemoteHost) async {}
}

/// Result of PrinterRegistry.importFromBackupFile.
class ImportOutcome {
  /// Printers added to the local list (duplicates by id were skipped).
  final int added;

  /// True when the backup carried a restore code that redeemed OK, so the
  /// printers were re-bound to this identity and will come back online.
  final bool reconnected;

  const ImportOutcome({required this.added, required this.reconnected});
}
