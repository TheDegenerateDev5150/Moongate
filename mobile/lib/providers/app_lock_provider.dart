import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../services/pin_service.dart';
import 'settings_provider.dart';

enum LockStatus { locked, unlocked }

/// Runtime locked/unlocked state behind the app-lock overlay. Distinct from the
/// persisted [appLockEnabledProvider] preference - this is the live gate that
/// [app.dart]'s `_AppLockGate` watches.
class AppLockController extends Notifier<LockStatus> {
  DateTime? _backgroundedAt;

  @override
  LockStatus build() {
    // A one-time read (not a watch): toggling the preference mid-session must
    // not lock/unlock the running app - enabling takes effect on next launch.
    if (!ref.read(appLockEnabledProvider)) return LockStatus.unlocked;
    // Optimistically lock on cold launch, then verify a PIN actually exists and
    // fail OPEN if it doesn't, so a desynced preference can't trap the user.
    _failOpenIfNoPin();
    return LockStatus.locked;
  }

  Future<void> _failOpenIfNoPin() async {
    if (!await PinService.instance.hasPin()) {
      state = LockStatus.unlocked;
      await ref.read(appLockEnabledProvider.notifier).set(false);
    }
  }

  /// Record the moment we go to the background (read by [evaluateOnResume]).
  void markBackgrounded() => _backgroundedAt = DateTime.now();

  /// On resume, re-lock if the configured background timeout has elapsed.
  /// No-op for the default `coldLaunchOnly` (resumeAfter == null).
  void evaluateOnResume() {
    if (state == LockStatus.locked) return;
    if (!ref.read(appLockEnabledProvider)) return;
    final after = ref.read(autoLockTimeoutProvider).resumeAfter;
    if (after == null) return;
    final since = _backgroundedAt;
    if (since != null && DateTime.now().difference(since) >= after) {
      state = LockStatus.locked;
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await PinService.instance.verifyPin(pin);
    if (ok) state = LockStatus.unlocked;
    return ok;
  }

  void unlockWithBiometric() {
    PinService.instance.resetThrottle();
    state = LockStatus.unlocked;
  }

  /// Plain unlock with no PIN/biometric check - used only by the "Forgot PIN?"
  /// reset, which has already wiped the PIN and local data.
  void unlock() => state = LockStatus.unlocked;

  void lockNow() => state = LockStatus.locked;
}

final lockStateProvider =
    NotifierProvider<AppLockController, LockStatus>(AppLockController.new);

/// True only when the device has usable biometric hardware. Gates whether the
/// biometric toggle (settings) and the biometric button (lock screen) render.
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) return false;
    return await auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
});
