import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../providers/custom_theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/version_provider.dart';
import '../../services/print_notification_service.dart';
import '../../services/printer_access_cache.dart';
import '../../services/printer_registry.dart';
import '../../services/printer_status_registry.dart';
import '../../services/settings_backup.dart';
import '../../services/supabase_service.dart';
import '../../services/update_service.dart';
import '../info/ui_guide.dart';
import '../language/language_picker.dart';
import '../notifications/notifications_prompt.dart';
import 'feedback_sheet.dart';
import 'printer_tile.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<PrinterConfig> _printers = [];
  bool _updateDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Show the pairing/reinstall explainer on cold launch until the user opts
    // out ("Don't show again"). Post-frame so the dialog has a mounted context.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _runFirstRunOnboarding().ignore());
  }

  void _load() {
    final list = PrinterRegistry.instance.printers;
    if (mounted) setState(() => _printers = list);
    // Keep the print-notification isolate's printer list in step — it reads a
    // separate cached snapshot, so poke it whenever the set may have changed
    // (pair / remove / restore). No-op when notifications are off.
    PrintNotificationService.instance.refreshNow().ignore();
  }

  /// Stable-sort the printer list by live status priority (printerStatusRank,
  /// shared with the notification): Error → Printing → Ready → Idle → Offline,
  /// keeping the added/dashboard order within each tier. A printer that hasn't
  /// polled yet counts as 'connecting' (Idle tier). Recomputed on every status
  /// change via the StreamBuilder in build().
  List<PrinterConfig> _sortByStatus(List<PrinterConfig> list) {
    final ranked = [
      for (var i = 0; i < list.length; i++)
        (
          i,
          list[i],
          printerStatusRank(
            PrinterStatusRegistry.instance.snapshot(list[i].id)?.state ??
                'connecting',
          ),
        ),
    ];
    ranked.sort(
        (a, b) => a.$3 != b.$3 ? a.$3.compareTo(b.$3) : a.$1.compareTo(b.$1));
    return [for (final r in ranked) r.$2];
  }

  Future<void> _removePrinter(PrinterConfig printer) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.dashboardRemovePrinterTitle),
        content: Text(l.dashboardRemovePrinterBody(printer.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Release the Supabase row first so the same Pi can be re-paired
    // without manual cleanup. Fail-open: if Supabase is unreachable we
    // still clear local state and surface a hint so the user isn't trapped.
    final released = await SupabaseService.instance.releasePrinter(printer.id);
    await PrinterRegistry.instance.remove(printer.id);
    PrinterAccessCache.instance.invalidate(printer.id);

    if (!released && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.dashboardRemoveSupabaseUnreachable),
        ),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Check for update — runs once per session, silently ignored on failure.
    final updateAsync = ref.watch(updateProvider);
    final update = _updateDismissed ? null : updateAsync.valueOrNull;

    final gridColumns = ref.watch(gridColumnsProvider);

    final body = _printers.isEmpty
        ? _EmptyState(onAddPrinter: () => context.push('/pair').then((_) => _load()))
        // Re-sort tiles by live status (active prints float up) whenever a
        // printer's state changes — printerStatusRank, shared with the
        // notification. Tiles are keyed by id so a reorder moves a tile (and
        // its poller) rather than rebuilding it.
        : StreamBuilder<void>(
            stream: PrinterStatusRegistry.instance.changes,
            builder: (context, _) => _PrinterGrid(
              printers: _sortByStatus(_printers),
              columns:  gridColumns,
              // Reload after the printer screen pops so any rename done in
              // the app bar there propagates to the tile.
              onTap:    (p) => context.push('/printer/${p.id}').then((_) => _load()),
              onRemove: _removePrinter,
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The Moongate moon-gate logo beside the wordmark.
            SvgPicture.asset('assets/icons/moongate_icon.svg',
                width: 26, height: 26),
            const SizedBox(width: 8),
            const Text('Moongate'),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: l.dashboardMenuTooltip,
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildDrawer(context),
      body: update != null
          ? Column(
              children: [
                _UpdateBanner(
                  update: update,
                  onDismiss: () => setState(() => _updateDismissed = true),
                ),
                Expanded(child: body),
              ],
            )
          : body,
      floatingActionButton: _printers.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await context.push('/pair');
                _load();
              },
              tooltip: l.dashboardAddPrinter,
              child: const Icon(Icons.add),
            ),
    );
  }

  /// Toggle the opt-in print-notification service. Turning it ON first asks for
  /// the Android 13+ notification permission; if denied, the toggle stays off.
  Future<void> _togglePrintNotifications(bool enable) async {
    if (enable) {
      final granted =
          await PrintNotificationService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context).printNotifPermissionNeeded),
          ));
        }
        return; // leave the toggle off
      }
    }
    await ref.read(printNotificationsEnabledProvider.notifier).set(enable);
    await PrintNotificationService.instance.sync(enable);
  }

  Widget _buildDrawer(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fontScale     = ref.watch(fontScaleProvider);
    final themeMode     = ref.watch(themeModeProvider);
    final gridColumns   = ref.watch(gridColumnsProvider);
    final allowRotation = ref.watch(allowRotationProvider);
    final cameraRefresh = ref.watch(dashboardCameraRefreshProvider);
    final printNotifications = ref.watch(printNotificationsEnabledProvider);
    final pollInterval = ref.watch(notifPollIntervalProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.print,
                      color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text('Moongate',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            const Divider(),

            // ── Scrollable body (safe in landscape / small screens) ──────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Printer management
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(l.dashboardAddPrinter),
                      onTap: () async {
                        Navigator.pop(context);
                        await context.push('/pair');
                        _load();
                      },
                    ),
                    if (_printers.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent),
                        title: Text(l.dashboardRemovePrinter,
                            style: const TextStyle(color: Colors.redAccent)),
                        onTap: () {
                          Navigator.pop(context);
                          _showRemoveSheet(context);
                        },
                      ),

                    const Divider(),

                    // Import / Export
                    if (_printers.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.upload_file_outlined),
                        title: Text(l.dashboardBackUpConfig),
                        subtitle:
                            Text(l.dashboardBackUpConfigSubtitle),
                        onTap: () {
                          Navigator.pop(context);
                          _exportConfig();
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: Text(l.dashboardRestoreConfig),
                      subtitle: Text(l.dashboardRestoreConfigSubtitle),
                      onTap: () {
                        Navigator.pop(context);
                        _importConfig();
                      },
                    ),

                    const Divider(),

                    // Theme
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(l.dashboardThemeHeading,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white54)),
                    ),
                    RadioGroup<AppThemeMode>(
                      groupValue: themeMode,
                      onChanged: (v) {
                        if (v == null) return;
                        ref.read(themeModeProvider.notifier).set(v);
                        // Selecting "Custom" should jump straight into the
                        // colour editor — saves the user a second tap and
                        // makes the option discoverable in one click.
                        if (v == AppThemeMode.custom) {
                          Navigator.pop(context);
                          context.push('/theme/custom');
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile(
                            value: AppThemeMode.system,
                            title: Text(l.dashboardThemeSystem),
                            secondary: const Icon(Icons.brightness_auto),
                          ),
                          RadioListTile(
                            value: AppThemeMode.dark,
                            title: Text(l.dashboardThemeDark),
                            secondary: const Icon(Icons.dark_mode),
                          ),
                          RadioListTile(
                            value: AppThemeMode.light,
                            title: Text(l.dashboardThemeLight),
                            secondary: const Icon(Icons.light_mode),
                          ),
                          RadioListTile(
                            value: AppThemeMode.custom,
                            title: Text(l.dashboardThemeCustom),
                            secondary: const Icon(Icons.palette_outlined),
                          ),
                        ],
                      ),
                    ),
                    // Always offer a way back into the editor — handy when
                    // Custom is already selected and the user just wants to
                    // tweak a colour without re-tapping the radio.
                    if (themeMode == AppThemeMode.custom)
                      ListTile(
                        leading: const Icon(Icons.tune),
                        title: Text(l.dashboardCustomiseColours),
                        subtitle: Text(
                            l.dashboardCustomiseColoursSubtitle),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/theme/custom');
                        },
                      ),

                    const Divider(),

                    // Font size
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(l.dashboardFontSizeHeading,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white54)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.text_fields, size: 16),
                          Expanded(
                            child: Slider(
                              value: fontScale,
                              min: 0.8,
                              max: 1.4,
                              divisions: 6,
                              label: _fontScaleLabel(fontScale),
                              onChanged: (v) =>
                                  ref.read(fontScaleProvider.notifier).set(v),
                            ),
                          ),
                          const Icon(Icons.text_fields, size: 22),
                        ],
                      ),
                    ),

                    const Divider(),

                    // ── Dashboard layout ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(l.dashboardLayoutHeading,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white54)),
                    ),
                    // Column count picker
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: SegmentedButton<int>(
                        // No selected-checkmark — it pushes the label onto a
                        // second line in these narrow segments. Selection is
                        // shown by the highlighted background instead. Icons
                        // dropped too for a clean, single-line look.
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          ButtonSegment(value: 1, label: Text(l.dashboardColumnCount(1))),
                          ButtonSegment(value: 2, label: Text(l.dashboardColumnCount(2))),
                          ButtonSegment(value: 3, label: Text(l.dashboardColumnCount(3))),
                        ],
                        selected: {gridColumns},
                        onSelectionChanged: (s) =>
                            ref.read(gridColumnsProvider.notifier).set(s.first),
                      ),
                    ),
                    // Rotation toggle
                    SwitchListTile(
                      dense: true,
                      secondary: const Icon(Icons.screen_rotation_outlined),
                      title: Text(l.dashboardRotateWithDevice),
                      subtitle: Text(l.dashboardRotateWithDeviceSubtitle),
                      value: allowRotation,
                      onChanged: (v) =>
                          ref.read(allowRotationProvider.notifier).set(v),
                    ),

                    const Divider(),

                    // ── Camera feed ───────────────────────────────────────────
                    // Throttles how often EVERY dashboard tile re-fetches its
                    // webcam snapshot. The default 1 s cuts network use ~15× vs
                    // the old raw feed; 'Raw' restores the live per-printer FPS.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(l.dashboardCameraFeedHeading,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white54)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                      child: Text(
                        l.dashboardCameraFeedSubtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white38),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: SegmentedButton<DashboardCameraRefresh>(
                        // No selected-checkmark (see column picker above) — keeps
                        // 'Raw'/'1s'/'3s'/'5s' on a single line when selected.
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          for (final r in DashboardCameraRefresh.values)
                            ButtonSegment(value: r, label: Text(r.label)),
                        ],
                        selected: {cameraRefresh},
                        onSelectionChanged: (s) => ref
                            .read(dashboardCameraRefreshProvider.notifier)
                            .set(s.first),
                      ),
                    ),

                    const Divider(),

                    // ── Print notifications ──────────────────────────────────
                    // Opt-in foreground service: live progress + state alerts.
                    SwitchListTile(
                      dense: true,
                      secondary:
                          const Icon(Icons.notifications_active_outlined),
                      title: Text(l.printNotifTitle),
                      subtitle: Text(l.printNotifSubtitle),
                      value: printNotifications,
                      onChanged: _togglePrintNotifications,
                    ),
                    // Poll cadence — only relevant while notifications are on.
                    if (printNotifications) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Text(l.notifPollIntervalTitle,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: Colors.white54)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: SegmentedButton<NotifPollInterval>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          segments: [
                            for (final i in NotifPollInterval.values)
                              ButtonSegment(value: i, label: Text(i.label)),
                          ],
                          selected: {pollInterval},
                          onSelectionChanged: (s) {
                            ref
                                .read(notifPollIntervalProvider.notifier)
                                .set(s.first);
                            PrintNotificationService.instance
                                .reschedule()
                                .ignore();
                          },
                        ),
                      ),
                    ],

                    const Divider(),

                    // ── About ────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(l.dashboardAboutHeading,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.white54)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.new_releases_outlined),
                      title: Text(l.dashboardWhatsNew),
                      subtitle: Text(l.dashboardWhatsNewSubtitle),
                      onTap: () {
                        Navigator.pop(context);
                        _showChangelog(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(l.dashboardHowPairingWorks),
                      subtitle: Text(l.dashboardHowPairingWorksSubtitle),
                      onTap: () {
                        Navigator.pop(context);
                        _showPairingHelp(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l.uiGuideTitle),
                      subtitle: Text(l.uiGuideMenuSubtitle),
                      onTap: () {
                        Navigator.pop(context);
                        showUiGuide(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: Text(l.dashboardReportProblem),
                      subtitle: Text(l.dashboardReportProblemSubtitle),
                      onTap: () {
                        Navigator.pop(context);
                        showFeedbackSheet(context, _printers);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(l.dashboardAppLock),
                      subtitle: Text(ref.watch(appLockEnabledProvider)
                          ? l.dashboardAppLockOn
                          : l.dashboardAppLockOff),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/settings/app-lock');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.coffee_outlined,
                          color: Colors.amber),
                      title: Text(l.dashboardBuyMeCoffee),
                      subtitle: Text(l.dashboardBuyMeCoffeeSubtitle),
                      onTap: () async {
                        Navigator.pop(context);
                        await launchUrl(
                          Uri.parse(
                              'https://www.paypal.com/donate/?hosted_button_id=WCWAZKQ7WKQB4'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom bar — always visible ───────────────────────────────────
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l.dashboardSettings),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l.menuLanguage),
              subtitle: Text(
                nativeLanguageName(ref.watch(localeProvider)) ??
                    l.languageSystemDefault,
              ),
              onTap: () {
                Navigator.pop(context);
                showLanguagePicker(context);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: ref.watch(appVersionProvider).when(
                data: (v) => Text(
                  l.dashboardVersion(v),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error:   (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saves the printer list to a JSON file chosen via the Android Storage
  /// Access Framework, so the user can keep it somewhere safe before a
  /// destructive reinstall and load it back afterwards. NB: this carries the
  /// printer list only — NOT the Supabase anonymous identity (that lives in
  /// flutter_secure_storage and is wiped on uninstall), so a restored config
  /// still needs a re-pair per printer to bind the new anon UID.
  Future<void> _exportConfig() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Mint a single-use restore code so this backup can bring the printers
    // back ONLINE after a reinstall (re-binds them to the new identity), not
    // just restore the list. Best-effort — a list-only backup if it fails.
    final restoreCode = await SupabaseService.instance.createRestoreGrant();
    final settings = await SettingsBackup.snapshot();
    if (!mounted) return;
    final bytes = Uint8List.fromList(
      utf8.encode(
        PrinterConfig.toBackupJson(_printers,
            restoreCode: restoreCode, settings: settings),
      ),
    );
    String? savedPath;
    try {
      // On Android, passing `bytes` makes saveFile write the file through the
      // SAF "create document" dialog and return its path (null if cancelled).
      // Without `bytes`, saveFile only returns a path and leaves the write to
      // us — which scoped storage won't allow.
      savedPath = await FilePicker.platform.saveFile(
        dialogTitle: l.dashboardSaveBackupDialogTitle,
        fileName: 'moongate-printers.json',
        bytes: bytes,
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.dashboardBackupFailed),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!mounted || savedPath == null) return; // user cancelled
    messenger.showSnackBar(
      SnackBar(
        content: Text(restoreCode != null
            ? l.dashboardBackupSuccess(_printers.length)
            : l.dashboardBackupSuccessListOnly(_printers.length)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Lets the user pick a previously saved backup file via the SAF document
  /// picker and restores its printer list. Existing printers are kept;
  /// duplicates (same id) are skipped.
  Future<void> _importConfig() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    ImportOutcome? outcome;
    try {
      outcome = await PrinterRegistry.instance.importFromBackupFile();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.dashboardInvalidBackupFile),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (outcome == null || !mounted) return; // user cancelled
    _load();
    // A restored backup may carry global app settings (theme, colours, columns,
    // language, …); the import wrote them to prefs, so reload the providers to
    // apply them live and re-sync the notification service to the restored
    // on/off preference.
    await _reloadSettingsAfterRestore();
    if (!mounted) return;
    final String msg;
    if (outcome.reconnected) {
      msg = l.dashboardRestoreReconnected(
          outcome.added, outcome.reconnectedCount);
    } else if (outcome.hadRestoreCode) {
      msg = l.dashboardRestoreNoneReconnected(outcome.added);
    } else {
      msg = l.dashboardRestoreListOnly(outcome.added);
    }
    messenger.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
    );
  }

  /// Re-read the settings providers from prefs after a restore wrote new
  /// values, so theme / colours / columns / language / etc. update without a
  /// restart. Mirrors the startup loads in main.dart — minus the device-bound
  /// app-lock, which a backup never carries.
  Future<void> _reloadSettingsAfterRestore() async {
    await ref.read(themeModeProvider.notifier).load();
    await ref.read(localeProvider.notifier).load();
    await ref.read(customThemeProvider.notifier).load();
    await ref.read(fontScaleProvider.notifier).load();
    await ref.read(gridColumnsProvider.notifier).load();
    await ref.read(allowRotationProvider.notifier).load();
    await ref.read(dashboardCameraRefreshProvider.notifier).load();
    await ref.read(printNotificationsEnabledProvider.notifier).load();
    await PrintNotificationService.instance
        .sync(ref.read(printNotificationsEnabledProvider));
  }

  void _showRemoveSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      // Without SafeArea the last ListTile clips behind the 3-button nav
      // bar on devices using on-screen system navigation.
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.dashboardRemoveSheetTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ..._printers.map(
              (p) => ListTile(
                leading: const Icon(Icons.print, color: Colors.redAccent),
                title: Text(p.name),
                subtitle: Text(
                  l.dashboardPrinterIdShort(p.id.substring(0, 8)),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePrinter(p);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _fontScaleLabel(double v) {
    if (v <= 0.85) return 'XS';
    if (v <= 0.95) return 'S';
    if (v <= 1.05) return 'M';
    if (v <= 1.15) return 'L';
    if (v <= 1.25) return 'XL';
    return 'XXL';
  }

  void _showChangelog(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.dashboardWhatsNew),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380, maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in _changelog) ...[
                  Text(
                    entry.version,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  for (final bullet in entry.bullets)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Text('• $bullet',
                          style: Theme.of(ctx).textTheme.bodySmall),
                    ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonClose),
          ),
        ],
      ),
    );
  }

  // ── Pairing onboarding help ──────────────────────────────────────────────
  static const _pairingHelpDismissedKey = 'pairing_help_dismissed';
  static const _languageSelectedKey = 'language_selected';
  static const _notifPromptedKey = 'notifications_prompted';

  /// First cold start: prompt for a language once, then run the pairing
  /// explainer. The language prompt is gated by [_languageSelectedKey] so it
  /// appears only on the very first launch; the pairing explainer keeps its
  /// existing show-until-dismissed behaviour and follows it.
  Future<void> _runFirstRunOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_languageSelectedKey) ?? false)) {
      if (!mounted) return;
      await showLanguagePicker(context, firstRun: true);
      await prefs.setBool(_languageSelectedKey, true);
    }
    await _maybeShowPairingHelp();
    await _maybeOfferNotifications();
  }

  /// Offer print notifications once — but only after the user actually has a
  /// printer (an empty dashboard has nothing to notify about, and a fresh
  /// install pairs first). Tapping "Turn on" requests the OS permission and
  /// enables the service.
  Future<void> _maybeOfferNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_notifPromptedKey) ?? false) return;
    if (PrinterRegistry.instance.printers.isEmpty) return;
    if (!mounted) return;
    final wantsIt = await showPrintNotificationsPrompt(context);
    await prefs.setBool(_notifPromptedKey, true);
    if (!wantsIt) return;
    final granted = await PrintNotificationService.instance.requestPermission();
    if (!granted) return;
    await ref.read(printNotificationsEnabledProvider.notifier).set(true);
    await PrintNotificationService.instance.sync(true);
  }

  /// On cold launch, show the "how pairing works" explainer unless the user
  /// ticked "Don't show this again". Pressing OK without ticking shows it again
  /// next launch — by design, so the workflow lands for users who skim it.
  Future<void> _maybeShowPairingHelp() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pairingHelpDismissedKey) ?? false) return;
    if (!mounted) return;
    await _showPairingHelp(context);
  }

  /// The pairing / reinstall explainer. Reachable on launch and from the menu
  /// ("How pairing works"). The "Don't show again" tick persists the dismissal
  /// so it never auto-shows again.
  Future<void> _showPairingHelp(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    var dontShowAgain = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.push_pin_outlined, color: cs.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(l.dashboardHowPairingWorks)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440, maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pairingHelpItem(ctx, Icons.qr_code_2, cs.primary,
                      l.dashboardPairingHelpPairOnceTitle,
                      l.dashboardPairingHelpPairOnceBody),
                  _pairingHelpItem(ctx, Icons.check_circle_outline, Colors.green,
                      l.dashboardPairingHelpUpdatesTitle,
                      l.dashboardPairingHelpUpdatesBody),
                  _pairingHelpItem(ctx, Icons.cloud_download_outlined, cs.primary,
                      l.dashboardPairingHelpReinstallTitle,
                      l.dashboardPairingHelpReinstallBody),
                  _pairingHelpItem(ctx, Icons.restart_alt, Colors.orangeAccent,
                      l.dashboardPairingHelpNoBackupTitle,
                      l.dashboardPairingHelpNoBackupBody),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: dontShowAgain,
                    onChanged: (v) => setLocal(() => dontShowAgain = v ?? false),
                    title: Text(l.dashboardDontShowAgain),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                if (dontShowAgain) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_pairingHelpDismissedKey, true);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pairingHelpItem(
      BuildContext ctx, IconData icon, Color color, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: Theme.of(ctx)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangelogEntry {
  final String version;
  final List<String> bullets;
  const _ChangelogEntry(this.version, this.bullets);
}

// Top-level brief — bumped on each release. Newest first.
const _changelog = <_ChangelogEntry>[
  _ChangelogEntry('v0.8.1', [
    'Print notifications now refresh the moment you add, remove or restore a printer — no more "No printers" stuck in the notification after a restore',
    'New "Update frequency" setting — choose how often notifications check your printers: 5s, 10s, 15s, 30s or 1 minute (Menu, under Print notifications)',
    'Status now updates promptly when a printer errors or finishes, instead of lagging behind',
    'New alert when a printer recovers and is ready again after an error (e.g. a firmware restart)',
    'No Pi update needed — just update the app',
  ]),
  _ChangelogEntry('v0.8.0', [
    'New optional print notifications — turn them on (Menu → Print notifications) for a live status of every printer in your notification shade: per-printer progress, ETA, temperatures and heat-up, plus alerts when a print starts, finishes, pauses or errors. Works with the app in the background; off by default',
    'Backup now keeps your settings too — theme and custom colours, dashboard columns, language and camera refresh ride along with your backup, not just the printer list (your app-lock PIN stays on the device for security)',
    'Printers now sort by activity — whatever\'s printing floats to the top, then Ready, Idle and Offline, on both the dashboard and the notification',
    'No Pi update needed — just update the app',
  ]),
  _ChangelogEntry('v0.7.0', [
    'Moongate now speaks your language — translations for German, French, Spanish, Italian, Simplified Chinese, Russian and Polish, alongside English. Pick your language on first launch, or change it anytime from Language at the bottom of the menu',
    'New icon guide — tap it to see what every dashboard icon means, with a Back to dashboard button',
    'Tidier single-column dashboard — printer tiles are now square',
    'Translations are a best-effort starting point; corrections are welcome',
  ]),
  _ChangelogEntry('v0.6.5', [
    'New "How pairing works" guide on launch (and in the menu) — explains that you pair once, that app updates keep your printers, and how to bring printers back after a reinstall (Restore from a backup, or MOONGATE_RESET_OWNER then re-pair). Tick "Don\'t show this again" to hide it',
  ]),
  _ChangelogEntry('v0.6.4', [
    'Fixed remote access over the internet — printers connect through the secure tunnel again (a v0.6.3 bug returned a server error when you were away from home). Update your Pi to get the fix',
    'Restore is now honest about results — it tells you when printers actually reconnected vs when they still need a re-pair',
    'Bug reports now include the remote (tunnel) connection result and your Pi’s plugin version, so problems are quicker to diagnose',
  ]),
  _ChangelogEntry('v0.6.3', [
    'Restore now brings your printers back ONLINE after a reinstall or on a new phone — no re-pairing. Your backup carries a one-time code that re-links them to the freshly-installed app',
    'Re-run the Pi installer so the printer recognises the restored app (needed for restore to reconnect)',
    'Import config from the Add Printer screen — restore before you pair, handy when reinstalling',
    'New "Report a problem" in the menu — sends a bug report with diagnostics (app, device, network, printer status) attached so issues are easier to fix',
    'Plus a "Trouble pairing? Send a report" link on the Add Printer screen',
  ]),
  _ChangelogEntry('v0.6.2', [
    'Set a printer\'s address by hand — a new "Advanced" option when adding a printer, and an address field in each printer\'s edit dialog. Handy when your printer is behind a reverse proxy (Traefik, Caddy, NPM) or in Docker and the app can\'t find it automatically — enter the address you\'d use to open its web page in a browser',
    'Clearer pairing — scanning the QR is marked as the instant method; typing the GATE code is flagged as the slower alternative',
    'Steadier first connection — a freshly-paired printer is less likely to show a premature "Offline", and recovers on its own when you return to the app',
  ]),
  _ChangelogEntry('v0.6.1', [
    'Fixed a printer staying on "Starting up…" forever when it was paired while powered off (or went offline right after pairing) — it now settles to "Offline" once unreachable, with a short grace window for one that\'s genuinely still booting',
  ]),
  _ChangelogEntry('v0.6.0', [
    'New optional App lock — protect Moongate with a PIN, plus fingerprint or face if your phone supports it (Menu → App lock)',
    'The lock appears when you open the app; you can optionally re-lock after time in the background',
    'Your PIN is stored encrypted on the device and wrong guesses are rate-limited',
    'Slimmer app — removed unused VPN code, so Moongate no longer asks for VPN or special background permissions',
  ]),
  _ChangelogEntry('v0.5.2', [
    'Back up & restore your printer list to a file — "Back up config" / "Restore config" now use a file you choose instead of the clipboard, so it survives reinstalling the app',
    'Fixed missing print progress and chamber temperature when viewing a printer over local Wi-Fi',
  ]),
  _ChangelogEntry('v0.5.1', [
    'Pairing is instant — scan the QR and the printer shows as Local right away',
    'Remote (tunnel) access now syncs in the background; both icons appear once it\'s ready',
    'No more sitting on "Starting up… waiting for first heartbeat" after you pair',
    'New "Dashboard camera feed" setting — Raw / 1s / 3s / 5s (default 1s) to cut data use',
    'Dashboard webcams pause while the app is in the background',
    'Reinstalling or on a new phone? Run MOONGATE_RESET_OWNER on the Pi first, then re-pair',
    'Re-run the Pi installer to enable instant pairing',
  ]),
  _ChangelogEntry('v0.5.0', [
    'Dashboard tile stays "Local" when your Pi\'s IP changes — even if the internet is down',
    'Finds your Pi on the local network via mDNS (pairs with the v0.4.4 Pi advertisement)',
    'Print controls now read the live LAN URL too — no stale-IP gap after DHCP changes',
    'Falls through to v0.4.x behaviour when discovery doesn\'t resolve (different WiFi, multicast blocked, etc.)',
    'Re-run the Pi installer to enable the Pi-side advertisement',
  ]),
  _ChangelogEntry('v0.4.4', [
    'Pi-side groundwork for LAN discovery — your Pi now advertises itself on the local network',
    'No visible change yet on its own; pairs with the upcoming v0.5.0 app update',
    'Re-run the Pi installer to pick up the change',
  ]),
  _ChangelogEntry('v0.4.3', [
    'Webcam tile now works on slow camera servers (stock RatRig Micron+ / uv4l-mjpeg)',
    'Self-throttles to whatever the camera can deliver instead of cancelling its own fetches',
    'No Pi-side change needed — just update the app',
  ]),
  _ChangelogEntry('v0.4.2', [
    'Re-pair after app reinstall just works — no more "already paired"',
    'Pairing goes live within seconds, not up to 5 minutes',
    'Mainsail through tunnel stays connected on cellular',
    'Type the GATE code if the camera can\'t scan the QR',
  ]),
  _ChangelogEntry('v0.4.1', [
    'Dashboard tile webcam preview works again on LAN and tunnel',
    'No reinstall on the Pi needed — just this app update',
  ]),
  _ChangelogEntry('v0.4.0', [
    'Hardened remote access — the tunnel URL alone grants nothing',
    'Mainsail reachable through the tunnel from anywhere',
    "Added 'Buy me a coffee' and this 'What's new'",
  ]),
  _ChangelogEntry('v0.3.0', [
    'Cloud-mediated pairing — no more URL sharing required',
    'LAN-first routing for snappier home use',
    'Cleaner remove / re-pair flow',
  ]),
  _ChangelogEntry('v0.2.29', [
    'Initial public release',
    'Pi-issued JWT auth, dual-path local + tunnel',
    'Mainsail / Fluidd WebView per printer',
  ]),
];

// ── Update banner ─────────────────────────────────────────────────────────────

class _UpdateBanner extends StatelessWidget {
  final UpdateInfo update;
  final VoidCallback onDismiss;

  const _UpdateBanner({required this.update, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.system_update_alt_rounded,
                color: cs.onPrimaryContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.dashboardUpdateAvailable(update.version),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(foregroundColor: cs.onPrimaryContainer),
              child: Text(l.dashboardUpdateLater),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => launchUrl(
                Uri.parse(update.apkUrl),
                mode: LaunchMode.externalApplication,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: Text(l.dashboardUpdate),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Printer grid ──────────────────────────────────────────────────────────────

class _PrinterGrid extends StatelessWidget {
  final List<PrinterConfig> printers;
  final void Function(PrinterConfig) onTap;
  final void Function(PrinterConfig) onRemove;

  /// Portrait column count chosen by the user (1, 2, or 3).
  /// When the device rotates to landscape, one extra column is added
  /// automatically so the extra horizontal space is used well.
  final int columns;

  const _PrinterGrid({
    required this.printers,
    required this.onTap,
    required this.onRemove,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isLandscape = constraints.maxWidth > constraints.maxHeight;

      // In landscape, bump by 1 so the extra width is used comfortably.
      // Capped at 4 to keep tiles readable even on small phone screens.
      final effectiveCols = isLandscape
          ? (columns + 1).clamp(2, 4)
          : columns;

      // Aspect ratio (width / height) per column count.
      // Wider tiles (fewer columns) can be shorter; narrow tiles need more
      // height to keep the webcam + controls comfortable.
      final aspectRatio = switch (effectiveCols) {
        1 => 1.0,   // single full-width tile: square on every device
        2 => 0.75,  // default two-column layout
        3 => 0.65,  // three columns — a bit taller relative to width
        _ => 0.55,  // four columns in landscape from a 3-col portrait pref
      };

      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: effectiveCols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
        ),
        itemCount: printers.length,
        itemBuilder: (_, i) => PrinterTile(
          key: ValueKey(printers[i].id),
          printer: printers[i],
          onTap: () => onTap(printers[i]),
        ),
      );
    });
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPrinter;

  const _EmptyState({required this.onAddPrinter});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.print_disabled,
              size: 72, color: Colors.white24),
          const SizedBox(height: 16),
          Text(l.dashboardEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l.dashboardEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l.dashboardAddPrinter),
            onPressed: onAddPrinter,
          ),
        ],
      ),
    );
  }
}
