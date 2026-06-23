import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../providers/settings_provider.dart';
import '../../services/heatsoak_timers.dart';
import '../../services/print_control_service.dart';
import '../../services/print_notification_service.dart';

/// Client-side sanity cap on an entered target. Klipper enforces each heater's
/// real `max_temp` and rejects anything above it (surfaced as a failure
/// snackbar), so this is just a fat-finger guard, not a safety limit.
const double _maxTemp = 400;

/// Ceiling on the heat-soak timer (10 hours), so a stray extra digit can't arm
/// an absurd deadline.
const int _maxMinutes = 600;

/// Bottom sheet to preheat a printer's hotend / bed and optionally arm a
/// heat-soak timer. Opened by a long-press on a tile's temperature row (online +
/// idle only — see `printer_tile.dart`). Sends `SET_HEATER_TEMPERATURE` to the
/// printer's Moonraker console over the same LAN→tunnel proxy as the macro
/// runner, so it needs no plugin change. Heater object names are auto-detected
/// (`available_heaters`) so it works whether the config calls them
/// extruder/heater_bed or something custom.
///
/// The heat-soak alert piggybacks the opt-in print-notification service (its
/// background isolate watches the armed deadline), so the sheet warns when that
/// service is off — otherwise the timer would never fire.
Future<void> showPreheatSheet(
  BuildContext context,
  PrinterConfig printer, {
  required double hotendTarget,
  required double bedTarget,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _PreheatSheet(
      printer: printer,
      hotendTarget: hotendTarget,
      bedTarget: bedTarget,
    ),
  );
}

class _PreheatSheet extends ConsumerStatefulWidget {
  final PrinterConfig printer;
  final double hotendTarget;
  final double bedTarget;
  const _PreheatSheet({
    required this.printer,
    required this.hotendTarget,
    required this.bedTarget,
  });

  @override
  ConsumerState<_PreheatSheet> createState() => _PreheatSheetState();
}

class _PreheatSheetState extends ConsumerState<_PreheatSheet> {
  late final PrintControlService _control;
  final _hotendCtl = TextEditingController();
  final _bedCtl = TextEditingController();
  final _timeCtl = TextEditingController(text: '0');

  /// Detected heater object names. Seeded with the Klipper defaults and replaced
  /// when the `available_heaters` probe returns, so a Set fired before the probe
  /// lands still targets the right heaters on a standard machine.
  ({String hotend, String bed}) _heaters =
      (hotend: 'extruder', bed: 'heater_bed');

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _control = PrintControlService(widget.printer);
    _control.detectHeaters().then((h) {
      if (mounted) setState(() => _heaters = h);
    });
  }

  @override
  void dispose() {
    _hotendCtl.dispose();
    _bedCtl.dispose();
    _timeCtl.dispose();
    super.dispose();
  }

  double? _parseTemp(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return null;
    return v.clamp(0, _maxTemp).toDouble();
  }

  int _parseMinutes(String s) {
    final v = int.tryParse(s.trim());
    if (v == null || v < 0) return 0;
    return v > _maxMinutes ? _maxMinutes : v;
  }

  Future<void> _enableNotifications() async {
    final granted =
        await PrintNotificationService.instance.requestPermission();
    if (!granted) return; // user denied at the OS prompt — the warning stays
    await ref.read(printNotificationsEnabledProvider.notifier).set(true);
    await PrintNotificationService.instance.sync(true);
  }

  Future<void> _submit() async {
    final hotend = _parseTemp(_hotendCtl.text);
    final bed = _parseTemp(_bedCtl.text);
    if (hotend == null && bed == null) return; // nothing to set
    final minutes = _parseMinutes(_timeCtl.text);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context); // survives the pop

    setState(() => _sending = true);
    final ok = await _control.setHeaters(
      hotend: hotend,
      bed: bed,
      hotendName: _heaters.hotend,
      bedName: _heaters.bed,
    );
    if (!mounted) return;

    if (!ok) {
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(
        content: Text(l.preheatFailed),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    // Arm (or clear) the soak timer. Armed even when notifications are off — the
    // in-sheet warning already flagged that — so it still fires if the user
    // enables them within the grace window.
    if (minutes > 0) {
      final at =
          DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;
      await HeatsoakTimers.arm(widget.printer.id, at);
    } else {
      await HeatsoakTimers.cancel(widget.printer.id);
    }
    if (!mounted) return;

    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(_confirmText(l, hotend, bed, minutes)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  String _confirmText(
      AppLocalizations l, double? hotend, double? bed, int minutes) {
    final parts = <String>[
      if (hotend != null) '${l.preheatHotend} ${hotend.round()}°',
      if (bed != null) '${l.preheatBed} ${bed.round()}°',
    ];
    final set = l.preheatSetConfirm(parts.join(' · '));
    return minutes > 0 ? '$set · ${l.preheatSoakIn(minutes)}' : set;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final notifsOn = ref.watch(printNotificationsEnabledProvider);
    final hasTemp = _hotendCtl.text.trim().isNotEmpty ||
        _bedCtl.text.trim().isNotEmpty;
    final soakMinutes = _parseMinutes(_timeCtl.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: title + printer name (matches the macros sheet) ──
              Text(l.preheatTitle, style: theme.textTheme.titleMedium),
              Text(
                widget.printer.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // ── Hotend + bed targets (either may be left blank) ──────────
              _TempField(
                controller: _hotendCtl,
                label: l.preheatHotend,
                icon: Icons.whatshot,
                color: Colors.deepOrange,
                currentTarget: widget.hotendTarget,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _TempField(
                controller: _bedCtl,
                label: l.preheatBed,
                icon: Icons.bed,
                color: Colors.blue,
                currentTarget: widget.bedTarget,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                l.preheatHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),

              // ── Optional heat-soak timer ─────────────────────────────────
              TextField(
                controller: _timeCtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.preheatSoakLabel,
                  helperText: l.preheatSoakHelp,
                  prefixIcon: const Icon(Icons.timer_outlined),
                  suffixText: l.preheatMinutes,
                  border: const OutlineInputBorder(),
                ),
              ),

              // A soak timer needs the print-notification service running, so
              // warn (with a one-tap enable) when it's off.
              if (soakMinutes > 0 && !notifsOn) ...[
                const SizedBox(height: 12),
                _NotifWarning(onEnable: _enableNotifications),
              ],
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_sending || !hasTemp) ? null : _submit,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_fire_department),
                  label: Text(l.preheatSet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One integer-°C temperature field. Empty = leave that heater alone; the
/// current target (when set) shows as the greyed hint so the user can see what
/// it's on now.
class _TempField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  final double currentTarget;
  final ValueChanged<String> onChanged;

  const _TempField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    required this.currentTarget,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        suffixText: '°C',
        hintText: currentTarget > 0 ? currentTarget.round().toString() : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Heads-up shown when a heat-soak timer is entered but print notifications are
/// off (so the alert can't fire), with a one-tap enable.
class _NotifWarning extends StatelessWidget {
  final VoidCallback onEnable;
  const _NotifWarning({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 20, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.preheatNotifWarning,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(onPressed: onEnable, child: Text(l.preheatNotifEnable)),
        ],
      ),
    );
  }
}
