/// ملف مساعد لإدارة الصور والأيقونات في التطبيق
/// 
/// هذا الملف يوفر طريقة منظمة للوصول إلى الصور والأيقونات
/// في جميع أنحاء التطبيق
class AppAssets {
  // المجلدات الأساسية
  static const String _imagesPath = 'assets/images';
  static const String _iconsPath = 'assets/icons';

  // ========== الصور ==========
  // شاشة البداية
  static const String splashLogo = '$_imagesPath/splash_logo.png';
  static const String splashBackground = '$_imagesPath/splash_background.png';

  // أيقونات التطبيق
  static const String appIcon = '$_imagesPath/app_icon.png';
  static const String appIconTransparent = '$_imagesPath/app_icon_transparent.png';

  // صور عامة
  static const String placeholder = '$_imagesPath/placeholder.png';
  static const String errorImage = '$_imagesPath/error_image.png';
  static const String noInternet = '$_imagesPath/no_internet.png';

  // ========== الأيقونات ==========
  // أيقونات التطبيق
  static const String iconApp = '$_iconsPath/app_icon.png';
  static const String iconAppRound = '$_iconsPath/app_icon_round.png';
  static const String jeelLogo = '$_iconsPath/JeelEngineeringicon.png'; // شعار Jeel Engineering

  // أيقونات الوظائف
  static const String iconSettings = '$_iconsPath/settings.png';
  static const String iconRefresh = '$_iconsPath/refresh.png';
  static const String iconBack = '$_iconsPath/back.png';
  static const String iconForward = '$_iconsPath/forward.png';
  static const String iconHome = '$_iconsPath/home.png';
  static const String iconMenu = '$_iconsPath/menu.png';

  // أيقونات الحالة
  static const String iconSuccess = '$_iconsPath/success.png';
  static const String iconError = '$_iconsPath/error.png';
  static const String iconWarning = '$_iconsPath/warning.png';
  static const String iconInfo = '$_iconsPath/info.png';

  /// دالة مساعدة للحصول على مسار الصورة
  /// 
  /// [imageName] اسم الصورة مع الامتداد
  /// 
  /// مثال: getImagePath('logo.png') => 'assets/images/logo.png'
  static String getImagePath(String imageName) {
    return '$_imagesPath/$imageName';
  }

  /// دالة مساعدة للحصول على مسار الأيقونة
  /// 
  /// [iconName] اسم الأيقونة مع الامتداد
  /// 
  /// مثال: getIconPath('settings.png') => 'assets/icons/settings.png'
  static String getIconPath(String iconName) {
    return '$_iconsPath/$iconName';
  }
}

/// فئة مساعدة لاستخدام الصور في التطبيق
class AppImages {
  /// تحميل صورة من assets
  /// 
  /// [path] مسار الصورة
  /// [width] عرض الصورة (اختياري)
  /// [height] ارتفاع الصورة (اختياري)
  /// [fit] طريقة ملء الصورة (اختياري)
  static String asset(String path) {
    return path;
  }
}

/// فئة مساعدة لاستخدام الأيقونات في التطبيق
class AppIcons {
  /// تحميل أيقونة من assets
  /// 
  /// [path] مسار الأيقونة
  static String asset(String path) {
    return path;
  }
}

