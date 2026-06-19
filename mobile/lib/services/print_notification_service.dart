import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:ui' as ui;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/notif_fields.dart';
import '../models/printer_config.dart';
import 'printer_access_cache.dart';
import 'printer_registry.dart';
import 'supabase_service.dart';

// ── Tuning ────────────────────────────────────────────────────────────────
// The persistent foreground notification is the live STATUS list of every
// printer, so its user-facing channel is named "Print status"; the discrete
// one-shot pop-ups are "Print alerts". The channel IDs keep their original
// 'progress'/'alerts' slugs so existing users' on/off choices carry over —
// only the display names changed (v0.9.3; were "Print progress" / "Print
// status", which read backwards relative to what each one controlled).
const _serviceChannelId   = 'moongate_print_progress';
const _serviceChannelName = 'Print status';
const _alertsChannelId    = 'moongate_print_alerts';
const _alertsChannelName   = 'Print alerts';
const _serviceId          = 4711;

// Default poll cadence, overridden by the user's "Update frequency" setting
// (`notif_poll_interval`). The chosen interval is the ACTUAL poll rate — there
// is no idle backoff, so a print start / error / recovery shows within one
// tick. LAN-first, so it's free at home and a long print costs ~1-2 MB cellular.
const _defaultPollIntervalMs = 30000;

/// Map the persisted `notif_poll_interval` enum name to milliseconds.
int _pollIntervalMsFromPref(String? name) => switch (name) {
      's5'  => 5000,
      's10' => 10000,
      's15' => 15000,
      'm1'  => 60000,
      _     => _defaultPollIntervalMs, // 's30' / unset
    };

/// Load the user's chosen UI locale (or the system / English fallback) and
/// return its AppLocalizations. Usable from the background isolate — it's a pure
/// Dart load with no BuildContext — so the notification reads in the same
/// language as the app even though it runs outside the widget tree.
Future<AppLocalizations> _loadL10n() async {
  var code = (await SharedPreferences.getInstance()).getString('app_locale');
  code ??= ui.PlatformDispatcher.instance.locale.languageCode;
  try {
    return await AppLocalizations.delegate.load(ui.Locale(code));
  } catch (_) {
    return AppLocalizations.delegate.load(const ui.Locale('en'));
  }
}

/// Main-isolate manager for the opt-in print-notification foreground service.
/// The actual polling runs in a background isolate (`_PrintTaskHandler`) so it
/// survives the UI being backgrounded. OFF by default — see
/// `printNotificationsEnabledProvider`.
class PrintNotificationService {
  PrintNotificationService._();
  static final PrintNotificationService instance = PrintNotificationService._();

  bool _configured = false;
  int  _configuredIntervalMs = _defaultPollIntervalMs;

  /// Read the user's chosen poll interval (ms) from SharedPreferences.
  Future<int> _readPollIntervalMs() async {
    final prefs = await SharedPreferences.getInstance();
    return _pollIntervalMsFromPref(prefs.getString('notif_poll_interval'));
  }

  void _configure(int intervalMs) {
    if (_configured && _configuredIntervalMs == intervalMs) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _serviceChannelId,
        channelName: _serviceChannelName,
        channelDescription: 'A live, at-a-glance status of all your printers.',
        // LOW + onlyAlertOnce: a silent, persistent progress notification that
        // updates in place without buzzing on every percent.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(intervalMs),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _configured = true;
    _configuredIntervalMs = intervalMs;
  }

  /// Request the Android 13+ POST_NOTIFICATIONS permission. Returns true when
  /// granted. Safe to call before [start].
  Future<bool> requestPermission() async {
    _configure(await _readPollIntervalMs());
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  /// Start the foreground service if it isn't already running.
  Future<void> start() async {
    _configure(await _readPollIntervalMs());
    if (await FlutterForegroundTask.isRunningService) return;
    final l = await _loadL10n();
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Moongate',
      notificationText: l.printNotifWatching,
      notificationIcon: const NotificationIcon(
          metaDataName: 'com.moongate.app.notification_icon'),
      callback: startPrintNotificationCallback,
    );
  }

  /// Stop the foreground service if it is running.
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Align the running service with the persisted on/off toggle. Called at
  /// startup and whenever the toggle changes.
  Future<void> sync(bool enabled) => enabled ? start() : stop();

  /// Re-read the poll interval and, if the service is running, restart it so a
  /// new cadence takes effect at once (the repeat interval is fixed at service
  /// start, so changing it needs a stop/start).
  Future<void> reschedule() async {
    if (await FlutterForegroundTask.isRunningService) {
      await stop();
      await start();
    }
  }

  /// Poke the running background task to refresh the notification immediately —
  /// call after the printer set changes (pair / remove / restore) so it updates
  /// at once instead of waiting for the next poll. No-op when off.
  Future<void> refreshNow() async {
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask('refresh');
    }
  }
}

/// Foreground-task isolate entry point. MUST be a top-level function.
@pragma('vm:entry-point')
void startPrintNotificationCallback() {
  FlutterForegroundTask.setTaskHandler(_PrintTaskHandler());
}

/// Runs in the background isolate. On each tick it polls every printer's
/// `/status`, refreshes the persistent progress notification (one line per
/// active print), and fires one-shot alerts on state transitions.
class _PrintTaskHandler extends TaskHandler {
  final _alerts = FlutterLocalNotificationsPlugin();
  bool _busy = false;
  final Map<String, String> _lastState = {};
  late AppLocalizations _l;
  // Which notification segments to show + their order — re-read from prefs each
  // tick (the user edits them on the main isolate). Defaults to all-on.
  NotifFieldsConfig _fields = NotifFieldsConfig.defaults();

  void _log(String msg) => dev.log(msg, name: 'MOONGATE/NOTIF');

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Background isolate: register plugins so http / shared_preferences /
    // supabase channels work here.
    try {
      ui.DartPluginRegistrant.ensureInitialized();
    } catch (_) {}

    await _alerts.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_moongate'),
    ));
    await _alerts
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _alertsChannelId,
          _alertsChannelName,
          description: 'Print started / paused / finished / error alerts.',
          importance: Importance.high,
        ));

    // Supabase in this isolate re-loads the persisted anon session, so it can
    // mint the same per-printer access tokens the app uses.
    try {
      await SupabaseService.instance.initialize();
    } catch (e) {
      _log('Supabase init failed in isolate: $e');
    }

    _l = await _loadL10n(); // localise the notification to the app's language

    // Locale-aware 12/24h clock for the print-finish ETA. This background
    // isolate has no BuildContext (so no TimeOfDay.format); intl's locale
    // formatter needs its symbol data loaded once before DateFormat.jm runs.
    try {
      await initializeDateFormatting();
    } catch (_) {}

    _tick(); // immediate first poll so the notification isn't empty for 30s
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _tick();

  @override
  void onReceiveData(Object data) {
    // Main app signalled a printer add / remove / restore — refresh now rather
    // than waiting for the next 30s/2min tick. _tick() reloads the registry
    // from disk, so it picks up the change immediately.
    _tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      // Re-read the notification-content config the user may have changed on the
      // main isolate. SharedPreferences caches per-isolate, so reload() first or
      // we'd never see their edits (same gotcha as the printer-set refresh).
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _fields = NotifFieldsConfig.fromPrefs(
        prefs.getString(kNotifFieldsOrderKey),
        prefs.getString(kNotifFieldsEnabledKey),
      );

      await PrinterRegistry.instance.load();
      final printers = PrinterRegistry.instance.printers;

      final entries = <(String, _Poll?)>[];

      for (final p in printers) {
        final s = await _poll(p);

        // Only a LIVE /status read (a genuine Klipper state) drives alerts and
        // updates the remembered state. A connectivity placeholder (synthetic
        // Idle, live == false) or an offline tick (s == null) must NOT touch
        // _lastState — otherwise a transient network blip rewrites it, and the
        // return to the real state then looks like a fresh transition. That was
        // the "repeated print-cancelled alert on every WiFi⇄cellular switch".
        if (s != null && s.live) {
          final prev = _lastState[p.id];
          if (prev != null && prev != s.state) {
            _maybeAlert(p.name, prev, s.state);
          }
          _lastState[p.id] = s.state;
        }

        entries.add((p.name, s)); // every printer, online or not
      }

      // Float active prints to the top — same ranking the dashboard uses
      // (printerStatusRank), stable within a tier (original order preserved).
      final ranked = [for (var i = 0; i < entries.length; i++) (i, entries[i])];
      ranked.sort((a, b) {
        final ra = _rank(a.$2.$2);
        final rb = _rank(b.$2.$2);
        return ra != rb ? ra.compareTo(rb) : a.$1.compareTo(b.$1);
      });
      final sorted = [for (final r in ranked) r.$2];

      await _updatePersistent(sorted);
    } catch (e) {
      _log('tick failed: $e');
    } finally {
      _busy = false;
    }
  }

  /// Sort rank for a printer's notification line — shares printerStatusRank
  /// with the dashboard so the two orderings stay identical. A warming printer
  /// counts as 'heating' (Printing tier); an unreachable one as 'offline'.
  int _rank(_Poll? s) {
    if (s == null) return printerStatusRank('offline');
    if (_warming(s)) return printerStatusRank('heating');
    return printerStatusRank(s.state);
  }

  Future<void> _updatePersistent(List<(String, _Poll?)> entries) async {
    final String title;
    final String text;
    if (entries.isEmpty) {
      title = 'Moongate';
      text = _l.printNotifNoPrinters;
    } else if (entries.length == 1) {
      // Single printer: emoji + full status on the title line.
      title = _statusLine(entries.first.$1, entries.first.$2, withEmoji: true);
      text = '';
    } else {
      // Collapsed glance = just the status emojis (one per printer, in order).
      // Expanded body = the full per-printer lines, with NO repeated emoji so
      // it reads cleanly rather than busy.
      title = entries.map((e) => _emoji(e.$2)).join(' ');
      text = entries.map((e) => _statusLine(e.$1, e.$2)).join('\n');
    }
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  Future<_Poll?> _poll(PrinterConfig p) async {
    final PrinterAccess access;
    try {
      // Cached per-isolate so a 30 s / 5 s poll loop reuses one token for
      // ~4.5 min instead of minting a fresh one from /printer-access on every
      // single tick. Running 24/7 in this foreground service, the uncached call
      // was a major source of Edge Function invocations — even for printers
      // that are powered off (their last token mints fine regardless).
      access = await PrinterAccessCache.instance.get(p.id);
    } catch (_) {
      return null; // offline / not yet heartbeated / network
    }
    final bases = <(String, bool)>[
      if (p.lanUrl != null && p.lanUrl!.isNotEmpty) (p.lanUrl!, true),
      if (access.tunnelUrl != null && access.tunnelUrl!.isNotEmpty)
        (access.tunnelUrl!, false),
    ];
    for (final (base, isLan) in bases) {
      final r = await _fetchStatus(base, access.accessToken, isLan);
      if (r != null) return r;
    }
    // No /status answer on any path. Distinguish a Pi that's up but whose
    // Moongate/Klipper stack isn't responding (Idle) from one that's genuinely
    // unreachable / powered off (Offline). A stale tunnel URL lingers in the
    // cloud after a Pi shuts down (printer-access still hands back the last
    // known one), so "a tunnel URL exists" is NOT proof of life — probe like
    // the dashboard does. The synthetic Idle is marked live: false so it never
    // drives a state-change alert.
    if (await _isReachable(p, access)) {
      return const _Poll(
        state: 'waiting',
        progress: 0,
        printDurationSec: 0,
        hotend: 0,
        hotendTarget: 0,
        bed: 0,
        bedTarget: 0,
        live: false,
      );
    }
    return null; // genuinely unreachable → Offline
  }

  /// HEAD the LAN and tunnel bases: ANY HTTP answer (even a 401 / 502) proves
  /// the host is up; only a thrown error means nothing is listening. Mirrors
  /// [PrinterStatusService] `_isPiReachable` so the notification's
  /// Idle-vs-Offline call matches the dashboard's. Used after every /status
  /// path has failed, to avoid labelling a powered-off printer "Idle".
  Future<bool> _isReachable(PrinterConfig p, PrinterAccess access) async {
    final candidates = <String>[
      if (p.lanUrl != null && p.lanUrl!.isNotEmpty) p.lanUrl!,
      if (access.tunnelUrl != null && access.tunnelUrl!.isNotEmpty)
        access.tunnelUrl!,
    ];
    for (final base in candidates) {
      try {
        await http.head(Uri.parse(base)).timeout(const Duration(seconds: 4));
        return true;
      } catch (_) {
        // Refused / timeout / DNS — try the next candidate.
      }
    }
    return false;
  }

  Future<_Poll?> _fetchStatus(String base, String token, bool isLan) async {
    try {
      final uri = Uri.parse(
          '$base/server/moongate/status?mg_token=${Uri.encodeComponent(token)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>?;
      final status = result?['status'] as Map<String, dynamic>?;
      if (status == null) return null;

      final printStats = status['print_stats'] as Map<String, dynamic>? ?? const {};
      final extruder   = status['extruder']     as Map<String, dynamic>? ?? const {};
      final bed        = status['heater_bed']   as Map<String, dynamic>? ?? const {};

      // The plugin's /status returns ONLY print_stats / heater_bed / extruder —
      // progress lives in display_status & virtual_sdcard, which aren't in this
      // payload. Mirror PrinterStatusService and pull them from a supplementary
      // /printer/objects/query, otherwise % stays pinned at 0 the whole print.
      var display = status['display_status'] as Map<String, dynamic>?;
      var sdcard  = status['virtual_sdcard'] as Map<String, dynamic>?;
      if (display == null || sdcard == null) {
        final supp = await _fetchProgress(base, token, isLan: isLan);
        display ??= supp?['display_status'] as Map<String, dynamic>?;
        sdcard  ??= supp?['virtual_sdcard'] as Map<String, dynamic>?;
      }

      var progress = (display?['progress'] as num?)?.toDouble() ?? 0;
      if (progress <= 0) progress = (sdcard?['progress'] as num?)?.toDouble() ?? 0;

      return _Poll(
        state:            (printStats['state'] as String?) ?? 'standby',
        progress:         progress.clamp(0.0, 1.0),
        printDurationSec: (printStats['print_duration'] as num?)?.toDouble() ?? 0,
        hotend:           (extruder['temperature'] as num?)?.toDouble() ?? 0,
        hotendTarget:     (extruder['target']      as num?)?.toDouble() ?? 0,
        bed:              (bed['temperature']      as num?)?.toDouble() ?? 0,
        bedTarget:        (bed['target']           as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Supplementary progress fetch. The moongate /status payload omits
  /// display_status & virtual_sdcard, so read them straight from Moonraker:
  /// LAN goes through nginx untouched (no auth header — Moonraker would reject
  /// our EdDSA token as a bad JWT), the tunnel goes through the auth proxy
  /// (Bearer). Best-effort — null on any failure just leaves progress at 0.
  Future<Map<String, dynamic>?> _fetchProgress(String base, String token,
      {required bool isLan}) async {
    try {
      final uri = Uri.parse(
          '$base/printer/objects/query?display_status&virtual_sdcard');
      final resp = await http
          .get(uri, headers: isLan ? null : {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['result']?['status'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // ── Formatting ──────────────────────────────────────────────────────────────

  /// True while a heater is still ramping to a set target and we should show a
  /// "Heating" line instead of the static Ready/Idle/0% label — i.e. pre-print
  /// soak, or the start of a print before extrusion (progress still ~0). Not
  /// for a paused print, where "Paused x%" is the more useful line.
  bool _warming(_Poll s) =>
      s.isHeating &&
      s.state != 'paused' &&
      (s.state != 'printing' || s.progress < 0.02);

  /// One status line per printer for the persistent notification: Offline when
  /// unreachable, Heating during warm-up, the rich progress line while printing,
  /// otherwise a friendly label (Ready / Idle / Paused / Complete / Error).
  String _statusLine(String name, _Poll? s, {bool withEmoji = false}) {
    final e = withEmoji ? '${_emoji(s)} ' : '';
    if (s == null) return '$e$name — ${_l.printStatusOffline}';
    if (_warming(s)) {
      final parts = <String>[
        if (s.hotendTarget > 0) '${s.hotend.round()}→${s.hotendTarget.round()}°',
        if (s.bedTarget > 0) '${s.bed.round()}→${s.bedTarget.round()}°',
      ];
      return '$e$name — ${_l.printStatusHeating} · ${parts.join(' · ')}';
    }
    switch (s.state) {
      case 'printing':
        return _composeLine(e, name, s);
      case 'paused':
        return _composeLine(e, name, s, label: _l.printStatusPaused);
      case 'complete':
        return '$e$name — ${_l.printStatusComplete}';
      case 'cancelled':
        return '$e$name — ${_l.printStatusCancelled}';
      case 'error':
        return '$e$name — ${_l.printStatusError}';
      case 'startup':
      case 'starting_up':
      case 'connecting':
        return '$e$name — ${_l.printStatusStartingUp}';
      case 'waiting':
        return '$e$name — ${_l.printStatusIdle}';
      case 'standby':
      default:
        return '$e$name — ${_l.printStatusReady}';
    }
  }

  /// Assemble a printer's line from the user-chosen field set + order
  /// ([_fields]). [label] (e.g. "Paused") leads the detail when present; the
  /// enabled segments follow, joined by " · ". A field that doesn't apply yet
  /// (remaining/ETA too early) or is switched off is skipped; with every field
  /// off the line collapses to just the emoji + name.
  String _composeLine(String prefix, String name, _Poll s, {String? label}) {
    final segs = <String>[];
    if (label != null) segs.add(label);
    for (final f in _fields.order) {
      if (!_fields.enabled.contains(f)) continue;
      final seg = _fieldSegment(f, s);
      if (seg != null) segs.add(seg);
    }
    return segs.isEmpty ? '$prefix$name' : '$prefix$name — ${segs.join(' · ')}';
  }

  /// Render one configured [field] for state [s], or null when it doesn't apply
  /// (e.g. remaining/ETA before the print is far enough along to estimate).
  String? _fieldSegment(NotifField field, _Poll s) {
    switch (field) {
      case NotifField.progress:
        return '${(s.progress * 100).round()}%';
      case NotifField.remaining:
        final rem = _remainingSeconds(s);
        return rem == null ? null : '~${_formatRemaining(rem)}';
      case NotifField.eta:
        final rem = _remainingSeconds(s);
        if (rem == null) return null;
        final clock = _formatFinishClock(rem);
        return clock == null ? null : '$kNotifEtaMarker$clock';
      case NotifField.hotend:
        return '$kNotifHotendMarker${s.hotend.round()}°';
      case NotifField.bed:
        return '$kNotifBedMarker${s.bed.round()}°';
    }
  }

  /// Status emoji used as the line / summary prefix.
  String _emoji(_Poll? s) {
    if (s == null) return '⚫';
    if (_warming(s)) return '🔥';
    switch (s.state) {
      case 'printing':
        return '🖨️';
      case 'paused':
        return '⏸️';
      case 'complete':
        return '✅';
      case 'error':
        return '🔴';
      case 'waiting':
        return '🟡';
      case 'startup':
      case 'starting_up':
      case 'connecting':
        return '⏳';
      case 'standby':
      default:
        return '🟢';
    }
  }

  /// Print time remaining (seconds), estimated from elapsed/progress with no
  /// extra metadata call. Null while it's too early — or implausibly long — to
  /// be meaningful.
  double? _remainingSeconds(_Poll s) {
    if (s.state != 'printing') return null;
    if (s.progress < 0.02 || s.printDurationSec < 30) return null;
    final remaining = s.printDurationSec * (1 - s.progress) / s.progress;
    if (remaining <= 0 || remaining > 100 * 3600) return null;
    return remaining;
  }

  /// "1h05m" / "14m" — how much longer the print has to run.
  String _formatRemaining(double seconds) {
    final d = Duration(seconds: seconds.round());
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  /// Wall-clock time the print is projected to finish ("1:20 AM" / "13:20"),
  /// localised 12/24h via the loaded UI locale — the same "ETA" Klipper and
  /// Mainsail display. Null if the locale's date symbols didn't load, so the
  /// line just falls back to showing the remaining duration alone.
  String? _formatFinishClock(double remainingSeconds) {
    try {
      final finish =
          DateTime.now().add(Duration(seconds: remainingSeconds.round()));
      return DateFormat.jm(_l.localeName).format(finish);
    } catch (_) {
      return null;
    }
  }

  // ── State-change alerts ─────────────────────────────────────────────────────

  void _maybeAlert(String name, String from, String to) {
    // A finished / failed print is only a real *event* when we were actually
    // printing just before. Klipper keeps the last result in print_stats.state
    // (it stays 'complete' / 'cancelled' / 'error' until the next print), so
    // arriving at one of those from an idle state is a re-observation, not a
    // new event — alerting on it produces duplicate buzzes (the cross-network
    // "cancelled" spam). Genuine transitions always come from printing/paused.
    final wasPrinting = from == 'printing' || from == 'paused';
    final String? body = switch (to) {
      'printing'  => from == 'paused' ? _l.printAlertResumed : _l.printAlertStarted,
      'paused'    => from == 'printing' ? _l.printAlertPaused : null,
      'complete'  => wasPrinting ? _l.printAlertComplete  : null,
      'cancelled' => wasPrinting ? _l.printAlertCancelled : null,
      'error'     => wasPrinting ? _l.printAlertError     : null,
      // Recovery: only when coming back from an error (e.g. a firmware restart),
      // not on a normal idle/boot transition — those would be noise.
      'standby'   => from == 'error' ? _l.printAlertReady : null,
      _           => null,
    };
    if (body == null) return;
    _alerts.show(
      name.hashCode & 0x7fffffff, // one alert slot per printer (latest wins)
      name,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertsChannelId,
          _alertsChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_moongate',
        ),
      ),
    );
  }
}

/// A single printer's parsed status — just what the notification needs.
class _Poll {
  final String state;
  final double progress;        // 0..1
  final double printDurationSec;
  final double hotend;
  final double hotendTarget;
  final double bed;
  final double bedTarget;

  /// True when this came from a real /status read (a genuine Klipper state).
  /// False for the synthesized "reachable but /status didn't answer" Idle
  /// placeholder — those must never drive a state-change alert (see _tick).
  final bool live;
  const _Poll({
    required this.state,
    required this.progress,
    required this.printDurationSec,
    required this.hotend,
    required this.hotendTarget,
    required this.bed,
    required this.bedTarget,
    this.live = true,
  });

  // A heater is actively ramping when it has a real target set and the current
  // reading is still meaningfully below it. Drives the "Heating" line during
  // pre-print soak / the start of a print before extrusion — when print_stats
  // is still standby (or printing at 0%) and nothing about the heaters would
  // otherwise show. `_heatTargetFloor` ignores low "keep-warm" trickle targets.
  static const double _heatTargetFloor = 35;
  static const double _heatMargin      = 3;
  bool _ramping(double cur, double tgt) =>
      tgt > _heatTargetFloor && (tgt - cur) > _heatMargin;
  bool get isHeating => _ramping(hotend, hotendTarget) || _ramping(bed, bedTarget);
}
