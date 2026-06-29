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
  Rect? _holeRect;
  int _resolvedForIndex = -1;

  /// Resolve the anchor's rectangle in the overlay's own coordinate space, after
  /// layout. Retries on the next frame until the target widget is mounted (it
  /// may belong to a screen we just navigated to), then stores the rect.
  void _resolveRect(TutorialState s) {
    final step = s.current;
    final anchorCtx = step?.anchor?.currentContext;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;

    if (step == null) {
      if (_holeRect != null) setState(() => _holeRect = null);
      return;
    }
    if (step.anchor == null) {
      // Centred message step: no spotlight.
      if (_holeRect != null || _resolvedForIndex != s.index) {
        setState(() {
          _holeRect = null;
          _resolvedForIndex = s.index;
        });
      }
      return;
    }
    final anchorBox = anchorCtx?.findRenderObject() as RenderBox?;
    if (anchorBox == null || stackBox == null || !anchorBox.hasSize) {
      // Not laid out yet; try again next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveRect(ref.read(tutorialControllerProvider));
      });
      return;
    }
    final topLeft = stackBox.globalToLocal(anchorBox.localToGlobal(Offset.zero));
    final rect = topLeft & anchorBox.size;
    if (rect != _holeRect || _resolvedForIndex != s.index) {
      setState(() {
        _holeRect = rect;
        _resolvedForIndex = s.index;
      });
    }
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
              hole: _holeRect,
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
  final Rect? hole;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TutorialScrim({
    required this.state,
    required this.hole,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    // Put the card opposite the spotlight: at the bottom when the target sits in
    // the top 60% of the screen, otherwise at the top. Avoids covering the very
    // thing we are pointing at.
    final cardAtBottom = hole == null ? true : hole!.center.dy < size.height * 0.6;
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
                painter: _SpotlightPainter(hole: hole),
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
                TextButton(onPressed: onSkip, child: Text(skipLabel)),
                const SizedBox(width: 4),
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
  final Rect? hole;
  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    if (hole == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    // Pad the target so even a thin (3px) bar gets a visible highlight.
    final cut = RRect.fromRectAndRadius(
      hole!.inflate(8),
      const Radius.circular(10),
    );
    final full = Path()..addRect(Offset.zero & size);
    final cutPath = Path()..addRRect(cut);
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cutPath),
      scrim,
    );
    // A soft ring around the hole.
    canvas.drawRRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.hole != hole;
}
