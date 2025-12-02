import 'dart:async';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'webview_screen.dart';
import 'settings_service.dart';
import 'utils/assets_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timeoutTimer;
  WebViewController? _preloadedController;
  String _url = '';
  String _title = '';
  bool _isPageLoaded = false;
  bool _hasNavigated = false;
  final Completer<void> _pageLoadCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndPreload();
    });
  }

  Future<void> _initializeAndPreload() async {
    try {
      // الحصول على URL والعنوان
      _url = await SettingsService.getUrl();
      _title = await SettingsService.getTitle();

      if (!mounted) return;

      // إنشاء WebViewController وبدء تحميل الصفحة في الخلفية
      _preloadedController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('Page loading started: $url');
              if (mounted) {
                setState(() {
                  _isPageLoaded = false;
                });
              }
            },
            onPageFinished: (String url) async {
              debugPrint('Page loaded successfully: $url');
              if (mounted && !_isPageLoaded) {
                setState(() {
                  _isPageLoaded = true;
                });
                // حل الـ Completer للإشارة إلى اكتمال التحميل
                if (!_pageLoadCompleter.isCompleted) {
                  _pageLoadCompleter.complete();
                }
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('Page load error: ${error.description}');
              // حتى مع وجود خطأ، انتقل بعد timeout
              if (mounted && !_pageLoadCompleter.isCompleted) {
                _pageLoadCompleter.complete();
              }
            },
            onNavigationRequest: (NavigationRequest request) async {
              final currentUrl = Uri.parse(_url);
              final requestUrl = Uri.parse(request.url);
              
              // إذا كان الرابط لا يبدأ بـ http/https، افتحه في متصفح خارجي
              if (!request.url.startsWith('http')) {
                final Uri uri = Uri.parse(request.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                return NavigationDecision.prevent;
              }

              // منع فتح YouTube في WebView
              if (request.url.startsWith('https://www.youtube.com/')) {
                return NavigationDecision.prevent;
              }

              // السماح بالتنقل داخل نفس النطاق (erp.jeel.om)
              if (requestUrl.host == currentUrl.host || 
                  requestUrl.host.contains('jeel.om') ||
                  requestUrl.host.contains('erp.jeel.om')) {
                return NavigationDecision.navigate;
              }

              return NavigationDecision.navigate;
            },
          ),
        );

      // بدء تحميل الصفحة في الخلفية
      _preloadedController!.loadRequest(Uri.parse(_url));

      // بدء timeout كحد أقصى للانتظار (10 ثوانٍ)
      _startTimeout();
      
      // الانتظار حتى اكتمال التحميل أو انتهاء timeout
      await _waitForPageLoad();
      
      // الانتقال بعد اكتمال التحميل أو timeout
      if (mounted && !_hasNavigated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && !_hasNavigated) {
          _navigateToHome();
        }
      }
      
    } catch (e) {
      debugPrint('Error initializing preload: $e');
      // في حالة الخطأ، استخدم القيم الافتراضية
      _url = 'https://erp.jeel.om/web/login';
      _title = 'جيل  للهندسة';
      // الانتقال بعد خطأ
      if (mounted && !_hasNavigated) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_hasNavigated) {
          _navigateToHome();
        }
      }
    }
  }

  void _startTimeout() {
    // timeout كحد أقصى 10 ثوانٍ
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      debugPrint('Page load timeout - completing anyway');
      if (mounted && !_hasNavigated) {
        if (!_pageLoadCompleter.isCompleted) {
          _pageLoadCompleter.complete();
        }
      }
    });
  }

  Future<void> _waitForPageLoad() async {
    try {
      // انتظر اكتمال التحميل أو timeout
      await _pageLoadCompleter.future;
    } catch (e) {
      debugPrint('Error waiting for page load: $e');
    }
  }

  Future<void> _navigateToHome() async {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    _timeoutTimer?.cancel();

    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (context.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              url: _url,
              title: _title,
              preloadedController: _preloadedController,
            ),
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
            builder: (context) => WebViewScreen(
              url: _url.isNotEmpty ? _url : 'https://erp.jeel.om/web/login',
              title: _title.isNotEmpty ? _title : 'جيل  للهندسة',
              preloadedController: _preloadedController,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
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

