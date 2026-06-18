import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';

/// Moongate brand red — the launcher-icon / moon-gate colour (#FF3B30). On the
/// boot splash the Dark theme uses this instead of the purple seed, so the
/// loading screen matches the red app icon.
const kMoongateRed = Color(0xFFFF3B30);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

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

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) context.go('/dashboard');
    });
  }

  @override
  void dispose() {
    _anim.dispose();
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
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: brandContainer,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: brand.withValues(alpha:0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
