import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../providers/custom_theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/version_provider.dart';
import '../../services/changelog_service.dart';
import '../../services/print_notification_service.dart';
import '../../services/printer_access_cache.dart';
import '../../services/printer_registry.dart';
import '../../services/printer_status_registry.dart';
import '../../services/printer_webview_cache.dart';
import '../../services/settings_backup.dart';
import '../../services/supabase_service.dart';
import '../../services/update_service.dart';
import '../donation/donation_prompt.dart';
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

  /// Transient (not persisted) manual-reorder editing state. Only meaningful
  /// when auto-arrange is off: true = tiles draggable + hint shown ("arranging");
  /// false = tiles locked in their saved order, dashboard clean ("settled").
  /// Toggled by the bottom-left Reorder/Done button.
  bool _reordering = false;

  // Always-visible scrollbar for the drawer body so small-screen users can see
  // there's more below the fold (user-reported — not obvious it scrolled).
  final ScrollController _drawerScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    // Show the pairing/reinstall explainer on cold launch until the user opts
    // out ("Don't show again"). Post-frame so the dialog has a mounted context.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _runFirstRunOnboarding().ignore());
  }

  @override
  void dispose() {
    _drawerScroll.dispose();
    super.dispose();
  }

  void _load() {
    final list = PrinterRegistry.instance.printers;
    if (mounted) setState(() => _printers = list);
    // Keep the print-notification isolate's printer list in step — it reads a
    // separate cached snapshot, so poke it whenever the set may have changed
    // (pair / remove / restore). No-op when notifications are off.
    PrintNotificationService.instance.refreshNow().ignore();
  }

  /// Persist a drag-to-reorder from the dashboard grid (manual mode only).
  /// reorderable_grid_view reports the *final* index directly, so this is a
  /// plain removeAt/insert — no ReorderableListView-style `-1` fix-up. The new
  /// order is written through the registry (which is the dashboard's order of
  /// record and rides backups).
  void _onReorder(int oldIndex, int newIndex) {
    final reordered = List<PrinterConfig>.of(_printers);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() => _printers = reordered);
    PrinterRegistry.instance
        .setOrder([for (final p in reordered) p.id])
        .ignore();
  }

  /// Flip the auto-arrange setting from the drawer. Turning it OFF drops the
  /// dashboard straight into arranging mode (tiles immediately draggable, so the
  /// feature is right there); turning it back ON ends any arranging session.
  void _setAutoArrange(bool enabled) {
    ref.read(autoArrangeProvider.notifier).set(enabled);
    setState(() => _reordering = !enabled);
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
    PrinterWebViewCache.instance.invalidate(printer.id);

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
    final cs = Theme.of(context).colorScheme;
    // Check for update — runs once per session, silently ignored on failure.
    final updateAsync = ref.watch(updateProvider);
    final update = _updateDismissed ? null : updateAsync.valueOrNull;

    final gridColumns = ref.watch(gridColumnsProvider);
    final autoArrange = ref.watch(autoArrangeProvider);

    // Reload after the printer screen pops so any rename done in the app bar
    // there propagates to the tile.
    void openPrinter(PrinterConfig p) =>
        context.push('/printer/${p.id}').then((_) => _load());

    final Widget body;
    if (_printers.isEmpty) {
      body = _EmptyState(
          onAddPrinter: () => context.push('/pair').then((_) => _load()));
    } else if (autoArrange) {
      // Re-sort tiles by live status (active prints float up) whenever a
      // printer's state changes — printerStatusRank, shared with the
      // notification. Tiles are keyed by id so a reorder moves a tile (and
      // its poller) rather than rebuilding it.
      body = StreamBuilder<void>(
        stream: PrinterStatusRegistry.instance.changes,
        builder: (context, _) => _PrinterGrid(
          printers: _sortByStatus(_printers),
          columns: gridColumns,
          onTap: openPrinter,
        ),
      );
    } else {
      // Manual order: tiles stay where the user put them and can be dragged to
      // reorder (long-press to pick up). Deliberately NOT wrapped in the status
      // StreamBuilder — re-sorting is exactly what the user turned off here, and
      // a rebuild mid-drag would fight the gesture. Each tile still refreshes
      // its own content through its internal status stream.
      body = Column(
        children: [
          if (_reordering && _printers.length > 1) const _ReorderHint(),
          Expanded(
            child: _PrinterGrid(
              printers: _printers,
              columns: gridColumns,
              onTap: openPrinter,
              // Draggable only while actively arranging; otherwise a plain grid
              // in the saved order so tiles can't be nudged by accident.
              onReorder: _reordering ? _onReorder : null,
            ),
          ),
        ],
      );
    }

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
      body: ValueListenableBuilder<bool>(
        valueListenable: SupabaseService.instance.signedIn,
        builder: (context, signedIn, _) {
          final banners = <Widget>[
            if (update != null)
              _UpdateBanner(
                update: update,
                onDismiss: () => setState(() => _updateDismissed = true),
                onWhatsNew: () => _showUpdateNotes(context, update),
              ),
            if (!signedIn) const _SignInBanner(),
          ];
          if (banners.isEmpty) return body;
          return Column(
            children: [...banners, Expanded(child: body)],
          );
        },
      ),
      floatingActionButton: _printers.isEmpty
          ? null
          : SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bottom-left: enter / leave manual reorder mode. Only shown
                    // in manual mode when there's more than one tile to move.
                    // "Done" settles the arrangement and clears the drag hint;
                    // "Reorder" re-enters it. The order itself is already saved
                    // on every drop — this button is purely the editing UI.
                    if (!autoArrange && _printers.length > 1)
                      FloatingActionButton(
                        heroTag: 'reorderFab',
                        onPressed: () =>
                            setState(() => _reordering = !_reordering),
                        backgroundColor: _reordering ? Colors.green : null,
                        foregroundColor: _reordering ? Colors.white : null,
                        // Tooltips keep the action labelled (for accessibility +
                        // long-press) now that the button itself is icon-only.
                        tooltip: _reordering
                            ? l.dashboardReorderDone
                            : l.dashboardReorderStart,
                        child: _reordering
                            ? const Icon(Icons.check)
                            : SvgPicture.asset(
                                'assets/icons/drag_drop.svg',
                                width: 24,
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                    cs.onPrimaryContainer, BlendMode.srcIn),
                              ),
                      )
                    else
                      const SizedBox.shrink(),
                    // Bottom-right: add a printer.
                    FloatingActionButton(
                      heroTag: 'addFab',
                      onPressed: () async {
                        await context.push('/pair');
                        _load();
                      },
                      tooltip: l.dashboardAddPrinter,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
    final autoArrange   = ref.watch(autoArrangeProvider);
    final cameraRefresh = ref.watch(dashboardCameraRefreshProvider);
    final showCameraIcons = ref.watch(showCameraConfigIconsProvider);
    final webcamsEnabled = ref.watch(webcamsEnabledProvider);
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
              child: Scrollbar(
                controller: _drawerScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _drawerScroll,
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

                    // ── Lighting ──────────────────────────────────────────────
                    // Pulled up here (right under Font size) for quick reach —
                    // it was previously buried near the bottom of the About list.
                    ListTile(
                      leading: const Icon(Icons.lightbulb_outline),
                      title: Text(l.lightingTitle),
                      subtitle: Text(l.lightingMenuSubtitle),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/lighting').then((_) => _load());
                      },
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
                    // Auto-arrange vs. manual drag-to-reorder. ON (default)
                    // keeps the historic status sort; OFF freezes the order and
                    // unlocks long-press drag on the grid.
                    SwitchListTile(
                      dense: true,
                      secondary: const Icon(Icons.swap_vert),
                      title: Text(l.dashboardAutoArrange),
                      subtitle: Text(l.dashboardAutoArrangeSubtitle),
                      value: autoArrange,
                      onChanged: _setAutoArrange,
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
                    // Master on/off for all dashboard webcam feeds — turning it
                    // off stops every tile's polling (a data saver) and shows
                    // the placeholder; the full-screen camera view still works.
                    SwitchListTile(
                      dense: true,
                      secondary: const Icon(Icons.videocam_outlined),
                      title: Text(l.dashboardShowWebcams),
                      subtitle: Text(l.dashboardShowWebcamsSubtitle),
                      value: webcamsEnabled,
                      onChanged: (v) =>
                          ref.read(webcamsEnabledProvider.notifier).set(v),
                    ),
                    // Show / hide the per-tile camera config gear.
                    SwitchListTile(
                      dense: true,
                      secondary: const Icon(Icons.tune),
                      title: Text(l.dashboardShowCameraIcons),
                      subtitle: Text(l.dashboardShowCameraIconsSubtitle),
                      value: showCameraIcons,
                      onChanged: (v) => ref
                          .read(showCameraConfigIconsProvider.notifier)
                          .set(v),
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
                      // Edit which fields show in the notification + their order.
                      ListTile(
                        leading: const Icon(Icons.format_list_bulleted),
                        title: Text(l.notifContentTitle),
                        subtitle: Text(l.notifContentSubtitle),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/settings/notifications');
                        },
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
                          Uri.parse(kDonationUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
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
    await ref.read(autoArrangeProvider.notifier).load();
    await ref.read(dashboardCameraRefreshProvider.notifier).load();
    await ref.read(showCameraConfigIconsProvider.notifier).load();
    await ref.read(printNotificationsEnabledProvider.notifier).load();
    await ref.read(notificationFieldsProvider.notifier).load();
    await ref.read(webcamsEnabledProvider.notifier).load();
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

  void _showChangelog(BuildContext context) =>
      _showChangelogSheet(context, future: ChangelogService.loadBundled());

  /// The "what's new in this update" overlay — entries from the user's installed
  /// build up to the latest, fetched from master (the installed app can't carry
  /// notes for a version newer than itself).
  void _showUpdateNotes(BuildContext context, UpdateInfo update) =>
      _showChangelogSheet(
        context,
        future: ChangelogService.entriesSinceInstalled(),
        update: update,
      );

  /// Shared changelog dialog. With [update] set it's the update overlay — it
  /// gains Update + View-on-GitHub actions and a fallback message when the
  /// remote fetch returns nothing.
  void _showChangelogSheet(
    BuildContext context, {
    required Future<List<ChangelogEntry>> future,
    UpdateInfo? update,
  }) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.dashboardWhatsNew),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380, maxWidth: 360),
          child: FutureBuilder<List<ChangelogEntry>>(
            future: future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final entries = snap.data ?? const <ChangelogEntry>[];
              if (entries.isEmpty) {
                // Only the update overlay reaches here (remote fetch failed) —
                // the bundled list is never empty.
                return Text(l.updateNotesUnavailable,
                    style: Theme.of(ctx).textTheme.bodySmall);
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in entries) ...[
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
              );
            },
          ),
        ),
        actions: [
          if (update != null)
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/PEEKYPAUL/Moongate/releases/latest'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(l.updateViewOnGithub),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonClose),
          ),
          if (update != null)
            FilledButton(
              onPressed: () => launchUrl(
                Uri.parse(update.apkUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(l.dashboardUpdate),
            ),
        ],
      ),
    );
  }

  // ── Pairing onboarding help ──────────────────────────────────────────────
  static const _pairingHelpDismissedKey = 'pairing_help_dismissed';
  static const _languageSelectedKey = 'language_selected';
  static const _notifPromptedKey = 'notifications_prompted';
  static const _donationPromptedKey = 'donation_prompted';

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
    await _maybeShowDonationPrompt();
  }

  /// A one-time, low-pressure nudge to support the project, shown on a cold
  /// start. Gated on having at least one printer so it never interrupts a brand
  /// new user mid-pairing (the donation ask lands once they're actually set up,
  /// not before they've seen the app work). Shown exactly once — the
  /// [_donationPromptedKey] flag is a first-run flag, so it's excluded from
  /// backups and can't carry over to a fresh install.
  Future<void> _maybeShowDonationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_donationPromptedKey) ?? false) return;
    if (PrinterRegistry.instance.printers.isEmpty) return;
    if (!mounted) return;
    final wantsToDonate = await showDonationPrompt(context);
    await prefs.setBool(_donationPromptedKey, true);
    if (!wantsToDonate) return;
    await launchUrl(Uri.parse(kDonationUrl),
        mode: LaunchMode.externalApplication);
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


// ── Update banner ─────────────────────────────────────────────────────────────

/// Shown above the dashboard while the app has no cloud session yet — usually
/// the anonymous sign-in being rate-limited after several reinstalls in a row.
/// SupabaseService retries on its own, so this is purely informational and
/// disappears once a session lands and the tiles reconnect.
class _SignInBanner extends StatelessWidget {
  const _SignInBanner();

  @override
  Widget build(BuildContext context) {
    final l  = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.dashboardSignInRetrying,
                style: TextStyle(color: cs.onSecondaryContainer, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  final UpdateInfo update;
  final VoidCallback onDismiss;
  final VoidCallback onWhatsNew;

  const _UpdateBanner({
    required this.update,
    required this.onDismiss,
    required this.onWhatsNew,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
              ],
            ),
            // Actions on their own row so "What's new" + Later + Update always
            // fit, even on a narrow phone.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                      foregroundColor: cs.onPrimaryContainer),
                  child: Text(l.dashboardUpdateLater),
                ),
                TextButton(
                  onPressed: onWhatsNew,
                  style: TextButton.styleFrom(
                      foregroundColor: cs.onPrimaryContainer),
                  child: Text(l.dashboardWhatsNew),
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

  /// Portrait column count chosen by the user (1, 2, or 3).
  /// When the device rotates to landscape, one extra column is added
  /// automatically so the extra horizontal space is used well.
  final int columns;

  /// When non-null, the grid is in manual-order mode: tiles can be long-pressed
  /// and dragged to reorder, and this fires with the new (old, new) indices.
  /// Null in the default auto-arrange mode, where the grid is a plain GridView.
  final void Function(int oldIndex, int newIndex)? onReorder;

  const _PrinterGrid({
    required this.printers,
    required this.onTap,
    required this.columns,
    this.onReorder,
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

      // Each tile's webcam preview is a fixed 1:1 square (see printer_tile).
      // To let that square span the full tile width, the tile height is sized
      // as the square (= tile width) plus a fixed band for the status text and
      // action row beneath it — so childAspectRatio is derived from the real
      // tile width rather than a hand-tuned per-column constant. Tiles get a
      // little taller than before (most visibly in multi-column layouts), the
      // trade for a feed that's square on every device.
      const padding = EdgeInsets.all(12);
      const crossSpacing = 10.0;
      // Vertical space reserved under the square webcam for the accent bar,
      // action row, and name/temperature band. Sized to the common active tile
      // (idle/ready ≈ 100px) so it sits snug under the square; the busiest tile
      // (printing, with a filename) runs a little over and the webcam gives a
      // few px back via its Flexible wrapper (printer_tile) rather than making
      // every quieter tile carry that worst-case reserve.
      const tileTextBand = 104.0;
      final tileWidth = (constraints.maxWidth -
              padding.horizontal -
              crossSpacing * (effectiveCols - 1)) /
          effectiveCols;
      final aspectRatio = tileWidth / (tileWidth + tileTextBand);

      final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveCols,
        crossAxisSpacing: crossSpacing,
        mainAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      );

      // Keyed by id so a reorder (or a status re-sort) moves a tile and its
      // poller rather than rebuilding it. The key is also what the reorderable
      // grid tracks while dragging.
      Widget tileAt(int i) => PrinterTile(
            key: ValueKey(printers[i].id),
            printer: printers[i],
            onTap: () => onTap(printers[i]),
          );

      if (onReorder == null) {
        return GridView.builder(
          padding: padding,
          gridDelegate: gridDelegate,
          itemCount: printers.length,
          itemBuilder: (_, i) => tileAt(i),
        );
      }

      // Manual-order mode: long-press a tile to lift it, drag it into place;
      // the reflow animates and the dropped order is persisted by the caller.
      return ReorderableGridView.builder(
        padding: padding,
        gridDelegate: gridDelegate,
        itemCount: printers.length,
        onReorder: onReorder!,
        itemBuilder: (_, i) => tileAt(i),
      );
    });
  }
}

/// Subtle strip shown above the grid in manual-order mode so the user knows the
/// tiles are now draggable (the gesture isn't otherwise discoverable). Only
/// rendered when there's more than one printer to reorder.
class _ReorderHint extends StatelessWidget {
  const _ReorderHint();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final faint =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.drag_indicator, size: 15, color: faint),
          const SizedBox(width: 4),
          Text(
            l.dashboardReorderHint,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: faint),
          ),
        ],
      ),
    );
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
