import 'dart:async';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'webview_screen.dart';
import 'settings_service.dart';
import 'utils/assets_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNavigation();
    });
  }

  void _startNavigation() {
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;

    try {
      final url = await SettingsService.getUrl();
      final title = await SettingsService.getTitle();

      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);
      if (context.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => WebViewScreen(url: url, title: title),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error navigating: $e');
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (context.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const WebViewScreen(
              url: 'https://erp.jeel.om/web/login',
              title: 'جيل  للهندسة',
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة التطبيق - شعار Jeel Engineering
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 3,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  AppAssets.jeelLogo,
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // في حالة عدم وجود الصورة، استخدم الأيقونة الافتراضية
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.business,
                        size: 70,
                        color: Colors.blue.shade700,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            // اسم التطبيق
            const Text(
              'Jeel ERP',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            // مؤشر التحميل الاحترافي - discreteCircular
            LoadingAnimationWidget.discreteCircle(
              color: const Color(0xFFA21955), // لون #A21955
              secondRingColor: const Color(0xFF0099A3), // لون #0099A3
              thirdRingColor: const Color(0xFFA21955),
              size: 50,
            ),
          ],
        ),
      ),
    );
  }
}
