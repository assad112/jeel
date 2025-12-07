import 'dart:async';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_test.dart';
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
      // Get URL and title
      _url = await SettingsService.getUrl();
      _title = await SettingsService.getTitle();

      if (!mounted) return;

      // Create WebViewController and start loading page in background
      _preloadedController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFA21955))
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
                // Complete the Completer to indicate loading is complete
                if (!_pageLoadCompleter.isCompleted) {
                  _pageLoadCompleter.complete();
                }
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('Page load error: ${error.description}');
              // Even with error, continue after timeout
              if (mounted && !_pageLoadCompleter.isCompleted) {
                _pageLoadCompleter.complete();
              }
            },
            onNavigationRequest: (NavigationRequest request) async {
              final currentUrl = Uri.parse(_url);
              final requestUrl = Uri.parse(request.url);

              // If link doesn't start with http/https, open in external browser
              if (!request.url.startsWith('http')) {
                final Uri uri = Uri.parse(request.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                return NavigationDecision.prevent;
              }

              // Prevent opening YouTube in WebView
              if (request.url.startsWith('https://www.youtube.com/')) {
                return NavigationDecision.prevent;
              }

              // Allow navigation within the same domain (erp.jeel.om)
              if (requestUrl.host == currentUrl.host ||
                  requestUrl.host.contains('jeel.om') ||
                  requestUrl.host.contains('erp.jeel.om')) {
                return NavigationDecision.navigate;
              }

              return NavigationDecision.navigate;
            },
          ),
        );

      // Start loading page in background
      _preloadedController!.loadRequest(Uri.parse(_url));

      // Start timeout as maximum wait time (10 seconds)
      _startTimeout();

      // Wait until loading completes or timeout ends
      await _waitForPageLoad();

      // Navigate after loading completes (without biometric check here)
      if (mounted && !_hasNavigated) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && !_hasNavigated) {
          _navigateToHome();
        }
      }
    } catch (e) {
      debugPrint('Error initializing preload: $e');
      // In case of error, use default values
      _url = 'https://erp.jeel.om/web/login';
      _title = 'Jeel Engineering';
      // Navigate after error
      if (mounted && !_hasNavigated) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_hasNavigated) {
          _navigateToHome();
        }
      }
    }
  }

  void _startTimeout() {
    // Maximum timeout 10 seconds
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
      // Wait for loading completion or timeout
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
            builder: (context) => LoginPage(),
            // builder: (context) => WebViewScreen(
            //   url: _url,
            //   title: _title,
            //   preloadedController: _preloadedController,
            // ),
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
              title: _title.isNotEmpty ? _title : 'Jeel Engineering',
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
            // App icon - Jeel Engineering logo
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
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
                    // If image is not found, use default icon
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFA21955).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.business,
                        size: 70,
                        color: Color(0xFFA21955),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            // App name
            const Text(
              'Jeel ERP',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA21955),
              ),
            ),
            const SizedBox(height: 20),
            // Professional loading indicator - discreteCircular
            LoadingAnimationWidget.discreteCircle(
              color: const Color(0xFFA21955),
              secondRingColor: const Color(0xFF0099A3),
              thirdRingColor: const Color(0xFFA21955),
              size: 50,
            ),
          ],
        ),
      ),
    );
  }
}
