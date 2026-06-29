import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'tutorial_controller.dart';

/// Wraps the whole app below the app-lock gate. When a tutorial is running it
/// paints a dimming scrim with a spotlight hole over the current step's anchor
/// and a callout card explaining it, with Skip / Next controls. When idle it is
/// invisible and just passes [child] through.
class TutorialOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const TutorialOverlay({super.key, required this.child});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  final GlobalKey _stackKey = GlobalKey();
  List<Rect> _holeRects = const [];
  int _resolvedForIndex = -1;

  /// Resolve every anchor's rectangle in the overlay's own coordinate space,
  /// after layout. Retries on the next frame until the targets are mounted (they
  /// may belong to a screen we just navigated to), then stores the rects.
  void _resolveRect(TutorialState s) {
    final step = s.current;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;

    if (step == null) {
      if (_holeRects.isNotEmpty) setState(() => _holeRects = const []);
      return;
    }
    if (step.anchors.isEmpty) {
      // Centred message step: no spotlight.
      if (_holeRects.isNotEmpty || _resolvedForIndex != s.index) {
        setState(() {
          _holeRects = const [];
          _resolvedForIndex = s.index;
        });
      }
      return;
    }
    final boxes = [
      for (final k in step.anchors)
        k.currentContext?.findRenderObject() as RenderBox?,
    ];
    if (stackBox == null || boxes.any((b) => b == null || !b.hasSize)) {
      // Not all laid out yet; try again next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveRect(ref.read(tutorialControllerProvider));
      });
      return;
    }
    final rects = [
      for (final b in boxes)
        stackBox.globalToLocal(b!.localToGlobal(Offset.zero)) & b.size,
    ];
    if (!_sameRects(rects, _holeRects) || _resolvedForIndex != s.index) {
      setState(() {
        _holeRects = rects;
        _resolvedForIndex = s.index;
      });
    }
  }

  bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialControllerProvider);

    // Re-resolve the spotlight whenever the active step changes.
    if (state.active && _resolvedForIndex != state.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveRect(ref.read(tutorialControllerProvider));
      });
    }

    return Stack(
      key: _stackKey,
      children: [
        widget.child,
        if (state.active)
          Positioned.fill(
            child: _TutorialScrim(
              state: state,
              holes: _holeRects,
              onNext: () => ref.read(tutorialControllerProvider.notifier).next(),
              onSkip: () => ref.read(tutorialControllerProvider.notifier).finish(),
            ),
          ),
      ],
    );
  }
}

class _TutorialScrim extends StatelessWidget {
  final TutorialState state;
  final List<Rect> holes;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TutorialScrim({
    required this.state,
    required this.holes,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    final step = state.current;
    final dim = step?.dimScreen ?? true;

    // The combined area of everything we're spotlighting, used to place the card
    // opposite it.
    final union = holes.isEmpty
        ? null
        : holes.reduce((a, b) => a.expandToInclude(b));

    // Put the card opposite the spotlight: at the bottom when the target sits in
    // the top 60% of the screen, otherwise at the top. Avoids covering the very
    // thing we are pointing at. A step can force the card to the top (e.g. when
    // a bottom sheet is on screen).
    final cardAtBottom = (step?.forceCardTop ?? false)
        ? false
        : (union == null ? true : union.center.dy < size.height * 0.6);
    final text = _copyFor(l, state.current?.id);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Scrim with the spotlight hole. Absorbs taps so the UI behind is
          // inert during the tour (the user advances with Next).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // swallow taps on the dimmed area
              child: CustomPaint(
                painter: _SpotlightPainter(holes: holes, dim: dim),
              ),
            ),
          ),
          // Callout card.
          Positioned(
            left: 16,
            right: 16,
            top: cardAtBottom ? null : padding.top + 16,
            bottom: cardAtBottom ? padding.bottom + 24 : null,
            child: _CalloutCard(
              text: text,
              stepIndex: state.index,
              stepTotal: state.total,
              isLast: state.isLast,
              onNext: onNext,
              onSkip: onSkip,
              nextLabel: state.isLast ? l.tutorialDone : l.tutorialNext,
              skipLabel: l.tutorialSkip,
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps a step id to its localized copy. Kept here so the controller stays free
/// of l10n. New steps add a case as the tour grows.
String _copyFor(AppLocalizations l, String? id) {
  switch (id) {
    case 'localBar':
      return l.tutorialLocalBar;
    case 'tunnelBar':
      return l.tutorialTunnelBar;
    case 'hotend':
      return l.tutorialHotend;
    case 'bed':
      return l.tutorialBed;
    case 'chamber':
      return l.tutorialChamber;
    case 'webcam':
      return l.tutorialWebcam;
    case 'preheat':
      return l.tutorialPreheat;
    default:
      return '';
  }
}

class _CalloutCard extends StatelessWidget {
  final String text;
  final int stepIndex;
  final int stepTotal;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String nextLabel;
  final String skipLabel;

  const _CalloutCard({
    required this.text,
    required this.stepIndex,
    required this.stepTotal,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    required this.nextLabel,
    required this.skipLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 8,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                // Progress dots.
                if (stepTotal > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < stepTotal; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == stepIndex
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                    ],
                  ),
                const Spacer(),
                // Skip is the exit hatch for the whole tour; on the last step
                // it would just duplicate Done, so it's hidden there.
                if (!isLast) ...[
                  TextButton(onPressed: onSkip, child: Text(skipLabel)),
                  const SizedBox(width: 4),
                ],
                FilledButton(onPressed: onNext, child: Text(nextLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the dimming scrim everywhere except a rounded hole over [hole].
class _SpotlightPainter extends CustomPainter {
  final List<Rect> holes;
  final bool dim;
  _SpotlightPainter({required this.holes, this.dim = true});

  @override
  void paint(Canvas canvas, Size size) {
    // Steps that open their own modal (preheat sheet) ask us not to dim - the
    // sheet's own barrier handles that. The tap-absorber stays so the sheet
    // can't be dismissed out from under the tour.
    if (!dim) return;
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    if (holes.isEmpty) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    // Pad each target so even a thin (3px) bar gets a visible highlight.
    final cuts = [
      for (final h in holes)
        RRect.fromRectAndRadius(h.inflate(8), const Radius.circular(10)),
    ];
    var holesPath = Path();
    for (final c in cuts) {
      holesPath = Path.combine(PathOperation.union, holesPath, Path()..addRRect(c));
    }
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        holesPath,
      ),
      scrim,
    );
    // A soft ring around each hole.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.7);
    for (final c in cuts) {
      canvas.drawRRect(c, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.dim != dim ||
      old.holes.length != holes.length ||
      !_listEq(old.holes, holes);

  static bool _listEq(List<Rect> a, List<Rect> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
