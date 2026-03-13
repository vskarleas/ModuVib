import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════
// LOCAL SECURITY SERVICE — PIN & biometric management
// ══════════════════════════════════════════════════════════════

class LocalSecurityService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // ══════════════════════════════════════════════════════════════
  // PIN MANAGEMENT
  // ══════════════════════════════════════════════════════════════

  /// Hash a PIN using SHA-256 with the user's UID as salt.
  String _hashPin(String uid, String pin) {
    final bytes = utf8.encode('$uid:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Save a hashed PIN for the given user.
  Future<void> savePin(String uid, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(uid, pin);
    await prefs.setString('pin_hash_$uid', hash);
  }

  /// Verify a PIN against the stored hash.
  Future<bool> verifyPin(String uid, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('pin_hash_$uid');
    if (storedHash == null) return false;
    return _hashPin(uid, pin) == storedHash;
  }

  /// Check whether a PIN has been set for the given user.
  Future<bool> hasPin(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('pin_hash_$uid');
  }

  // ══════════════════════════════════════════════════════════════
  // BIOMETRIC PREFERENCE
  // ══════════════════════════════════════════════════════════════

  /// Store the user's biometric preference.
  Future<void> setBiometricEnabled(String uid, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled_$uid', enabled);
  }

  /// Read the user's biometric preference (defaults to false).
  Future<bool> isBiometricEnabled(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled_$uid') ?? false;
  }

  // ══════════════════════════════════════════════════════════════
  // SECURITY SETUP FLAG
  // ══════════════════════════════════════════════════════════════

  /// Check whether the user has completed security setup.
  Future<bool> isSecuritySetupComplete(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('security_setup_complete_$uid') ?? false;
  }

  /// Mark security setup as complete for the given user.
  Future<void> markSecuritySetupComplete(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('security_setup_complete_$uid', true);
  }

  // ══════════════════════════════════════════════════════════════
  // BIOMETRIC AUTHENTICATION (local_auth)
  // ══════════════════════════════════════════════════════════════

  /// Check if the device supports biometric authentication.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompt the user for biometric authentication.
  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
