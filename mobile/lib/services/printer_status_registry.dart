import 'dart:async';

import '../models/printer_config.dart';

/// In-memory, last-known live status per printer id.
///
/// Each [PrinterTile] pushes its latest [PrinterStatus] here on every poll;
/// the bug-report sheet reads it so a report captures what the dashboard was
/// actually showing — connection path, tunnelReady, the last Klipper/synthetic
/// state — which is the single most useful signal for triaging a "it says X
/// but really Y" report (cf. the Voron "Connected / idle" case).
///
/// Best-effort only: not persisted, cleared on app restart, and a stale entry
/// for a since-removed printer is harmless because readers only look up ids
/// that are still in the live printer list.
class PrinterStatusRegistry {
  PrinterStatusRegistry._();
  static final PrinterStatusRegistry instance = PrinterStatusRegistry._();

  final Map<String, PrinterStatus> _latest = {};

  // Fires when a printer's Klipper/synthetic STATE changes (not on every poll),
  // so the dashboard can re-sort tiles by status without polling itself — see
  // printerStatusRank. Broadcast + best-effort; recomputing the order is cheap.
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  void update(String printerId, PrinterStatus status) {
    final changed = _latest[printerId]?.state != status.state;
    _latest[printerId] = status;
    if (changed) _changes.add(null);
  }

  /// Latest known status for [printerId], or null if it hasn't polled yet.
  PrinterStatus? snapshot(String printerId) => _latest[printerId];

  // ── Last-poll diagnostics (for bug reports) ─────────────────────────────
  final Map<String, Map<String, dynamic>> _pollDiag = {};

  /// Record why the last poll resolved as it did (LAN /status outcome, the
  /// URL tried, timestamp) so a bug report can explain a stuck tile.
  void recordPoll(String printerId, Map<String, dynamic> diag) {
    _pollDiag[printerId] = diag;
  }

  /// Last-poll diagnostic for [printerId], or null if it hasn't polled yet.
  Map<String, dynamic>? pollDiag(String printerId) => _pollDiag[printerId];
}
