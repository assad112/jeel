import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing information (login credentials)
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Storage keys
  static const String _usernameKey = 'saved_username';
  static const String _passwordKey = 'saved_password';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _autoLoginEnabledKey = 'auto_login_enabled';

  /// Save login credentials with verification
  static Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    try {
      // Validate input
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Username and password cannot be empty');
      }

      // Save username
      await _storage.write(key: _usernameKey, value: username.trim());
      
      // Save password
      await _storage.write(key: _passwordKey, value: password);

      // Verify that data was saved correctly
      final savedUsername = await _storage.read(key: _usernameKey);
      final savedPassword = await _storage.read(key: _passwordKey);

      if (savedUsername != username.trim() || savedPassword != password) {
        throw Exception('Verification failed: Saved data does not match');
      }

      debugPrint('✅ Credentials saved and verified successfully');
    } catch (e) {
      debugPrint('❌ Error saving credentials: $e');
      rethrow;
    }
  }

  /// Read login credentials
  static Future<Map<String, String?>> getCredentials() async {
    try {
      final username = await _storage.read(key: _usernameKey);
      final password = await _storage.read(key: _passwordKey);
      return {
        'username': username,
        'password': password,
      };
    } catch (e) {
      debugPrint('Error reading credentials: $e');
      return {'username': null, 'password': null};
    }
  }

  /// Check if credentials are saved
  static Future<bool> hasSavedCredentials() async {
    try {
      final username = await _storage.read(key: _usernameKey);
      final password = await _storage.read(key: _passwordKey);
      return username != null && password != null && username.isNotEmpty && password.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking saved credentials: $e');
      return false;
    }
  }

  /// Delete login credentials
  static Future<void> deleteCredentials() async {
    try {
      await _storage.delete(key: _usernameKey);
      await _storage.delete(key: _passwordKey);
      await _storage.delete(key: _biometricEnabledKey);
      await _storage.delete(key: _autoLoginEnabledKey);
      debugPrint('Credentials deleted');
    } catch (e) {
      debugPrint('Error deleting credentials: $e');
    }
  }

  /// Enable/disable biometric authentication with verification
  static Future<void> setBiometricEnabled(bool enabled) async {
    try {
      // Save the setting
      await _storage.write(key: _biometricEnabledKey, value: enabled.toString());

      // Verify that it was saved correctly
      final savedValue = await _storage.read(key: _biometricEnabledKey);
      if (savedValue != enabled.toString()) {
        throw Exception('Failed to verify biometric setting');
      }

      debugPrint('✅ Biometric enabled status set to: $enabled');
    } catch (e) {
      debugPrint('❌ Error setting biometric enabled: $e');
      rethrow;
    }
  }

  /// Check if biometric authentication is enabled
  static Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error checking biometric enabled: $e');
      return false;
    }
  }

  /// Enable/disable auto login
  static Future<void> setAutoLoginEnabled(bool enabled) async {
    try {
      await _storage.write(key: _autoLoginEnabledKey, value: enabled.toString());
    } catch (e) {
      debugPrint('Error setting auto login enabled: $e');
    }
  }

  /// Check if auto login is enabled
  static Future<bool> isAutoLoginEnabled() async {
    try {
      final value = await _storage.read(key: _autoLoginEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error checking auto login enabled: $e');
      return false;
    }
  }

  /// Clear all saved data
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('All secure storage cleared');
    } catch (e) {
      debugPrint('Error clearing secure storage: $e');
    }
  }
}


