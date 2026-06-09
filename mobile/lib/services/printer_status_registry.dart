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

  void update(String printerId, PrinterStatus status) {
    _latest[printerId] = status;
  }

  /// Latest known status for [printerId], or null if it hasn't polled yet.
  PrinterStatus? snapshot(String printerId) => _latest[printerId];
}
