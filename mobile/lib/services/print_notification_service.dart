import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:ui' as ui;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../models/printer_config.dart';
import 'printer_registry.dart';
import 'supabase_service.dart';

// ── Tuning ────────────────────────────────────────────────────────────────
const _serviceChannelId   = 'moongate_print_progress';
const _serviceChannelName = 'Print progress';
const _alertsChannelId    = 'moongate_print_alerts';
const _alertsChannelName   = 'Print status';
const _serviceId          = 4711;

// Poll every 30s while a print is active; back off to ~2 min when everything is
// idle (just to catch a print starting). LAN-first, so it's free at home and a
// long print costs ~1-2 MB over cellular.
const _pollIntervalMs   = 30000;
const _idleSkipCycles   = 4;     // when idle: poll only every Nth 30s tick

/// Main-isolate manager for the opt-in print-notification foreground service.
/// The actual polling runs in a background isolate (`_PrintTaskHandler`) so it
/// survives the UI being backgrounded. OFF by default — see
/// `printNotificationsEnabledProvider`.
class PrintNotificationService {
  PrintNotificationService._();
  static final PrintNotificationService instance = PrintNotificationService._();

  bool _configured = false;

  void _configure() {
    if (_configured) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _serviceChannelId,
        channelName: _serviceChannelName,
        channelDescription: 'Live print progress while notifications are on.',
        // LOW + onlyAlertOnce: a silent, persistent progress notification that
        // updates in place without buzzing on every percent.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(_pollIntervalMs),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _configured = true;
  }

  /// Request the Android 13+ POST_NOTIFICATIONS permission. Returns true when
  /// granted. Safe to call before [start].
  Future<bool> requestPermission() async {
    _configure();
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  /// Start the foreground service if it isn't already running.
  Future<void> start() async {
    _configure();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Moongate',
      notificationText: 'Watching your printers…',
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
  bool _wasActive = true;   // poll on the first tick, then back off when idle
  int  _idleTick = 0;
  final Map<String, String> _lastState = {};

  void _log(String msg) => dev.log(msg, name: 'MOONGATE/NOTIF');

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Background isolate: register plugins so http / shared_preferences /
    // supabase channels work here.
    try {
      ui.DartPluginRegistrant.ensureInitialized();
    } catch (_) {}

    await _alerts.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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

    _tick(); // immediate first poll so the notification isn't empty for 30s
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _tick();

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _tick() async {
    if (_busy) return;
    // Idle backoff: when nothing was printing last tick, only poll every Nth
    // 30s tick (~2 min) to save data; poll every tick while a print is active.
    if (!_wasActive) {
      _idleTick = (_idleTick + 1) % _idleSkipCycles;
      if (_idleTick != 0) return;
    }
    _busy = true;
    try {
      await PrinterRegistry.instance.load();
      final printers = PrinterRegistry.instance.printers;

      final lines = <String>[];
      var anyActive = false;

      for (final p in printers) {
        final s = await _poll(p);
        if (s == null) continue;

        final prev = _lastState[p.id];
        if (prev != null && prev != s.state) {
          _maybeAlert(p.name, prev, s.state);
        }
        _lastState[p.id] = s.state;

        if (s.state == 'printing' || s.state == 'paused') {
          anyActive = true;
          lines.add(_progressLine(p.name, s));
        }
      }

      await _updatePersistent(lines);
      _wasActive = anyActive;
    } catch (e) {
      _log('tick failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _updatePersistent(List<String> lines) async {
    if (lines.isEmpty) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Moongate',
        notificationText: 'No active prints',
      );
    } else if (lines.length == 1) {
      await FlutterForegroundTask.updateService(
        notificationTitle: lines.first,
        notificationText: '',
      );
    } else {
      // Stack one line per active print; Android shows them all when expanded.
      await FlutterForegroundTask.updateService(
        notificationTitle: '${lines.length} printers printing',
        notificationText: lines.join('\n'),
      );
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  Future<_Poll?> _poll(PrinterConfig p) async {
    final PrinterAccess access;
    try {
      access = await SupabaseService.instance.getPrinterAccess(p.id);
    } catch (_) {
      return null; // offline / not yet heartbeated / network
    }
    final bases = <String>[
      if (p.lanUrl != null && p.lanUrl!.isNotEmpty) p.lanUrl!,
      if (access.tunnelUrl != null && access.tunnelUrl!.isNotEmpty)
        access.tunnelUrl!,
    ];
    for (final base in bases) {
      final r = await _fetchStatus(base, access.accessToken);
      if (r != null) return r;
    }
    return null;
  }

  Future<_Poll?> _fetchStatus(String base, String token) async {
    try {
      final uri = Uri.parse(
          '$base/server/moongate/status?mg_token=${Uri.encodeComponent(token)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>?;
      final status = result?['status'] as Map<String, dynamic>?;
      if (status == null) return null;

      final printStats = status['print_stats']    as Map<String, dynamic>? ?? const {};
      final extruder   = status['extruder']        as Map<String, dynamic>? ?? const {};
      final bed        = status['heater_bed']      as Map<String, dynamic>? ?? const {};
      final display    = status['display_status']  as Map<String, dynamic>? ?? const {};
      final sdcard     = status['virtual_sdcard']  as Map<String, dynamic>? ?? const {};

      var progress = (display['progress'] as num?)?.toDouble() ?? 0;
      if (progress <= 0) progress = (sdcard['progress'] as num?)?.toDouble() ?? 0;

      return _Poll(
        state:            (printStats['state'] as String?) ?? 'standby',
        progress:         progress.clamp(0.0, 1.0),
        printDurationSec: (printStats['print_duration'] as num?)?.toDouble() ?? 0,
        hotend:           (extruder['temperature'] as num?)?.toDouble() ?? 0,
        bed:              (bed['temperature']      as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Formatting ──────────────────────────────────────────────────────────────

  String _progressLine(String name, _Poll s) {
    final pct = (s.progress * 100).round();
    final temps = '${s.hotend.round()}°/${s.bed.round()}°';
    if (s.state == 'paused') return '$name — $pct% · paused · $temps';
    final eta = _formatEta(s);
    return eta != null
        ? '$name — $pct% · ~$eta left · $temps'
        : '$name — $pct% · $temps';
  }

  /// Remaining time estimated from elapsed/progress (no extra metadata call).
  /// Null while it's too early to be meaningful.
  String? _formatEta(_Poll s) {
    if (s.state != 'printing') return null;
    if (s.progress < 0.02 || s.printDurationSec < 30) return null;
    final remaining = s.printDurationSec * (1 - s.progress) / s.progress;
    if (remaining <= 0 || remaining > 100 * 3600) return null;
    final d = Duration(seconds: remaining.round());
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  // ── State-change alerts ─────────────────────────────────────────────────────

  void _maybeAlert(String name, String from, String to) {
    final String? body = switch (to) {
      'printing'  => from == 'paused' ? 'Resumed printing' : 'Started printing',
      'paused'    => 'Print paused',
      'complete'  => 'Print complete',
      'cancelled' => 'Print cancelled',
      'error'     => 'Printer error',
      _           => null, // standby / startup / etc. — no alert
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
  final double bed;
  const _Poll({
    required this.state,
    required this.progress,
    required this.printDurationSec,
    required this.hotend,
    required this.bed,
  });
}
