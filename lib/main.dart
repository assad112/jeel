import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'splash_screen.dart';
import 'widgets/bank_security_wrapper.dart';
import 'utils/app_localizations.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      // Localization support - uses device language
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('ar'), // Arabic
      ],
      // Use device locale
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return supportedLocales.first; // Default to English
      },
      home: BankSecurityWrapper(
        enableScreenshotProtection: false,
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
