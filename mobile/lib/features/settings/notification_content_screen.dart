import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/notif_fields.dart';
import '../../providers/settings_provider.dart';
import '../../services/print_notification_service.dart';

/// Lets the user choose which details appear on each print's notification card
/// - and drag them into the order they want on the phone. Reached from the
/// dashboard drawer (under "Print notifications") at /settings/notifications.
/// The printer name is fixed and so isn't listed here.
class NotificationContentScreen extends ConsumerWidget {
  const NotificationContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(notificationFieldsProvider);
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.notifContentTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              l.notifContentIntro,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          // Live preview of the resulting notification line - updates as fields
          // are toggled / reordered, using representative sample values.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PreviewCard(cfg: cfg),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView(
              // Drag only from the handle so the row's switch stays tappable.
              buildDefaultDragHandles: false,
              // + the system bar inset: explicit padding switches off the
              // list's automatic safe-area handling, and the last row's drag
              // handle was sitting under the Android button/gesture bar.
              padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.of(context).padding.bottom),
              // onReorder is current on stable Flutter; only this box's
              // pre-release SDK flags it (the onReorderItem replacement doesn't
              // exist on stable, so switching would break the CI build).
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) async {
                await ref
                    .read(notificationFieldsProvider.notifier)
                    .reorder(oldIndex, newIndex);
                PrintNotificationService.instance.refreshNow();
              },
              children: [
                for (int i = 0; i < cfg.order.length; i++)
                  _FieldRow(
                    key: ValueKey(cfg.order[i]),
                    index: i,
                    field: cfg.order[i],
                    enabled: cfg.enabled.contains(cfg.order[i]),
                    onChanged: (v) async {
                      await ref
                          .read(notificationFieldsProvider.notifier)
                          .setEnabled(cfg.order[i], v);
                      PrintNotificationService.instance.refreshNow();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The faux-notification preview that reflects the current field set + order.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.cfg});
  final NotifFieldsConfig cfg;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final shown =
        cfg.order.where(cfg.enabled.contains).map(notifFieldExample).toList();
    // Generic placeholder for the preview; the live notification uses the
    // printer's real name.
    final name = '(${l.printerNameLabel})';
    final line =
        shown.isEmpty ? '🖨️ $name' : '🖨️ $name - ${shown.join(' · ')}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.notifContentPreview,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
            ),
            const SizedBox(height: 4),
            Text(line, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// One reorderable, switchable field row with a drag handle on the left.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.index,
    required this.field,
    required this.enabled,
    required this.onChanged,
  });

  final int index;
  final NotifField field;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile(
      secondary: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(_label(l, field)),
      subtitle: Text(notifFieldExample(field)),
      value: enabled,
      onChanged: onChanged,
    );
  }

  String _label(AppLocalizations l, NotifField f) => switch (f) {
        NotifField.progress => l.notifFieldProgress,
        NotifField.remaining => l.notifFieldRemaining,
        NotifField.eta => l.notifFieldEta,
        NotifField.hotend => l.notifFieldHotend,
        NotifField.bed => l.notifFieldBed,
      };
}
