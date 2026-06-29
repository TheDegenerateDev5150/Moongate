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

  /// The hotend / bed / chamber temperature chips on the first tile.
  final GlobalKey tempHotend = GlobalKey(debugLabel: 'tut_tempHotend');
  final GlobalKey tempBed = GlobalKey(debugLabel: 'tut_tempBed');
  final GlobalKey tempChamber = GlobalKey(debugLabel: 'tut_tempChamber');

  /// The webcam square on the first tile.
  final GlobalKey webcam = GlobalKey(debugLabel: 'tut_webcam');
}
