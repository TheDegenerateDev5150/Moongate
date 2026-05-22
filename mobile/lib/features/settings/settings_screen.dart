import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/vpn_service.dart';
import '../../services/auth_service.dart';
import '../../services/printer_registry.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sign out of all printers',
                style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Removes all paired printers from this device.'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                      'All paired printers will be removed from this device.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await VpnService.instance.disconnect();
                await AuthService.instance.signOut();
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
