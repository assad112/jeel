import 'package:flutter/material.dart';

/// App Localizations - Supports Arabic and English based on device language
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Check if current locale is Arabic
  bool get isArabic => locale.languageCode == 'ar';

  /// Get text direction based on locale
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  // ============================================================
  // APP INFO
  // ============================================================
  String get appName => 'Jeel ERP';
  String get appInfo => isArabic ? 'معلومات التطبيق' : 'App Information';
  String get version => isArabic ? 'الإصدار' : 'Version';
  String get copyright => isArabic ? 'جيل للهندسة' : 'Jeel Engineering';

  // ============================================================
  // BIOMETRIC
  // ============================================================
  String get biometricSettings =>
      isArabic ? 'إعدادات البصمة' : 'Biometric Settings';
  String get biometricAvailable =>
      isArabic ? 'البصمة متوفرة على الجهاز' : 'Biometric available on device';
  String get biometricNotAvailable => isArabic
      ? 'البصمة غير متوفرة على الجهاز'
      : 'Biometric not available on device';
  String get biometricEnabled =>
      isArabic ? 'البصمة مفعّلة' : 'Biometric enabled';
  String get biometricDisabled =>
      isArabic ? 'البصمة معطّلة' : 'Biometric disabled';
  String get enableBiometric => isArabic ? 'تفعيل البصمة' : 'Enable Biometric';
  String get disableBiometric =>
      isArabic ? 'تعطيل البصمة' : 'Disable Biometric';
  String get biometricDisabledMessage => isArabic
      ? '⚠️ البصمة معطّلة. فعّلها من الإعدادات ← إعدادات البصمة'
      : '⚠️ Biometric is disabled. Enable it from Settings → Biometric Settings';
  String get fingerprintToAccess => isArabic
      ? 'استخدم بصمتك للدخول إلى التطبيق'
      : 'Use your fingerprint to access the app';
  String get fingerprintToLogin =>
      isArabic ? 'امسح بصمتك لتسجيل الدخول' : 'Scan fingerprint to LOGIN';
  String get fingerprintToSave => isArabic
      ? 'أكد بصمتك لحفظ كلمة المرور'
      : 'Confirm fingerprint to SAVE this password';

  // Biometric save prompt
  String get enableBiometricQuestion =>
      isArabic ? 'هل تريد تفعيل البصمة؟' : 'Enable Biometric Login?';
  String get enableBiometricDescription => isArabic
      ? 'هل تريد حفظ بيانات الدخول واستخدام البصمة لتسجيل الدخول بسرعة في المرات القادمة؟'
      : 'Would you like to save your credentials and use biometric (fingerprint/Face ID) for faster login next time?';
  String get yesSaveBiometric => isArabic ? 'نعم، فعّل البصمة' : 'Yes, Enable';
  String get noThanks => isArabic ? 'لا، شكراً' : 'No, Thanks';
  String get credentialsSavedWithBiometric => isArabic
      ? 'تم حفظ بيانات الدخول وتفعيل البصمة بنجاح!'
      : 'Credentials saved and biometric login enabled!';
  String get credentialsSavedWithoutBiometric => isArabic
      ? 'تم حفظ بيانات الدخول. يمكنك تفعيل البصمة لاحقاً من الإعدادات.'
      : 'Credentials saved. You can enable biometric later from Settings.';

  // ============================================================
  // LOGIN & AUTH
  // ============================================================
  String get signingIn => isArabic ? 'جاري تسجيل الدخول...' : 'Signing in...';
  String get verifyingIdentity =>
      isArabic ? 'جاري التحقق من الهوية...' : 'Verifying identity...';
  String get verificationFailed =>
      isArabic ? 'فشل التحقق من الهوية' : 'Identity verification failed';
  String get authSuccessful => isArabic
      ? 'تم التحقق بنجاح، جاري تسجيل الدخول...'
      : 'Authentication Successful, Logging in...';
  String get passwordSaved => isArabic
      ? 'تم حفظ كلمة المرور! في المرة القادمة، امسح بصمتك فقط.'
      : 'Password SAVED! Next time, just scan your finger.';
  String get enterCredentialsFirst => isArabic
      ? '⚠️ أدخل اسم المستخدم وكلمة المرور أولاً، ثم اضغط هذا الزر للحفظ.'
      : '⚠️ Enter your Username & Password first, then press this button to save.';

  // ============================================================
  // SETTINGS
  // ============================================================
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get urlSettings => isArabic ? 'إعدادات الرابط' : 'URL Settings';
  String get refreshApp => isArabic ? 'تحديث التطبيق' : 'Refresh App';
  String get securitySettings =>
      isArabic ? 'إعدادات الأمان' : 'Security Settings';
  String get deleteCredentials =>
      isArabic ? 'حذف بيانات الدخول' : 'Delete Credentials';
  String get resetApp => isArabic ? 'إعادة تعيين التطبيق' : 'Reset App';

  // ============================================================
  // COMMON
  // ============================================================
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';
  String get tryAgain => isArabic ? 'حاول مرة أخرى' : 'Try Again';
  String get error => isArabic ? 'خطأ' : 'Error';
  String get success => isArabic ? 'نجاح' : 'Success';
  String get loading => isArabic ? 'جاري التحميل...' : 'Loading...';
  String get warning => isArabic ? 'تحذير' : 'Warning';

  // ============================================================
  // RESET PASSWORD
  // ============================================================
  String get resetPassword =>
      isArabic ? 'إعادة تعيين كلمة المرور' : 'Reset Password';
  String get email => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get sendResetLink =>
      isArabic ? 'إرسال رابط إعادة التعيين' : 'Send Reset Link';
  String get backToLogin => isArabic ? 'العودة لتسجيل الدخول' : 'Back to Login';

  // ============================================================
  // MESSAGES
  // ============================================================
  String get noInternetConnection =>
      isArabic ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection';
  String get connectionError =>
      isArabic ? 'خطأ في الاتصال' : 'Connection error';
  String get sessionExpired => isArabic ? 'انتهت الجلسة' : 'Session expired';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
