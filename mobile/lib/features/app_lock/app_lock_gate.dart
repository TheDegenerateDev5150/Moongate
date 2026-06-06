import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_lock_provider.dart';
import 'lock_screen.dart';

/// Wraps the whole app (mounted in [app.dart]'s `MaterialApp.router` builder).
/// While locked it paints an opaque [LockScreen] over everything — above the
/// router's Navigator, so no route can render without it and the underlying
/// navigation state is preserved for when the user unlocks. Also drives
/// FLAG_SECURE so the lock (and the app's contents while locked) are kept out
/// of screenshots and the recent-apps thumbnail.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  static const _secure = MethodChannel('com.moongate.app/secure');
  bool? _lastSecure;

  void _applySecure(bool on) {
    if (_lastSecure == on) return;
    _lastSecure = on;
    _secure.invokeMethod('setSecure', {'on': on}).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(lockStateProvider) == LockStatus.locked;
    _applySecure(locked);
    return Stack(
      children: [
        widget.child,
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
