import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../services/printer_registry.dart';
import '../../services/printer_webview_cache.dart';

/// Moongate brand red - the launcher-icon / moon-gate colour (#FF3B30). On the
/// boot splash the Dark theme uses this instead of the purple seed, so the
/// loading screen matches the red app icon.
const kMoongateRed = Color(0xFFFF3B30);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  // A second, continuously-looping controller drives the "alive" loading
  // effect - a breathing glow on the logo and a travelling pulse through the
  // dots - so the splash doesn't sit perfectly still while it loads.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
    _anim.forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Warm every printer's Mainsail/Fluidd page in the background while the
    // splash shows, so the first open from the dashboard is instant (no
    // "Initializing…"). Runs headless in PrinterWebViewCache and outlives this
    // screen; the slightly longer splash below gives the loads a head start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PrinterWebViewCache.instance
          .prewarmAll(PrinterRegistry.instance.printers);
    });

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) context.go('/dashboard');
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // On the Dark theme, brand the boot screen with Moongate red (the launcher
    // colour) instead of the purple seed, so it matches the app icon. Light
    // keeps its seed; Custom keeps the user's own accent.
    final isDark = ref.watch(themeModeProvider) == AppThemeMode.dark;
    final brand = isDark ? kMoongateRed : cs.primary;
    final brandContainer =
        isDark ? kMoongateRed.withValues(alpha: 0.18) : cs.primaryContainer;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Breathing logo: a gentle scale + a pulsing glow, looping so
                // the mark feels alive while the app loads.
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final breathe =
                        (1 - math.cos(_pulse.value * 2 * math.pi)) / 2;
                    return Transform.scale(
                      scale: 1.0 + 0.05 * breathe,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: brandContainer,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: brand
                                  .withValues(alpha: 0.25 + 0.35 * breathe),
                              blurRadius: 16 + 22 * breathe,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  // The Moongate moon-gate mark (same SVG as the dashboard
                  // app-bar / launcher icon), tinted to the brand colour.
                  child: SvgPicture.asset(
                    'assets/icons/moongate_icon.svg',
                    width: 64,
                    height: 64,
                    colorFilter: ColorFilter.mode(brand, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'MOONGATE',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: brand,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.splashTagline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha:0.45),
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 22),
                // Three dots with a travelling pulse - a quiet "loading" cue.
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = (_pulse.value + i / 3) % 1.0;
                      final wave = (1 - math.cos(phase * 2 * math.pi)) / 2;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(
                          opacity: 0.25 + 0.75 * wave,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
