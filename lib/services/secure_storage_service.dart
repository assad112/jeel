import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خدمة حفظ المعلومات بشكل آمن (معلومات الدخول)
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // مفاتيح التخزين
  static const String _usernameKey = 'saved_username';
  static const String _passwordKey = 'saved_password';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _autoLoginEnabledKey = 'auto_login_enabled';

  /// حفظ معلومات الدخول
  static Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    try {
      await _storage.write(key: _usernameKey, value: username);
      await _storage.write(key: _passwordKey, value: password);
      debugPrint('Credentials saved securely');
    } catch (e) {
      debugPrint('Error saving credentials: $e');
      rethrow;
    }
  }

  /// قراءة معلومات الدخول
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

  /// التحقق من وجود معلومات دخول محفوظة
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

  /// حذف معلومات الدخول
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

  /// تفعيل/تعطيل المصادقة الحيوية
  static Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
    } catch (e) {
      debugPrint('Error setting biometric enabled: $e');
    }
  }

  /// التحقق من تفعيل المصادقة الحيوية
  static Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error checking biometric enabled: $e');
      return false;
    }
  }

  /// تفعيل/تعطيل تسجيل الدخول التلقائي
  static Future<void> setAutoLoginEnabled(bool enabled) async {
    try {
      await _storage.write(key: _autoLoginEnabledKey, value: enabled.toString());
    } catch (e) {
      debugPrint('Error setting auto login enabled: $e');
    }
  }

  /// التحقق من تفعيل تسجيل الدخول التلقائي
  static Future<bool> isAutoLoginEnabled() async {
    try {
      final value = await _storage.read(key: _autoLoginEnabledKey);
      return value == 'true';
    } catch (e) {
      debugPrint('Error checking auto login enabled: $e');
      return false;
    }
  }

  /// مسح جميع البيانات المحفوظة
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('All secure storage cleared');
    } catch (e) {
      debugPrint('Error clearing secure storage: $e');
    }
  }
}


