import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/pairing_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/printer/printer_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'providers/settings_provider.dart';
import 'services/printer_registry.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(
      path: '/',
      redirect: (_, __) => '/dashboard',
    ),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/pair', builder: (_, __) => const PairingScreen()),
    GoRoute(
      path: '/printer/:id',
      builder: (_, state) {
        final id = state.pathParameters['id']!;
        // Guard against stale IDs (printer removed while screen was open).
        final printer = PrinterRegistry.instance.printers
            .where((p) => p.id == id)
            .firstOrNull;
        if (printer == null) return const DashboardScreen();
        return PrinterScreen(printer: printer);
      },
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

class MoongateApp extends ConsumerStatefulWidget {
  const MoongateApp({super.key});

  @override
  ConsumerState<MoongateApp> createState() => _MoongateAppState();
}

class _MoongateAppState extends ConsumerState<MoongateApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-run the subnet locality check whenever the app comes back to the
    // foreground.  The phone may have moved to a different WiFi network
    // while we were backgrounded — without this refresh, the live
    // preferences we computed at cold-start would be stale and the printer
    // screen could try a now-unreachable local IP.
    if (state == AppLifecycleState.resumed) {
      PrinterRegistry.instance.refreshNetworkLocality();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp.router(
      title: 'Moongate',
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      // Apply font scaling via builder so we inherit the real system MediaQuery
      // (status-bar height, nav-bar height, etc.) rather than discarding it.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontScale),
        ),
        child: child!,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: brightness,
      ),
    );
  }
}
