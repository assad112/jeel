import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _urlKey = 'webview_url';
  static const String _titleKey = 'webview_title';
  static const String _defaultUrl = 'https://erp.jeel.om/web/login';
  static const String _defaultTitle = 'Jeel ERP';

  // Save URL
  static Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
  }

  // Get URL
  static Future<String> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_urlKey) ?? _defaultUrl;
  }

  // Save Title
  static Future<void> saveTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleKey, title);
  }

  // Get Title
  static Future<String> getTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_titleKey) ?? _defaultTitle;
  }

  // Reset Settings
  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_titleKey);
  }
}
