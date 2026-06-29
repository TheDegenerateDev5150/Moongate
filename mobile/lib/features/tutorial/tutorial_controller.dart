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
  const TutorialStep({required this.id, this.anchor});
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

  /// The ordered steps for a run. Slice 1: just the local-mode bar.
  List<TutorialStep> _buildSteps() => [
        TutorialStep(id: 'localBar', anchor: TutorialAnchors.instance.connectionBar),
      ];

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
