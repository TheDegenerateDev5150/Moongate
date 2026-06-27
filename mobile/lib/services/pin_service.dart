import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores and verifies the optional app-lock PIN.
///
/// Security model: a 4-6 digit PIN has a tiny keyspace, so the real defenses
/// are (1) [FlutterSecureStorage], which is Android Keystore-backed and keeps
/// the hash encrypted at rest, and (2) the escalating attempt lockout below.
/// The salted SHA-256 hash is defense-in-depth should the encrypted blob ever
/// be extracted - we never store the PIN in the clear.
const _storage = FlutterSecureStorage();

class PinService {
  PinService._();
  static final PinService instance = PinService._();

  static const _hashKey    = 'moongate_pin_hash';
  static const _saltKey    = 'moongate_pin_salt';
  static const _lenKey     = 'moongate_pin_len';
  static const _failKey    = 'moongate_pin_fail_count';
  static const _lockoutKey = 'moongate_pin_lockout_until';

  Future<bool> hasPin() async => (await _storage.read(key: _hashKey)) != null;

  /// Digit count of the stored PIN, so the lock screen can auto-submit when the
  /// user reaches it. Falls back to 4 when no PIN is set.
  Future<int> pinLength() async =>
      int.tryParse(await _storage.read(key: _lenKey) ?? '') ?? 4;

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(16);
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: base64Encode(_hash(pin, salt)));
    await _storage.write(key: _lenKey, value: '${pin.length}');
    await resetThrottle();
  }

  /// Verifies [pin]. Returns false (without consuming an attempt) while a
  /// lockout is active. A wrong PIN records the failure and may start a
  /// lockout; a correct PIN clears the throttle.
  Future<bool> verifyPin(String pin) async {
    if (await remainingLockout() != null) return false;
    final saltB64 = await _storage.read(key: _saltKey);
    final hashB64 = await _storage.read(key: _hashKey);
    if (saltB64 == null || hashB64 == null) return false;
    final ok = _constantTimeEquals(
      base64Decode(hashB64),
      _hash(pin, base64Decode(saltB64)),
    );
    if (ok) {
      await resetThrottle();
    } else {
      await _recordFailure();
    }
    return ok;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _lenKey);
    await resetThrottle();
  }

  Future<int> failedAttempts() async =>
      int.tryParse(await _storage.read(key: _failKey) ?? '') ?? 0;

  /// Time left on the current lockout, or null if entry is allowed right now.
  Future<Duration?> remainingLockout() async {
    final untilMs = int.tryParse(await _storage.read(key: _lockoutKey) ?? '');
    if (untilMs == null) return null;
    final ms = untilMs - DateTime.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : null;
  }

  Future<void> resetThrottle() async {
    await _storage.delete(key: _failKey);
    await _storage.delete(key: _lockoutKey);
  }

  // ── internals ──────────────────────────────────────────────────────────

  Future<void> _recordFailure() async {
    final fails = (await failedAttempts()) + 1;
    await _storage.write(key: _failKey, value: '$fails');
    final seconds = _lockoutSecondsFor(fails);
    if (seconds > 0) {
      final until = DateTime.now().millisecondsSinceEpoch + seconds * 1000;
      await _storage.write(key: _lockoutKey, value: '$until');
    }
  }

  /// Attempts 1-4 are free; escalate from the 5th consecutive failure.
  int _lockoutSecondsFor(int fails) => switch (fails) {
        < 5 => 0,
        5 => 30,
        6 => 60,
        7 => 300,
        8 => 900,
        _ => 1800,
      };

  List<int> _hash(String pin, List<int> salt) =>
      sha256.convert(<int>[...salt, ...utf8.encode(pin)]).bytes;

  Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
