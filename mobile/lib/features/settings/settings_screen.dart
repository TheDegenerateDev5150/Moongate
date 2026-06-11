import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../services/printer_access_cache.dart';
import '../../services/printer_registry.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(l.settingsRemoveAllTitle,
                style: const TextStyle(color: Colors.redAccent)),
            subtitle: Text(l.settingsRemoveAllSubtitle),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.settingsRemoveAllConfirmTitle),
                  content: Text(l.settingsRemoveAllConfirmBody),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.commonCancel)),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.settingsRemoveAllConfirmAction),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                PrinterAccessCache.instance.clear();
                for (final p in List.of(PrinterRegistry.instance.printers)) {
                  await PrinterRegistry.instance.remove(p.id);
                }
                if (context.mounted) context.go('/pair');
              }
            },
          ),
        ],
      ),
    );
  }
}
