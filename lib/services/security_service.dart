import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SecurityService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

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
      return false;
    }
  }

  static Future<bool> isDeveloperMode() async {
    try {
      return await SafeDevice.isDevelopmentModeEnable;
    } catch (e) {
      debugPrint('Error checking developer mode: $e');
      return false;
    }
  }

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

      info['isCompromised'] = await isDeviceCompromised();
      info['isDeveloperMode'] = await isDeveloperMode();

      return info;
    } catch (e) {
      debugPrint('Error getting device security info: $e');
      return {'error': e.toString()};
    }
  }

  static Future<bool> isRealDevice() async {
    try {
      return await SafeDevice.isRealDevice;
    } catch (e) {
      debugPrint('Error checking if real device: $e');
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

  static Future<SecurityCheckResult> performSecurityCheck({
    bool allowEmulator = kDebugMode,
    bool allowRootedDevices = false,
    bool allowDeveloperMode = kDebugMode,
  }) async {
    try {
      final isCompromised = await isDeviceCompromised();
      final isRealDev = await isRealDevice();
      final isDeveloper = await isDeveloperMode();

      final List<String> warnings = [];
      final List<String> errors = [];

      if (isCompromised && !allowRootedDevices) {
        errors.add('Device is jailbroken or rooted. This app cannot run on compromised devices.');
      }

      if (!isRealDev && !allowEmulator) {
        errors.add('App cannot run on emulator/simulator for security reasons.');
      }

      if (isDeveloper && !allowDeveloperMode) {
        warnings.add('Developer mode is enabled on this device.');
      }

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
        isPassed: true,
        isCompromised: false,
        isRealDevice: true,
        isDeveloperMode: false,
        errors: [],
        warnings: ['Could not perform complete security check: $e'],
      );
    }
  }

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

