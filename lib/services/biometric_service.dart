import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'dart:ui' as ui;

enum BiometricAuthStatus {
  success,
  canceled,
  unavailable,
  failed,
  error,
}

class BiometricAuthResult {
  final BiometricAuthStatus status;
  final String? errorCode;
  final String? errorMessage;

  const BiometricAuthResult({
    required this.status,
    this.errorCode,
    this.errorMessage,
  });

  bool get isSuccess => status == BiometricAuthStatus.success;
  bool get isCanceled => status == BiometricAuthStatus.canceled;
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static void _perfLog(String message) {
    if (!kDebugMode) return;
    debugPrint('⏱️ [Biometric] $message');
  }

  /// Check if device language is Arabic
  static bool get _isArabic {
    final locale = ui.PlatformDispatcher.instance.locale;
    return locale.languageCode == 'ar';
  }

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
    String reason = 'Please authenticate to access the app',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    final result = await authenticateWithResult(
      reason: reason,
      useErrorDialogs: useErrorDialogs,
      stickyAuth: stickyAuth,
    );
    return result.isSuccess;
  }

  static bool _isCancelCode(String code) {
    final normalized = code.toLowerCase();
    return normalized.contains('usercancel') ||
        normalized.contains('user_cancel') ||
        normalized.contains('usercanceled') ||
        normalized.contains('user_cancelled') ||
        normalized.contains('systemcancel') ||
        normalized.contains('system_cancel') ||
        normalized.contains('systemcanceled') ||
        normalized.contains('appcancel') ||
        normalized.contains('app_cancel') ||
        normalized.contains('auth_error.usercanceled') ||
        normalized.contains('auth_error.systemcanceled');
  }

  static BiometricAuthStatus _mapPlatformExceptionToStatus(PlatformException e) {
    if (_isCancelCode(e.code)) {
      return BiometricAuthStatus.canceled;
    }

    final normalized = e.code.toLowerCase();
    if (normalized.contains('notenrolled') ||
        normalized.contains('not_enrolled') ||
        normalized.contains('notavailable') ||
        normalized.contains('not_available') ||
        normalized.contains('passcodenotset') ||
        normalized.contains('passcode_not_set') ||
        normalized.contains('lockedout') ||
        normalized.contains('lockout') ||
        normalized.contains('permanentlylockedout') ||
        normalized.contains('permanently_locked_out')) {
      return BiometricAuthStatus.unavailable;
    }

    return BiometricAuthStatus.error;
  }

  static Future<BiometricAuthResult> authenticateWithResult({
    String reason = 'Please authenticate to access the app',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final sw = Stopwatch()..start();
      final available = await getAvailableBiometrics();
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!isDeviceSupported || available.isEmpty) {
        debugPrint('Biometric authentication not available or not enrolled');
        _perfLog('unavailable (pre-check) in ${sw.elapsedMilliseconds}ms');
        return const BiometricAuthResult(status: BiometricAuthStatus.unavailable);
      }

      // Get localized messages based on device language
      final authMessages = _isArabic
          ? const AndroidAuthMessages(
              signInTitle: 'تسجيل الدخول بالبصمة',
              biometricHint: 'تحقق من هويتك',
              biometricNotRecognized:
                  'لم يتم التعرف على البصمة. حاول مرة أخرى.',
              biometricRequiredTitle: 'البصمة مطلوبة',
              biometricSuccess: 'تم التحقق بنجاح',
              cancelButton: 'إلغاء',
              deviceCredentialsRequiredTitle: 'مطلوب بيانات الجهاز',
              deviceCredentialsSetupDescription: 'يرجى إعداد بيانات الجهاز',
              goToSettingsButton: 'الإعدادات',
              goToSettingsDescription:
                  'البصمة غير مُعدة. اذهب للإعدادات لإضافتها.',
            )
          : const AndroidAuthMessages(
              signInTitle: 'Sign in with Biometric',
              biometricHint: 'Verify your identity',
              biometricNotRecognized: 'Fingerprint not recognized. Try again.',
              biometricRequiredTitle: 'Biometric Required',
              biometricSuccess: 'Authentication successful',
              cancelButton: 'Cancel',
              deviceCredentialsRequiredTitle: 'Device credentials required',
              deviceCredentialsSetupDescription:
                  'Please set up device credentials',
              goToSettingsButton: 'Settings',
              goToSettingsDescription:
                  'Biometric not set up. Go to settings to add it.',
            );

      _perfLog('prompt start');
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        authMessages: <AuthMessages>[authMessages],
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      _perfLog('prompt end (didAuthenticate=$didAuthenticate) in ${sw.elapsedMilliseconds}ms');

      if (didAuthenticate) {
        return const BiometricAuthResult(status: BiometricAuthStatus.success);
      }

      // In practice, local_auth typically returns false when the user cancels
      // the prompt (tap cancel / back). We treat this as canceled so callers
      // can route back to login without showing an error dialog.
      return const BiometricAuthResult(status: BiometricAuthStatus.canceled);
    } on PlatformException catch (e) {
      debugPrint(
        'PlatformException during biometric auth: ${e.code} - ${e.message}',
      );
      _perfLog('PlatformException code=${e.code}');
      return BiometricAuthResult(
        status: _mapPlatformExceptionToStatus(e),
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('Error during biometric authentication: $e');
      _perfLog('error: $e');
      return BiometricAuthResult(
        status: BiometricAuthStatus.error,
        errorMessage: e.toString(),
      );
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
        return 'Face';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      default:
        return 'Unknown';
    }
  }

  static Future<String> getAvailableBiometricsString() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) return 'Not available';
    return types.map((t) => getBiometricTypeName(t)).join(', ');
  }
}
