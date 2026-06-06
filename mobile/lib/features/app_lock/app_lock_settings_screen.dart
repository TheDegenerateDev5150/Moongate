import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_lock_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/pin_service.dart';
import 'pin_pad.dart';

/// Configure the optional app lock: enable/disable (with PIN setup/verify),
/// biometric unlock, auto-lock timeout, and changing the PIN. Reached from the
/// dashboard drawer ("App lock") at /settings/app-lock.
class AppLockSettingsScreen extends ConsumerWidget {
  const AppLockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appLockEnabledProvider);
    final biometric = ref.watch(biometricUnlockProvider);
    final timeout = ref.watch(autoLockTimeoutProvider);
    final bioAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Require a PIN — and optionally your fingerprint or face — before '
              'Moongate will open. The lock always appears when the app is '
              'started fresh.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('App lock'),
            subtitle: const Text('PIN required to open the app'),
            value: enabled,
            onChanged: (v) => _toggleEnabled(context, ref, v),
          ),
          if (enabled) ...[
            const Divider(),
            if (bioAvailable)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Biometric unlock'),
                subtitle:
                    const Text('Use fingerprint or face — PIN stays as a fallback'),
                value: biometric,
                onChanged: (v) =>
                    ref.read(biometricUnlockProvider.notifier).set(v),
              ),
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change PIN'),
              onTap: () => _changePin(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Auto-lock'),
              subtitle: Text(timeout.label),
              onTap: () => _pickTimeout(context, ref, timeout),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleEnabled(
      BuildContext context, WidgetRef ref, bool value) async {
    if (value) {
      final pin = await _setNewPin(context);
      if (pin == null) return; // cancelled → the preference stays off
      await ref.read(appLockEnabledProvider.notifier).set(true);
    } else {
      if (!await _verifyCurrent(context)) return;
      await ref.read(appLockEnabledProvider.notifier).set(false);
      await ref.read(biometricUnlockProvider.notifier).set(false);
      await PinService.instance.clearPin();
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    if (!await _verifyCurrent(context)) return;
    if (!context.mounted) return;
    final pin = await _setNewPin(context);
    if (pin == null) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN updated')));
    }
  }

  /// Enter then confirm a new PIN; persists it via [PinService]. Returns the
  /// chosen PIN, or null if cancelled.
  Future<String?> _setNewPin(BuildContext context) async {
    final pin1 = await showPinSheet(context,
        title: 'Choose a PIN', subtitle: 'Enter 4–6 digits');
    if (pin1 == null || !context.mounted) return null;
    final pin2 = await showPinSheet(context,
        title: 'Confirm PIN',
        expectedLength: pin1.length,
        validator: (p) async => p == pin1 ? null : "PINs don't match");
    if (pin2 == null) return null;
    await PinService.instance.setPin(pin1);
    return pin1;
  }

  /// Prompt for the current PIN, verifying with the throttle. Returns true if
  /// correct.
  Future<bool> _verifyCurrent(BuildContext context) async {
    final len = await PinService.instance.pinLength();
    if (!context.mounted) return false;
    final res = await showPinSheet(context,
        title: 'Enter current PIN',
        expectedLength: len,
        validator: (p) async {
          final lock = await PinService.instance.remainingLockout();
          if (lock != null) {
            return 'Too many attempts. Try again in ${lock.inSeconds}s';
          }
          return await PinService.instance.verifyPin(p) ? null : 'Wrong PIN';
        });
    return res != null;
  }

  Future<void> _pickTimeout(
      BuildContext context, WidgetRef ref, AutoLockTimeout current) async {
    final picked = await showDialog<AutoLockTimeout>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-lock'),
        children: AutoLockTimeout.values
            .map((t) => ListTile(
                  title: Text(t.label),
                  trailing: t == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, t),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      ref.read(autoLockTimeoutProvider.notifier).set(picked);
    }
  }
}
