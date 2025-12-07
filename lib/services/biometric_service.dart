import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final availableBiometrics = await _auth.getAvailableBiometrics();
      final isDeviceSupported = await _auth.isDeviceSupported();
      return availableBiometrics.isNotEmpty && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  static Future<bool> authenticate({
    String reason = 'يرجى المصادقة للوصول إلى التطبيق',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final available = await getAvailableBiometrics();
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!isDeviceSupported || available.isEmpty) {
        debugPrint('Biometric authentication not available or not enrolled');
        return false;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Masuk dengan Biometrik',
            cancelButton: 'Batal',
          ),
        ],
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint(
        'PlatformException during biometric auth: ${e.code} - ${e.message}',
      );
      // handling by code
      if (e.code == 'NotEnrolled' || e.code == 'not_enrolled') {
        // beri instruksi enrolment ke user
      } else if (e.code == 'NotAvailable' || e.code == 'not_available') {
        // not any sensor
      } else if (e.code == 'LockedOut' || e.code == 'lockout') {
        // failed lock biometric
      }
      return false;
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      return false;
    }
  }

  static Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      debugPrint('Error stopping authentication: $e');
    }
  }

  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'الوجه';
      case BiometricType.fingerprint:
        return 'البصمة';
      case BiometricType.iris:
        return 'القزحية';
      default:
        return 'غير معروف';
    }
  }

  static Future<String> getAvailableBiometricsString() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) return 'غير متوفر';
    return types.map((t) => getBiometricTypeName(t)).join(', ');
  }
}
