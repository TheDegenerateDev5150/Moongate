import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notif_fields.dart';

// ---------------------------------------------------------------------------
// Theme mode
// ---------------------------------------------------------------------------

/// Moongate's theme selector.
///
/// `dark`/`light` map 1:1 onto Flutter's [ThemeMode].
/// `custom` is our own value — when selected, [app.dart] builds the
/// MaterialApp theme from user-picked colours stored in
/// [customThemeProvider] instead of the seeded purple defaults.
enum AppThemeMode { dark, light, custom }

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode';

  @override
  AppThemeMode build() => AppThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = switch (raw) {
      'light'  => AppThemeMode.light,
      'custom' => AppThemeMode.custom,
      // 'system' (a removed option) and anything unknown fall back to Dark.
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
// Auto-arrange by status  (true = sort tiles by live status; false = manual)
// ---------------------------------------------------------------------------

/// Whether the dashboard re-sorts tiles by live status (Error → Printing →
/// Ready → Idle → Offline) on every status change. ON by default — the
/// historic behaviour, which floats active prints to the top.
///
/// Turning it OFF freezes the tiles in the user's own order and unlocks
/// long-press drag-to-reorder on the dashboard grid (the order is persisted by
/// [PrinterRegistry] and rides backups). Without this, a printer coming online
/// or starting a print would yank a hand-placed tile out from under the user.
/// Travels in backups.
class AutoArrangeNotifier extends Notifier<bool> {
  static const _key = 'auto_arrange_by_status';

  @override
  bool build() => true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final autoArrangeProvider =
    NotifierProvider<AutoArrangeNotifier, bool>(AutoArrangeNotifier.new);

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
// Camera config icons  (show/hide the per-tile camera gear)
// ---------------------------------------------------------------------------

/// Whether the small camera-config gear is shown in the corner of each
/// dashboard tile's webcam. On by default; users who don't set custom cameras
/// can turn it off so it never overlaps the image feed. Travels in backups.
class ShowCameraConfigIconsNotifier extends Notifier<bool> {
  static const _key = 'show_camera_config_icons';

  @override
  bool build() => true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool show) async {
    state = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, show);
  }
}

final showCameraConfigIconsProvider =
    NotifierProvider<ShowCameraConfigIconsNotifier, bool>(
  ShowCameraConfigIconsNotifier.new,
);

// ---------------------------------------------------------------------------
// Print notifications  (opt-in foreground-service progress + state alerts)
// ---------------------------------------------------------------------------

/// Whether the background print-notification service is enabled. OFF by default.
/// Turning it on (from the first-run prompt or the menu) requests the Android 13+
/// POST_NOTIFICATIONS permission and starts the foreground service that polls
/// /status to post the persistent progress notification + state-change alerts.
/// This is just the persisted on/off preference — see `PrintNotificationService`
/// for the runtime service.
class PrintNotificationsEnabledNotifier extends Notifier<bool> {
  static const _key = 'print_notifications_enabled';

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

final printNotificationsEnabledProvider =
    NotifierProvider<PrintNotificationsEnabledNotifier, bool>(
  PrintNotificationsEnabledNotifier.new,
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

// ---------------------------------------------------------------------------
// Language / locale
// ---------------------------------------------------------------------------

/// The user's chosen UI language, stored as a bare language code (e.g. 'de').
///
/// `null` means "follow the device's system language" — [app.dart] passes a
/// null `locale` to MaterialApp, so Flutter resolves the system locale against
/// `AppLocalizations.supportedLocales` and falls back to English when the
/// device language isn't one we ship.
///
/// Whether the user has actually been shown the first-run language prompt is
/// tracked separately by the `language_selected` flag in the dashboard
/// onboarding flow — independent of which locale ends up active.
class LocaleNotifier extends Notifier<String?> {
  static const _key = 'app_locale';

  @override
  String? build() => null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    state = (code == null || code.isEmpty) ? null : code;
  }

  /// Set the active language code, or pass `null` to revert to the system
  /// language. Persists to SharedPreferences.
  Future<void> set(String? languageCode) async {
    state = languageCode;
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, languageCode);
    }
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, String?>(LocaleNotifier.new);

// ---------------------------------------------------------------------------
// Notification poll interval
// ---------------------------------------------------------------------------

/// How often the opt-in print-notification foreground service polls each
/// printer's /status. The chosen value is the actual poll rate (no idle
/// backoff) — faster reacts quicker but uses a little more data/battery.
/// Default 30s. Changing it restarts the service (see
/// `PrintNotificationService.reschedule`).
enum NotifPollInterval { s5, s10, s15, s30, m1 }

extension NotifPollIntervalX on NotifPollInterval {
  int get ms => switch (this) {
        NotifPollInterval.s5  => 5000,
        NotifPollInterval.s10 => 10000,
        NotifPollInterval.s15 => 15000,
        NotifPollInterval.s30 => 30000,
        NotifPollInterval.m1  => 60000,
      };

  /// Short segmented-picker label (universal — not localised).
  String get label => switch (this) {
        NotifPollInterval.s5  => '5s',
        NotifPollInterval.s10 => '10s',
        NotifPollInterval.s15 => '15s',
        NotifPollInterval.s30 => '30s',
        NotifPollInterval.m1  => '1m',
      };
}

class NotifPollIntervalNotifier extends Notifier<NotifPollInterval> {
  static const _key = 'notif_poll_interval';

  @override
  NotifPollInterval build() => NotifPollInterval.s30;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = NotifPollInterval.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => NotifPollInterval.s30,
    );
  }

  Future<void> set(NotifPollInterval value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}

final notifPollIntervalProvider =
    NotifierProvider<NotifPollIntervalNotifier, NotifPollInterval>(
  NotifPollIntervalNotifier.new,
);

// ---------------------------------------------------------------------------
// Notification content  (which fields show in the print notification + order)
// ---------------------------------------------------------------------------

/// The set + order of fields shown in the persistent print-status notification
/// (progress, time-remaining, finish-ETA, hotend, bed). Edited on the
/// Notification-content screen; read by the background isolate straight from
/// SharedPreferences (see [NotifFieldsConfig.fromPrefs]). Travels in backups.
class NotificationFieldsNotifier extends Notifier<NotifFieldsConfig> {
  @override
  NotifFieldsConfig build() => NotifFieldsConfig.defaults();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotifFieldsConfig.fromPrefs(
      prefs.getString(kNotifFieldsOrderKey),
      prefs.getString(kNotifFieldsEnabledKey),
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kNotifFieldsOrderKey, state.orderPref);
    await prefs.setString(kNotifFieldsEnabledKey, state.enabledPref);
  }

  /// Show or hide [field].
  Future<void> setEnabled(NotifField field, bool on) async {
    final next = {...state.enabled};
    if (on) {
      next.add(field);
    } else {
      next.remove(field);
    }
    state = NotifFieldsConfig(state.order, next);
    await _persist();
  }

  /// Move a field within the display order (ReorderableListView indices).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final order = List.of(state.order);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = order.removeAt(oldIndex);
    order.insert(newIndex, moved);
    state = NotifFieldsConfig(order, state.enabled);
    await _persist();
  }
}

final notificationFieldsProvider =
    NotifierProvider<NotificationFieldsNotifier, NotifFieldsConfig>(
  NotificationFieldsNotifier.new,
);

// ---------------------------------------------------------------------------
// Webcams on/off  (master switch for the dashboard tile camera feeds)
// ---------------------------------------------------------------------------

/// Whether the dashboard tiles show (and fetch) their webcam feeds. On by
/// default. Turning it off stops every tile's snapshot polling and shows the
/// placeholder instead — a quick data-saver, and it lets an on-demand camera
/// (e.g. go2rtc) drop its stream and idle. The full-screen camera view, which
/// the user opens deliberately, ignores this. Travels in backups.
class WebcamsEnabledNotifier extends Notifier<bool> {
  static const _key = 'webcams_enabled';

  @override
  bool build() => true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final webcamsEnabledProvider =
    NotifierProvider<WebcamsEnabledNotifier, bool>(WebcamsEnabledNotifier.new);
