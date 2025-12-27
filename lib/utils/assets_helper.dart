class AppAssets {
  static const String _imagesPath = 'assets/images';
  static const String _iconsPath = 'assets/icons';

  static const String splashLogo = '$_imagesPath/splash_logo.png';
  static const String splashBackground = '$_imagesPath/splash_background.png';

  static const String appIcon = '$_imagesPath/app_icon.png';
  static const String appIconTransparent = '$_imagesPath/app_icon_transparent.png';

  static const String placeholder = '$_imagesPath/placeholder.png';
  static const String errorImage = '$_imagesPath/error_image.png';
  static const String noInternet = '$_imagesPath/no_internet.png';

  static const String iconApp = '$_iconsPath/app_icon.png';
  static const String iconAppRound = '$_iconsPath/app_icon_round.png';
  static const String jeelLogo = '$_iconsPath/JeelEngineeringicon.png';

  static const String iconSettings = '$_iconsPath/settings.png';
  static const String iconRefresh = '$_iconsPath/refresh.png';
  static const String iconBack = '$_iconsPath/back.png';
  static const String iconForward = '$_iconsPath/forward.png';
  static const String iconHome = '$_iconsPath/home.png';
  static const String iconMenu = '$_iconsPath/menu.png';

  static const String iconSuccess = '$_iconsPath/success.png';
  static const String iconError = '$_iconsPath/error.png';
  static const String iconWarning = '$_iconsPath/warning.png';
  static const String iconInfo = '$_iconsPath/info.png';

  static String getImagePath(String imageName) {
    return '$_imagesPath/$imageName';
  }

  static String getIconPath(String iconName) {
    return '$_iconsPath/$iconName';
  }
}

class AppImages {
  static String asset(String path) {
    return path;
  }
}

class AppIcons {
  static String asset(String path) {
    return path;
  }
}

