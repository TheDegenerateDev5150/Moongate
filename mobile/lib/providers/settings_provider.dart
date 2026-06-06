import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Theme mode
// ---------------------------------------------------------------------------

/// Moongate's theme selector.
///
/// `system`/`dark`/`light` map 1:1 onto Flutter's [ThemeMode].
/// `custom` is our own value — when selected, [app.dart] builds the
/// MaterialApp theme from user-picked colours stored in
/// [customThemeProvider] instead of the seeded purple defaults.
enum AppThemeMode { system, dark, light, custom }

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode';

  @override
  AppThemeMode build() => AppThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = switch (raw) {
      'light'  => AppThemeMode.light,
      'system' => AppThemeMode.system,
      'custom' => AppThemeMode.custom,
      _        => AppThemeMode.dark,
    };
  }

  Future<void> set(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

// ---------------------------------------------------------------------------
// Font scale
// ---------------------------------------------------------------------------

class FontScaleNotifier extends Notifier<double> {
  static const _key = 'font_scale';

  @override
  double build() => 1.0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? 1.0;
  }

  Future<void> set(double scale) async {
    state = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, scale);
  }
}

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(
  FontScaleNotifier.new,
);

// ---------------------------------------------------------------------------
// Grid columns  (1 | 2 | 3 — portrait preference; landscape auto-bumps +1)
// ---------------------------------------------------------------------------

class GridColumnsNotifier extends Notifier<int> {
  static const _key = 'grid_columns';

  @override
  int build() => 2;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 2;
  }

  Future<void> set(int cols) async {
    state = cols;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, cols);
  }
}

final gridColumnsProvider = NotifierProvider<GridColumnsNotifier, int>(
  GridColumnsNotifier.new,
);

// ---------------------------------------------------------------------------
// Allow rotation  (false = portrait-locked, true = follows device)
// ---------------------------------------------------------------------------

class AllowRotationNotifier extends Notifier<bool> {
  static const _key = 'allow_rotation';

  @override
  bool build() => false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
    await _applyOrientation(state);
  }

  Future<void> set(bool allow) async {
    state = allow;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, allow);
    await _applyOrientation(allow);
  }

  Future<void> _applyOrientation(bool allow) =>
      SystemChrome.setPreferredOrientations(
        allow
            ? [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ],
      );
}

final allowRotationProvider = NotifierProvider<AllowRotationNotifier, bool>(
  AllowRotationNotifier.new,
);

// ---------------------------------------------------------------------------
// Dashboard camera refresh rate
// ---------------------------------------------------------------------------

/// How often each dashboard tile re-fetches its webcam snapshot.
///
/// The dashboard previously pulled snapshots at each printer's Crowsnest
/// "target FPS" (up to ~15 FPS) continuously, for EVERY tile at once — a
/// large, constant data drain, especially over the Cloudflare tunnel. (This
/// was the cause of the "Moongate is spiking network traffic" reports.) This
/// global setting caps the dashboard to a sensible inter-frame interval.
/// `raw` keeps the old per-printer FPS behaviour for users who want a live
/// view and have the bandwidth to spare.
///
/// Scope: this only affects the *dashboard tile* previews. The full-screen
/// printer view is a Mainsail/Fluidd WebView that manages its own stream and
/// is unaffected.
enum DashboardCameraRefresh { raw, oneSecond, threeSeconds, fiveSeconds }

extension DashboardCameraRefreshX on DashboardCameraRefresh {
  /// Fixed inter-frame interval in milliseconds, or null for [raw] — in which
  /// case the tile falls back to the printer's own target FPS (self-throttled
  /// by the sequential fetch loop to whatever the camera can actually deliver).
  int? get intervalMs => switch (this) {
        DashboardCameraRefresh.raw          => null,
        DashboardCameraRefresh.oneSecond    => 1000,
        DashboardCameraRefresh.threeSeconds => 3000,
        DashboardCameraRefresh.fiveSeconds  => 5000,
      };

  /// Short label for the segmented picker.
  String get label => switch (this) {
        DashboardCameraRefresh.raw          => 'Raw',
        DashboardCameraRefresh.oneSecond    => '1s',
        DashboardCameraRefresh.threeSeconds => '3s',
        DashboardCameraRefresh.fiveSeconds  => '5s',
      };
}

class DashboardCameraRefreshNotifier extends Notifier<DashboardCameraRefresh> {
  static const _key = 'dashboard_camera_refresh';

  // Default to a 1 s interval — ~15× less webcam traffic than the old raw
  // feed while still feeling live. Users can opt back into raw in the menu.
  @override
  DashboardCameraRefresh build() => DashboardCameraRefresh.oneSecond;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = DashboardCameraRefresh.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => DashboardCameraRefresh.oneSecond,
    );
  }

  Future<void> set(DashboardCameraRefresh value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}

final dashboardCameraRefreshProvider =
    NotifierProvider<DashboardCameraRefreshNotifier, DashboardCameraRefresh>(
  DashboardCameraRefreshNotifier.new,
);

// ---------------------------------------------------------------------------
// App lock  (optional biometric / PIN gate on launch)
// ---------------------------------------------------------------------------

/// Whether the app requires authentication before the dashboard is reachable.
/// Off by default; enabling it (from the App-lock settings screen) also sets a
/// PIN — see [PinService]. The runtime locked/unlocked state lives in
/// `lockStateProvider`; this is just the persisted on/off preference.
class AppLockEnabledNotifier extends Notifier<bool> {
  static const _key = 'app_lock_enabled';

  @override
  bool build() => false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final appLockEnabledProvider =
    NotifierProvider<AppLockEnabledNotifier, bool>(AppLockEnabledNotifier.new);

/// Whether to offer biometric unlock on top of the PIN. Only meaningful when
/// the lock is enabled AND the device actually has biometric hardware (see
/// `biometricAvailableProvider`). The PIN is always the fallback.
class BiometricUnlockNotifier extends Notifier<bool> {
  static const _key = 'app_lock_biometric';

  @override
  bool build() => false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final biometricUnlockProvider =
    NotifierProvider<BiometricUnlockNotifier, bool>(BiometricUnlockNotifier.new);

/// When the app should re-lock after returning from the background. The lock
/// ALWAYS appears on a cold launch; this only governs re-locking an already
/// running process. Default [coldLaunchOnly] = never re-lock while running.
enum AutoLockTimeout {
  immediately,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  coldLaunchOnly,
}

extension AutoLockTimeoutX on AutoLockTimeout {
  /// How long the app may sit backgrounded before it re-locks, or null to never
  /// re-lock while the process lives (a cold launch still locks).
  Duration? get resumeAfter => switch (this) {
        AutoLockTimeout.immediately    => Duration.zero,
        AutoLockTimeout.oneMinute      => const Duration(minutes: 1),
        AutoLockTimeout.fiveMinutes    => const Duration(minutes: 5),
        AutoLockTimeout.fifteenMinutes => const Duration(minutes: 15),
        AutoLockTimeout.coldLaunchOnly => null,
      };

  String get label => switch (this) {
        AutoLockTimeout.immediately    => 'Immediately',
        AutoLockTimeout.oneMinute      => 'After 1 minute',
        AutoLockTimeout.fiveMinutes    => 'After 5 minutes',
        AutoLockTimeout.fifteenMinutes => 'After 15 minutes',
        AutoLockTimeout.coldLaunchOnly => 'Only on app launch',
      };
}

class AutoLockTimeoutNotifier extends Notifier<AutoLockTimeout> {
  static const _key = 'app_lock_timeout';

  @override
  AutoLockTimeout build() => AutoLockTimeout.coldLaunchOnly;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = AutoLockTimeout.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AutoLockTimeout.coldLaunchOnly,
    );
  }

  Future<void> set(AutoLockTimeout value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}

final autoLockTimeoutProvider =
    NotifierProvider<AutoLockTimeoutNotifier, AutoLockTimeout>(
  AutoLockTimeoutNotifier.new,
);
