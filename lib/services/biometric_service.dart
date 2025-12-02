import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// خدمة المصادقة الحيوية (البصمة/الوجه)
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// التحقق من توفر المصادقة الحيوية
  static Future<bool> isAvailable() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// الحصول على أنواع المصادقة المتاحة
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// المصادقة باستخدام البصمة/الوجه
  static Future<bool> authenticate({
    String reason = 'يرجى المصادقة للوصول إلى التطبيق',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) {
        debugPrint('Biometric authentication not available');
        return false;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      // معالجة أخطاء البصمة بشكل احترافي أكثر
      debugPrint('PlatformException during biometric auth: ${e.code} - ${e.message}');
      // القيم الدقيقة للأكواد تختلف بين الأنظمة؛ هنا نرجع false فقط بدون كسر التطبيق
      return false;
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return false;
    }
  }

  /// إلغاء المصادقة
  static Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      debugPrint('Error stopping authentication: $e');
    }
  }

  /// الحصول على اسم نوع المصادقة بالعربية
  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'الوجه';
      case BiometricType.fingerprint:
        return 'البصمة';
      case BiometricType.iris:
        return 'القزحية';
      case BiometricType.strong:
        return 'مصادقة قوية';
      case BiometricType.weak:
        return 'مصادقة ضعيفة';
    }
  }

  /// الحصول على جميع أنواع المصادقة المتاحة كـ String
  static Future<String> getAvailableBiometricsString() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) {
      return 'غير متوفر';
    }
    return types.map((type) => getBiometricTypeName(type)).join(', ');
  }
}

