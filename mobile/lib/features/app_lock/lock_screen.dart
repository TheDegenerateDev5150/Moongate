import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../providers/app_lock_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/pin_service.dart';
import '../../services/printer_access_cache.dart';
import '../../services/printer_registry.dart';
import 'pin_pad.dart';

/// The full-screen lock shown by [AppLockGate] while the app is locked. Offers
/// PIN entry and, when enabled+available, a biometric prompt (auto-triggered
/// once on appearance). A low-key "Forgot PIN?" resets the app as an escape
/// hatch.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  int _pinLength = 4;
  Duration? _lockout;
  Timer? _ticker;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final len = await PinService.instance.pinLength();
    final lock = await PinService.instance.remainingLockout();
    if (!mounted) return;
    setState(() {
      _pinLength = len;
      _lockout = lock;
    });
    if (lock != null) _startTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPrompt());
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final lock = await PinService.instance.remainingLockout();
      if (!mounted) return;
      setState(() => _lockout = lock);
      if (lock == null) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _maybeAutoPrompt() async {
    if (_autoPrompted) return;
    _autoPrompted = true;
    if (!ref.read(biometricUnlockProvider)) return;
    if (!await ref.read(biometricAvailableProvider.future)) return;
    await _promptBiometric();
  }

  Future<void> _promptBiometric() async {
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Moongate',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) ref.read(lockStateProvider.notifier).unlockWithBiometric();
    } catch (_) {
      // No biometrics enrolled / sensor busy → fall back to the PIN silently.
    }
  }

  Future<String?> _onPin(String pin) async {
    final ok = await ref.read(lockStateProvider.notifier).unlockWithPin(pin);
    if (ok) return null; // the gate removes this screen on the next build
    final lock = await PinService.instance.remainingLockout();
    if (lock != null) {
      _startTicker();
      if (mounted) setState(() => _lockout = lock);
      return null; // the status line shows the countdown
    }
    return 'Wrong PIN';
  }

  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Moongate?'),
        content: const Text(
            'This removes the app lock and clears the paired printers from '
            'this device so you can start over. Your printers are not deleted '
            '— re-pair them by running MOONGATE_PAIR on each one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PinService.instance.clearPin();
    await ref.read(appLockEnabledProvider.notifier).set(false);
    await ref.read(biometricUnlockProvider.notifier).set(false);
    PrinterAccessCache.instance.clear();
    for (final p in List.of(PrinterRegistry.instance.printers)) {
      await PrinterRegistry.instance.remove(p.id);
    }
    ref.read(lockStateProvider.notifier).unlock();
    if (mounted) context.go('/pair');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lockedOut = _lockout != null;
    final showBiometric = ref.watch(biometricUnlockProvider) &&
        (ref.watch(biometricAvailableProvider).valueOrNull ?? false);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.lock_rounded, size: 38, color: cs.primary),
                ),
                const SizedBox(height: 8),
                PinEntryView(
                  title: 'Enter your PIN',
                  subtitle: 'Moongate is locked',
                  expectedLength: _pinLength,
                  enabled: !lockedOut,
                  statusText: lockedOut
                      ? 'Too many attempts. Try again in ${_lockout!.inSeconds}s'
                      : null,
                  onSubmit: _onPin,
                  belowKeypad: Column(
                    children: [
                      if (showBiometric)
                        TextButton.icon(
                          onPressed: lockedOut ? null : _promptBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Use biometrics'),
                        ),
                      TextButton(
                        onPressed: _forgotPin,
                        child: const Text('Forgot PIN?'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
