import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../services/print_control_service.dart';

/// Bottom-sheet G-code browser. Lists the files already stored on the printer
/// (Moonraker's `gcodes` root), lets the user pick one, and starts it after a
/// confirmation. Opened from the folder button on an online-and-ready tile —
/// see `printer_tile.dart`. The button itself is hidden while a print is
/// running, so this sheet is only ever reached when the printer can accept a
/// new job.
Future<void> showGcodeFilesSheet(BuildContext context, PrinterConfig printer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _GcodeFilesSheet(printer: printer),
  );
}

class _GcodeFilesSheet extends StatefulWidget {
  final PrinterConfig printer;
  const _GcodeFilesSheet({required this.printer});

  @override
  State<_GcodeFilesSheet> createState() => _GcodeFilesSheetState();
}

class _GcodeFilesSheetState extends State<_GcodeFilesSheet> {
  late final PrintControlService _control;
  late Future<GcodeListing?> _future;
  String? _selected; // selected file's path, or null
  bool _starting = false;

  /// In-flight / loaded thumbnail fetches keyed by file path, so scrolling the
  /// list doesn't refetch as ListView rebuilds tiles.
  final Map<String, Future<Uint8List?>> _thumbs = {};

  @override
  void initState() {
    super.initState();
    _control = PrintControlService(widget.printer);
    _future = _control.listGcodes();
  }

  void _reload() => setState(() {
        _selected = null;
        _thumbs.clear();
        _future = _control.listGcodes();
      });

  Future<Uint8List?> _thumb(GcodeFile f, GcodeListing listing) =>
      _thumbs.putIfAbsent(
          f.path,
          () => _control.fetchThumbnail(f,
              base: listing.base, isLan: listing.isLan));

  Future<void> _start() async {
    final path = _selected;
    if (path == null || _starting) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context); // survives the sheet close
    final name = path.split('/').last;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.gcodeConfirmTitle),
        content: Text(l.gcodeConfirmBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.gcodeStartAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _starting = true);
    final ok = await _control.startPrint(path);
    if (!mounted) return;
    Navigator.of(context).pop(); // close the sheet
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? l.gcodeStarted(name) : l.gcodeStartFailed),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
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
                        Text(l.gcodeSheetTitle, style: theme.textTheme.titleMedium),
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

            // ── File list / states ──────────────────────────────────────
            Expanded(
              child: FutureBuilder<GcodeListing?>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return _Centered(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l.gcodeLoading,
                              style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    );
                  }
                  final listing = snap.data;
                  if (listing == null) {
                    return _Centered(
                      child: _Message(
                        icon: Icons.cloud_off,
                        text: l.gcodeError,
                        action: FilledButton.tonal(
                          onPressed: _reload,
                          child: Text(l.commonRetry),
                        ),
                      ),
                    );
                  }
                  final files = listing.files;
                  if (files.isEmpty) {
                    return _Centered(
                      child: _Message(
                        icon: Icons.folder_off_outlined,
                        text: l.gcodeEmpty,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: files.length,
                    itemBuilder: (context, i) {
                      final f = files[i];
                      final selected = f.path == _selected;
                      return ListTile(
                        selected: selected,
                        selectedTileColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        leading: _GcodeThumb(future: _thumb(f, listing)),
                        title: Text(f.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_subtitle(context, f),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: selected
                            ? Icon(Icons.check_circle,
                                color: theme.colorScheme.primary)
                            : null,
                        onTap: () => setState(
                            () => _selected = selected ? null : f.path),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Start bar ───────────────────────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed:
                        (_selected != null && !_starting) ? _start : null,
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(l.gcodeStartButton),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "subfolder · 12 Jun 2026 · 4.2 MB" — parts omitted when unknown.
  String _subtitle(BuildContext context, GcodeFile f) {
    final parts = <String>[];
    if (f.folder != null) parts.add(f.folder!);
    final dt = f.modifiedAt;
    if (dt != null) {
      parts.add(MaterialLocalizations.of(context).formatShortDate(dt));
    }
    final size = _formatSize(f.size);
    if (size.isNotEmpty) parts.add(size);
    return parts.join('  ·  ');
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var s = bytes.toDouble();
    var u = 0;
    while (s >= 1024 && u < units.length - 1) {
      s /= 1024;
      u++;
    }
    final decimals = (u == 0 || s >= 100) ? 0 : 1;
    return '${s.toStringAsFixed(decimals)} ${units[u]}';
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

/// Leading thumbnail for a G-code row: the slicer-embedded preview when the
/// file has one, otherwise a legible file glyph. Always a fixed rounded box so
/// the row height stays even whether or not a thumbnail loads.
class _GcodeThumb extends StatelessWidget {
  final Future<Uint8List?> future;
  const _GcodeThumb({required this.future});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 46,
        height: 46,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        child: FutureBuilder<Uint8List?>(
          future: future,
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes != null && bytes.isNotEmpty) {
              return Image.memory(bytes,
                  fit: BoxFit.cover, gaplessPlayback: true);
            }
            // Loading, or the file has no embedded thumbnail — show a clear
            // glyph rather than the faint outline icon it replaces.
            return Icon(Icons.description,
                size: 24, color: theme.colorScheme.onSurfaceVariant);
          },
        ),
      ),
    );
  }
}
