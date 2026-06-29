import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tutorial_anchors.dart';

/// One step of the live walkthrough.
///
/// [anchor] is the GlobalKey of the element to spotlight (null = a centred
/// message with no spotlight). [id] selects the localized copy in the overlay,
/// kept as a plain string so the controller stays free of l10n imports.
class TutorialStep {
  final String id;
  final GlobalKey? anchor;

  /// Whether to dim the screen behind the spotlight. Turned off for steps that
  /// open their own modal (e.g. the preheat sheet) which already dims the rest.
  final bool dimScreen;

  /// Force the callout card to the top of the screen. Used when a bottom sheet
  /// is on screen so the card sits above it rather than under it.
  final bool forceCardTop;

  const TutorialStep({
    required this.id,
    this.anchor,
    this.dimScreen = true,
    this.forceCardTop = false,
  });
}

/// Immutable run state of the tutorial: whether it is active, which step we are
/// on, and the ordered step list for this run.
class TutorialState {
  final bool active;
  final int index;
  final List<TutorialStep> steps;

  const TutorialState({
    this.active = false,
    this.index = 0,
    this.steps = const [],
  });

  TutorialStep? get current =>
      active && index >= 0 && index < steps.length ? steps[index] : null;
  int get total => steps.length;
  bool get isLast => index >= steps.length - 1;

  TutorialState copyWith({bool? active, int? index, List<TutorialStep>? steps}) =>
      TutorialState(
        active: active ?? this.active,
        index: index ?? this.index,
        steps: steps ?? this.steps,
      );
}

/// Drives the walkthrough: start / next / skip. Kept deliberately small; the
/// step list grows here as each slice of the tour lands. Navigation, fake-state
/// injection and theme snapshot-restore hook in around these calls in later
/// slices.
class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  /// The ordered steps for a run. Grows per slice. Slice 2: the full tile tour
  /// (local bar -> tunnel bar -> hotend -> bed -> chamber -> webcam). The first
  /// dashboard tile fakes the matching state for each step and restores after.
  List<TutorialStep> _buildSteps() {
    final a = TutorialAnchors.instance;
    return [
      TutorialStep(id: 'localBar', anchor: a.connectionBar),
      TutorialStep(id: 'tunnelBar', anchor: a.connectionBar),
      TutorialStep(id: 'hotend', anchor: a.tempHotend),
      TutorialStep(id: 'bed', anchor: a.tempBed),
      TutorialStep(id: 'chamber', anchor: a.tempChamber),
      TutorialStep(id: 'webcam', anchor: a.webcam),
      // Opens the real preheat sheet; the sheet dims the rest itself, so we
      // don't add our own scrim and we float the card above the sheet.
      const TutorialStep(id: 'preheat', dimScreen: false, forceCardTop: true),
    ];
  }

  void start() {
    state = TutorialState(active: true, index: 0, steps: _buildSteps());
  }

  void next() {
    if (!state.active) return;
    if (state.isLast) {
      finish();
      return;
    }
    state = state.copyWith(index: state.index + 1);
  }

  /// End the tour (reached the end, or the user tapped Skip).
  void finish() {
    state = const TutorialState();
  }
}

final tutorialControllerProvider =
    NotifierProvider<TutorialController, TutorialState>(TutorialController.new);
