import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../services/print_control_service.dart';
import '../../services/printer_status_registry.dart';

/// Outcome of a global power action, surfaced as a snackbar by the caller after
/// the sheet closes (the sheet's own context is gone once it pops).
class _PowerResult {
  final bool on; // true = powered on, false = powered off
  final int done; // machines where every device toggled successfully
  final int total; // machines we attempted
  const _PowerResult(
      {required this.on, required this.done, required this.total});

  String message(AppLocalizations l) =>
      on ? l.globalPowerResultOn(done, total) : l.globalPowerResultOff(done, total);
}

/// Show the "power all machines" sheet. On open it fetches each printer's
/// Moonraker power devices (on demand, no background polling), then lets the
/// user switch them all on (a tap, low risk) or off (a slide-to-confirm, the
/// deliberate one). Machines that are printing or unreachable are excluded from
/// power-off and shown as such. Surfaces a result snackbar via [context] once it
/// closes.
Future<void> showGlobalPowerSheet(
    BuildContext context, List<PrinterConfig> printers) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = AppLocalizations.of(context);
  final result = await showModalBottomSheet<_PowerResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _GlobalPowerSheet(printers: printers),
  );
  if (result != null) {
    messenger.showSnackBar(SnackBar(content: Text(result.message(l))));
  }
}

/// One dashboard printer plus the power state resolved for it when the sheet
/// opened.
class _Row {
  final PrinterConfig printer;

  /// Its Moonraker power devices, or null when the printer was unreachable.
  final List<PowerDevice>? devices;

  /// Whether it is currently printing or paused (excluded from power-off).
  final bool printing;

  _Row(this.printer, this.devices, this.printing);

  bool get reachable => devices != null;
  bool get hasDevices => devices != null && devices!.isNotEmpty;

  /// Eligible to be switched off by "power off all": reachable, has a device,
  /// and not mid-print.
  bool get offTarget => hasDevices && !printing;
}

class _GlobalPowerSheet extends StatefulWidget {
  final List<PrinterConfig> printers;
  const _GlobalPowerSheet({required this.printers});

  @override
  State<_GlobalPowerSheet> createState() => _GlobalPowerSheetState();
}

class _GlobalPowerSheetState extends State<_GlobalPowerSheet> {
  List<_Row>? _rows; // null while loading
  bool _busy = false; // an on/off run is in progress

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    // Resolve every printer's power devices in parallel. Whether it is printing
    // is read from the live status registry (no extra round-trip) so we can keep
    // a running print powered on.
    final rows = await Future.wait(widget.printers.map((p) async {
      final devices = await PrintControlService(p).listPowerDevices();
      final st = PrinterStatusRegistry.instance.snapshot(p.id);
      final printing =
          st != null && (st.state == 'printing' || st.state == 'paused');
      return _Row(p, devices, printing);
    }));
    if (!mounted) return;
    // Show machines that expose a power device, plus unreachable ones (so the
    // user sees they were skipped). A reachable machine with no [power] device
    // is irrelevant here, so it is hidden.
    setState(() =>
        _rows = rows.where((r) => r.hasDevices || !r.reachable).toList());
  }

  Future<void> _powerOnAll() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.globalPowerConfirmOnTitle),
        content: Text(l.globalPowerConfirmOnBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.globalPowerOnAll),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(on: true, targets: _rows!.where((r) => r.hasDevices).toList());
  }

  Future<void> _powerOffAll() =>
      _run(on: false, targets: _rows!.where((r) => r.offTarget).toList());

  Future<void> _run({required bool on, required List<_Row> targets}) async {
    setState(() => _busy = true);
    var done = 0;
    for (final r in targets) {
      final svc = PrintControlService(r.printer);
      var allOk = true;
      for (final d in r.devices!) {
        if (!await svc.setPowerDevice(d.name, on)) allOk = false;
      }
      if (allOk) done++;
    }
    if (!mounted) return;
    Navigator.pop(
        context, _PowerResult(on: on, done: done, total: targets.length));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = _rows;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.power_settings_new, size: 22),
                const SizedBox(width: 8),
                Text(l.globalPowerSheetTitle,
                    style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            if (rows == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rows.where((r) => r.hasDevices).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.globalPowerNothing,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor)),
              )
            else ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final r in rows) _rowTile(r, theme, l)],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _powerOnAll,
                  icon: const Icon(Icons.power_settings_new, size: 18),
                  label: Text(l.globalPowerOnAll),
                ),
              ),
              const SizedBox(height: 10),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (rows.any((r) => r.offTarget))
                _SlideToConfirm(
                    label: l.globalPowerSlideOff, onConfirm: _powerOffAll),
              const SizedBox(height: 8),
              Center(
                child: Text(l.globalPowerPrintingNote,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rowTile(_Row r, ThemeData theme, AppLocalizations l) {
    final cs = theme.colorScheme;
    String label;
    Color color;
    if (!r.reachable) {
      label = l.globalPowerStateOffline;
      color = theme.hintColor;
    } else if (r.printing) {
      label = l.globalPowerStateKeptPrinting;
      color = cs.tertiary;
    } else {
      label = l.globalPowerStateWillSwitchOff;
      color = cs.primary;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.print_outlined,
              size: 18, color: r.reachable ? null : theme.disabledColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(r.printer.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(label,
              style: theme.textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Slide-to-confirm control: drag the thumb across to fire [onConfirm]. Used for
/// the deliberately-hard "power off everything" action so it can never be a
/// stray tap. Releasing short of the end snaps back; clearing ~90% commits.
class _SlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback onConfirm;
  const _SlideToConfirm({required this.label, required this.onConfirm});

  @override
  State<_SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<_SlideToConfirm> {
  double _dx = 0;
  bool _committed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const height = 52.0;
    const thumb = 46.0;
    return LayoutBuilder(builder: (ctx, c) {
      final maxDx = (c.maxWidth - thumb - 4).clamp(0.0, double.infinity);
      final progress = maxDx == 0 ? 0.0 : (_dx / maxDx).clamp(0.0, 1.0);
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Opacity(
                opacity: (1 - progress).clamp(0.0, 1.0),
                child: Text(widget.label,
                    style: TextStyle(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              left: 2 + _dx,
              top: 3,
              child: GestureDetector(
                onHorizontalDragUpdate: _committed
                    ? null
                    : (d) => setState(
                        () => _dx = (_dx + d.delta.dx).clamp(0.0, maxDx)),
                onHorizontalDragEnd: _committed
                    ? null
                    : (_) {
                        if (_dx >= maxDx * 0.9) {
                          setState(() {
                            _dx = maxDx;
                            _committed = true;
                          });
                          widget.onConfirm();
                        } else {
                          setState(() => _dx = 0);
                        }
                      },
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration:
                      BoxDecoration(color: cs.error, shape: BoxShape.circle),
                  child: Icon(
                      _committed ? Icons.check : Icons.power_settings_new,
                      color: cs.onError),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
