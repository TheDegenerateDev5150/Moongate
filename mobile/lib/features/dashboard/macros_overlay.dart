import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../services/print_control_service.dart';
import '../../services/printer_registry.dart';

/// Bottom-sheet macro runner. Lists the Klipper macros defined on the printer
/// (Moonraker's `printer/objects/list`, filtered to `gcode_macro` entries),
/// lets the user **star** the ones they use most to pin them to the top, and
/// runs a macro after a confirmation. Opened from the macro button on an
/// online tile - see `printer_tile.dart`.
///
/// Hidden from the list (in [PrintControlService.listMacros]): `_`-prefixed
/// helper macros (Klipper's private-macro convention, e.g. `_Probe_Variables`)
/// and Moongate's own plumbing macros (`MOONGATE_PAIR` / `MOONGATE_RESET_OWNER`
/// - the latter would unpair the printer). Favourites are stored per-printer on
/// the config and ride backups.
Future<void> showMacrosSheet(BuildContext context, PrinterConfig printer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _MacrosSheet(printer: printer),
  );
}

class _MacrosSheet extends StatefulWidget {
  final PrinterConfig printer;
  const _MacrosSheet({required this.printer});

  @override
  State<_MacrosSheet> createState() => _MacrosSheetState();
}

class _MacrosSheetState extends State<_MacrosSheet> {
  late final PrintControlService _control;
  late Future<List<String>?> _future;

  /// Names the user has starred, pinned to the top. Seeded from the persisted
  /// per-printer config; mutated locally on each star tap and written straight
  /// back to the registry (which persists it + carries it into backups). The
  /// local set is the source of truth for this open sheet.
  late final Set<String> _favourites;

  /// Macro currently being sent - gates taps and shows a spinner on its row so
  /// a double-tap can't fire it twice.
  String? _running;

  @override
  void initState() {
    super.initState();
    _control = PrintControlService(widget.printer);
    _favourites = {...widget.printer.favouriteMacros};
    _future = _control.listMacros();
  }

  void _reload() => setState(() => _future = _control.listMacros());

  void _toggleFavourite(String macro) {
    setState(() {
      // Set.remove returns false when the element wasn't present - so a single
      // call both un-stars a favourite and stars a non-favourite.
      if (!_favourites.remove(macro)) _favourites.add(macro);
    });
    // Fire-and-forget: the local set already drives this frame, and the write
    // only needs to land before the sheet is next opened.
    PrinterRegistry.instance
        .updateFavouriteMacros(widget.printer.id, _favourites.toList());
  }

  Future<void> _run(String macro) async {
    if (_running != null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context); // survives a sheet rebuild

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.macroConfirmTitle),
        content: Text(l.macroConfirmBody(macro)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.macroRunAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _running = macro);
    final ok = await _control.runMacro(macro);
    if (!mounted) return;
    setState(() => _running = null);
    // Unlike starting a print, the sheet stays open so several macros can be
    // fired in a row.
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? l.macroSent(macro) : l.macroFailed(macro)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.macrosSheetTitle,
                          style: theme.textTheme.titleMedium),
                      Text(
                        widget.printer.name,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l.commonRetry,
                  onPressed: _reload,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Macro list / states ─────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<String>?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return _Centered(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l.macrosLoading,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                final macros = snap.data;
                if (macros == null) {
                  return _Centered(
                    child: _Message(
                      icon: Icons.cloud_off,
                      text: l.macrosError,
                      action: FilledButton.tonal(
                        onPressed: _reload,
                        child: Text(l.commonRetry),
                      ),
                    ),
                  );
                }
                if (macros.isEmpty) {
                  return _Centered(
                    child: _Message(
                      icon: Icons.code_off,
                      text: l.macrosEmpty,
                    ),
                  );
                }
                // Favourites first, each group alphabetised; a thin divider
                // marks where the pinned ones end.
                final favs = macros.where(_favourites.contains).toList()
                  ..sort(_byName);
                final rest =
                    macros.where((m) => !_favourites.contains(m)).toList()
                      ..sort(_byName);
                return SafeArea(
                  top: false,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final m in favs) _MacroRow(
                        name: m,
                        favourite: true,
                        running: _running == m,
                        enabled: _running == null,
                        onRun: () => _run(m),
                        onToggleFavourite: () => _toggleFavourite(m),
                      ),
                      if (favs.isNotEmpty && rest.isNotEmpty)
                        const Divider(height: 1),
                      for (final m in rest) _MacroRow(
                        name: m,
                        favourite: false,
                        running: _running == m,
                        enabled: _running == null,
                        onRun: () => _run(m),
                        onToggleFavourite: () => _toggleFavourite(m),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static int _byName(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());
}

/// One macro row: a tap runs it (after a confirm in the parent), the trailing
/// star pins/unpins it. While its macro is being sent the leading glyph becomes
/// a spinner and the whole list is disabled.
class _MacroRow extends StatelessWidget {
  final String name;
  final bool favourite;
  final bool running;
  final bool enabled;
  final VoidCallback onRun;
  final VoidCallback onToggleFavourite;

  const _MacroRow({
    required this.name,
    required this.favourite,
    required this.running,
    required this.enabled,
    required this.onRun,
    required this.onToggleFavourite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: running
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(Icons.code_rounded, color: theme.colorScheme.primary),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: IconButton(
        icon: Icon(
          favourite ? Icons.star_rounded : Icons.star_border_rounded,
          color: favourite ? Colors.amber : theme.colorScheme.outline,
        ),
        tooltip: favourite ? l.macroUnfavourite : l.macroFavourite,
        onPressed: onToggleFavourite,
      ),
      onTap: enabled ? onRun : null,
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: child));
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: theme.colorScheme.outline),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    );
  }
}
