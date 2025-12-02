import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// خدمة إدارة الكوكيز وجلسة الدخول
class CookieService {
  static const String _sessionKey = 'user_session';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _lastLoginKey = 'last_login';

  /// حفظ حالة تسجيل الدخول
  static Future<void> saveLoginSession({
    required String sessionId,
    required String url,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, sessionId);
    await prefs.setString('session_url', url);
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
  }

  /// قراءة حالة تسجيل الدخول
  static Future<Map<String, String?>> getLoginSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_sessionKey);
    final url = prefs.getString('session_url');
    final lastLogin = prefs.getString(_lastLoginKey);
    
    return {
      'sessionId': sessionId,
      'url': url,
      'lastLogin': lastLogin,
    };
  }

  /// التحقق من حالة تسجيل الدخول
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// حفظ حالة تسجيل الدخول بعد تحميل الصفحة
  static Future<void> saveLoginState(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cookies_url', url);
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
      debugPrint('Login state saved for: $url');
    } catch (e) {
      debugPrint('Error saving login state: $e');
    }
  }

  /// مسح جميع الكوكيز وجلسة الدخول
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove('session_url');
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_lastLoginKey);
      await prefs.remove('saved_cookies');
      await prefs.remove('cookies_url');
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  /// مسح الكوكيز من WebView
  static Future<void> clearWebViewCookies(WebViewController controller) async {
    try {
      await controller.clearCache();
      await controller.clearLocalStorage();
      debugPrint('WebView cookies and cache cleared');
    } catch (e) {
      debugPrint('Error clearing WebView cookies: $e');
    }
  }

  /// الحصول على معلومات الجلسة
  static Future<Map<String, dynamic>> getSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    final lastLogin = prefs.getString(_lastLoginKey);
    
    return {
      'isLoggedIn': isLoggedIn,
      'lastLogin': lastLogin != null 
          ? DateTime.parse(lastLogin) 
          : null,
    };
  }
}

