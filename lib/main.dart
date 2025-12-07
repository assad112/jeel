import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'widgets/bank_security_wrapper.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      home: BankSecurityWrapper(
        enableScreenshotProtection: false, // تم تعطيل حماية Screenshot
        enableJailbreakDetection: true,
        enableInactivityTimeout: true,
        inactivityTimeout: const Duration(minutes: 5),
        showSecurityWarnings: true,
        onInactivityTimeout: () {
          debugPrint('⏰ User has been inactive for 5 minutes');
        },
        onSecurityViolation: () {
          debugPrint('⚠️ Security violation detected!');
        },
        child: const SplashScreen(),
      ),
    ),
  );
}
