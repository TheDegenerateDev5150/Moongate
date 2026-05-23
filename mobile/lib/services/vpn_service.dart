import 'package:flutter/services.dart';

/// Manages the WireGuard VPN tunnel lifecycle.
///
/// The tunnel is started when the app comes to foreground and stopped
/// when the app is closed or sent to background (configurable).
/// On Android this shows the OS VPN key icon — this is an OS requirement
/// and cannot be suppressed. No pop-up, no sound.
class VpnService {
  VpnService._();
  static final VpnService instance = VpnService._();

  static const _channel = MethodChannel('com.moongate.app/vpn');

  bool _initialized = false;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // Platform channel handler for status callbacks from native code
    _channel.setMethodCallHandler(_onNativeCall);
  }

  /// Connect the WireGuard tunnel using [config] (WireGuard INI format).
  Future<void> connect(String config) async {
    await _channel.invokeMethod('connect', {'config': config});
    _connected = true;
  }

  /// Disconnect and tear down the tunnel immediately.
  /// Silently ignores PlatformException — the VPN may not be active or the
  /// native service may be unavailable (e.g. Cloudflare-only builds).
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
    _connected = false;
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onConnected':
        _connected = true;
      case 'onDisconnected':
        _connected = false;
    }
  }
}
