import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// خدمة الأمان الشاملة للتطبيق (Bank-Level Security)
class SecurityService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// التحقق من كسر الحماية (Jailbreak/Root Detection)
  static Future<bool> isDeviceCompromised() async {
    try {
      final isJailbroken = await SafeDevice.isJailBroken;
      final isRealDevice = await SafeDevice.isRealDevice;
      
      if (isJailbroken || !isRealDevice) {
        debugPrint('⚠️ Security Alert: Device is compromised (Jailbroken/Rooted/Emulator)');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking device compromise: $e');
      // في حالة الخطأ، نفترض أن الجهاز آمن (لعدم حظر المستخدمين بشكل خاطئ)
      return false;
    }
  }

  /// التحقق من وضع التطوير (Developer Mode)
  static Future<bool> isDeveloperMode() async {
    try {
      return await SafeDevice.isDevelopmentModeEnable;
    } catch (e) {
      debugPrint('Error checking developer mode: $e');
      return false;
    }
  }

  /// الحصول على معلومات الجهاز للتحقق من الأمان
  static Future<Map<String, dynamic>> getDeviceSecurityInfo() async {
    final Map<String, dynamic> info = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info['platform'] = 'Android';
        info['version'] = androidInfo.version.release;
        info['sdk'] = androidInfo.version.sdkInt;
        info['brand'] = androidInfo.brand;
        info['model'] = androidInfo.model;
        info['isPhysicalDevice'] = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info['platform'] = 'iOS';
        info['version'] = iosInfo.systemVersion;
        info['model'] = iosInfo.model;
        info['name'] = iosInfo.name;
        info['isPhysicalDevice'] = iosInfo.isPhysicalDevice;
      }

      // التحقق من كسر الحماية
      info['isCompromised'] = await isDeviceCompromised();
      info['isDeveloperMode'] = await isDeveloperMode();

      return info;
    } catch (e) {
      debugPrint('Error getting device security info: $e');
      return {'error': e.toString()};
    }
  }

  /// التحقق من أن التطبيق يعمل على جهاز حقيقي وليس محاكي
  static Future<bool> isRealDevice() async {
    try {
      return await SafeDevice.isRealDevice;
    } catch (e) {
      debugPrint('Error checking if real device: $e');
      // في حالة الخطأ، نستخدم device_info_plus كبديل
      try {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          return androidInfo.isPhysicalDevice;
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          return iosInfo.isPhysicalDevice;
        }
      } catch (e2) {
        debugPrint('Error with fallback device check: $e2');
      }
      return true;
    }
  }

  /// فحص شامل للأمان - يرجع true إذا كان الجهاز آمناً
  static Future<SecurityCheckResult> performSecurityCheck({
    bool allowEmulator = kDebugMode, // السماح بالمحاكي في وضع التطوير فقط
    bool allowRootedDevices = false, // عدم السماح بالأجهزة المكسورة الحماية
    bool allowDeveloperMode = kDebugMode, // السماح بوضع المطور في التطوير فقط
  }) async {
    try {
      final isCompromised = await isDeviceCompromised();
      final isRealDev = await isRealDevice();
      final isDeveloper = await isDeveloperMode();

      final List<String> warnings = [];
      final List<String> errors = [];

      // التحقق من كسر الحماية
      if (isCompromised && !allowRootedDevices) {
        errors.add('Device is jailbroken or rooted. This app cannot run on compromised devices.');
      }

      // التحقق من المحاكي
      if (!isRealDev && !allowEmulator) {
        errors.add('App cannot run on emulator/simulator for security reasons.');
      }

      // التحقق من وضع المطور
      if (isDeveloper && !allowDeveloperMode) {
        warnings.add('Developer mode is enabled on this device.');
      }

      // في وضع الـ Debug، نسمح بكل شيء
      if (kDebugMode) {
        debugPrint('🔓 Debug Mode: Security checks relaxed');
      }

      final isPassed = errors.isEmpty;

      return SecurityCheckResult(
        isPassed: isPassed,
        isCompromised: isCompromised,
        isRealDevice: isRealDev,
        isDeveloperMode: isDeveloper,
        errors: errors,
        warnings: warnings,
      );
    } catch (e) {
      debugPrint('Error performing security check: $e');
      return SecurityCheckResult(
        isPassed: true, // في حالة الخطأ، نسمح بالمرور
        isCompromised: false,
        isRealDevice: true,
        isDeveloperMode: false,
        errors: [],
        warnings: ['Could not perform complete security check: $e'],
      );
    }
  }

  /// طباعة معلومات الأمان للتطبيق
  static Future<void> printSecurityInfo() async {
    debugPrint('🔒 Security Information:');
    debugPrint('═' * 50);
    
    final info = await getDeviceSecurityInfo();
    info.forEach((key, value) {
      debugPrint('  $key: $value');
    });
    
    debugPrint('═' * 50);
  }
}

/// نتيجة فحص الأمان
class SecurityCheckResult {
  final bool isPassed;
  final bool isCompromised;
  final bool isRealDevice;
  final bool isDeveloperMode;
  final List<String> errors;
  final List<String> warnings;

  SecurityCheckResult({
    required this.isPassed,
    required this.isCompromised,
    required this.isRealDevice,
    required this.isDeveloperMode,
    required this.errors,
    required this.warnings,
  });

  @override
  String toString() {
    return 'SecurityCheckResult(\n'
        '  isPassed: $isPassed\n'
        '  isCompromised: $isCompromised\n'
        '  isRealDevice: $isRealDevice\n'
        '  isDeveloperMode: $isDeveloperMode\n'
        '  errors: $errors\n'
        '  warnings: $warnings\n'
        ')';
  }
}

