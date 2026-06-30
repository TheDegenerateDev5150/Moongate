import 'package:flutter/widgets.dart';

/// Shared GlobalKeys for the dashboard elements the live tutorial spotlights.
///
/// The first printer tile attaches these keys to its parts when it is the
/// designated tutorial-anchor tile, and the [TutorialOverlay] reads their
/// RenderBoxes to position the spotlight hole. Both sides reference the same
/// singleton so the keys are identical instances.
///
/// Slice 1 only needs the connection bar; the temps, webcam and printer-screen
/// anchors get added here as the tour is built out.
class TutorialAnchors {
  TutorialAnchors._();
  static final TutorialAnchors instance = TutorialAnchors._();

  /// The thin connection-state colour bar at the top of the first tile.
  final GlobalKey connectionBar = GlobalKey(debugLabel: 'tut_connectionBar');

  /// The Local/Tunnel text label + its wifi/cloud icon in the tile's name row.
  final GlobalKey connectionLabel = GlobalKey(debugLabel: 'tut_connectionLabel');

  /// The hotend / bed / chamber temperature chips on the first tile.
  final GlobalKey tempHotend = GlobalKey(debugLabel: 'tut_tempHotend');
  final GlobalKey tempBed = GlobalKey(debugLabel: 'tut_tempBed');
  final GlobalKey tempChamber = GlobalKey(debugLabel: 'tut_tempChamber');

  /// The webcam square on the first tile.
  final GlobalKey webcam = GlobalKey(debugLabel: 'tut_webcam');

  /// The name + temperatures block, the long-press target that opens preheat.
  final GlobalKey preheatArea = GlobalKey(debugLabel: 'tut_preheatArea');

  /// The emergency-stop button at the end of the temperature row.
  final GlobalKey estop = GlobalKey(debugLabel: 'tut_estop');

  /// The add-printer floating action button on the dashboard.
  final GlobalKey addPrinter = GlobalKey(debugLabel: 'tut_addPrinter');

  // ── Hamburger menu (end drawer) ─────────────────────────────────────────────
  /// The Theme selector in the drawer.
  final GlobalKey menuTheme = GlobalKey(debugLabel: 'tut_menuTheme');
}
