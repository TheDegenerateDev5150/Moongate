import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/services.dart';

import 'supabase_service.dart';

/// iOS background push notifications.
///
/// Talks to the native side over a MethodChannel (mirroring the app-lock
/// secure channel): asks the OS for permission, registers with Apple, receives
/// the APNs device token, and hands it to the register-push-token Edge Function
/// so the cloud can deliver "print finished / failed" alerts while the app is
/// closed.
///
/// iOS only for now - Android keeps its existing foreground-service
/// notifications, so this is a no-op there. Everything degrades quietly: with
/// no paid Apple account the native registration fails (no aps-environment
/// entitlement), so we simply never receive a token and nothing is sent.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const MethodChannel _channel = MethodChannel('com.moongate.app/push');
  final SupabaseService _supabase = SupabaseService.instance;

  // The APNs token can arrive before anonymous sign-in has completed; stash it
  // and register once we hold a session (the register-push-token call needs the
  // user's JWT).
  String? _pendingToken;
  bool _started = false;

  void _log(String msg) => dev.log(msg, name: 'MOONGATE/PUSH');

  /// Wire up the token callback and ask the OS for notification permission.
  /// Call once at startup. No-op on Android and after the first call.
  Future<void> start() async {
    if (_started || !Platform.isIOS) return;
    _started = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onToken') {
        final token = call.arguments as String?;
        if (token != null && token.isNotEmpty) _onToken(token);
      }
      return null;
    });

    // Retry a stashed token the moment a session lands.
    _supabase.signedIn.addListener(_flushPending);

    try {
      final granted =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      _log('Notification permission granted=$granted');
      // If granted, the native side registers with Apple and calls back
      // 'onToken' with the device token (handled above).
    } on PlatformException catch (e) {
      _log('requestPermission failed: $e');
    }
  }

  void _onToken(String token) {
    _pendingToken = token;
    _flushPending();
  }

  void _flushPending() {
    final token = _pendingToken;
    if (token == null) return;
    if (!_supabase.ready) return; // not signed in yet; the listener will retry
    _pendingToken = null;
    _supabase.registerPushToken(token: token, platform: 'ios');
  }
}
