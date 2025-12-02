import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/secure_storage_service.dart';
import 'widgets/professional_loader.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final WebViewController? preloadedController;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.preloadedController,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  double _progress = 0;
  bool _isError = false;
  bool _isLoading = true;
  late AnimationController _loadingAnimationController;

  @override
  void initState() {
    super.initState();
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // استخدام الـ controller المحمل مسبقاً إذا كان متاحاً، وإلا إنشاء واحد جديد
    if (widget.preloadedController != null) {
      _controller = widget.preloadedController!;
      // افترض أن الصفحة محملة بالفعل عند استخدام preloaded controller
      _isLoading = false;
      // إضافة navigation delegate للتحديثات إذا لم يكن موجوداً
      _attachNavigationDelegate();
      // إذا كان محمل مسبقاً، تحقق من حالة التحميل بسرعة
      _checkPreloadedPageStatus();
    } else {
      _initializeController();
    }
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _isError = false;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
              _progress = 0;
            });
            
            // محاولة ملء بيانات الدخول تلقائياً (إن وُجدت) في صفحة تسجيل الدخول
            await _autoFillFromStoredCredentials();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              'Error code: ${error.errorCode}, Desc: ${error.description}',
            );

            setState(() {
              _isError = true;
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) async {
            // السماح بالتنقل داخل نفس الموقع فقط
            final currentUrl = Uri.parse(widget.url);
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

            // السماح بالتنقل داخل نفس الموقع
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // إرفاق navigation delegate للـ controller المحمل مسبقاً
  void _attachNavigationDelegate() {
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) {
            setState(() {
              _progress = progress / 100;
            });
          }
        },
        onPageStarted: (String url) {
          if (mounted) {
            setState(() {
              _isLoading = true;
              _isError = false;
            });
          }
        },
        onPageFinished: (String url) async {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _progress = 0;
            });
            
            // محاولة ملء بيانات الدخول تلقائياً (إن وُجدت) في صفحة تسجيل الدخول
            await _autoFillFromStoredCredentials();
          }
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint(
            'Error code: ${error.errorCode}, Desc: ${error.description}',
          );

          if (mounted) {
            setState(() {
              _isError = true;
              _isLoading = false;
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) async {
          // السماح بالتنقل داخل نفس الموقع فقط
          final currentUrl = Uri.parse(widget.url);
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

          // السماح بالتنقل داخل نفس الموقع
          return NavigationDecision.navigate;
        },
      ),
    );
  }

  // التحقق من حالة الصفحة المحملة مسبقاً
  Future<void> _checkPreloadedPageStatus() async {
    if (!mounted) return;
    
    // التحقق فوراً من أن الصفحة تم تحميلها بالفعل
    try {
      final currentUrl = await _controller.currentUrl();
      if (currentUrl != null && currentUrl.isNotEmpty) {
        // الصفحة محملة بالفعل، لا حاجة لإظهار loader
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isError = false;
            _progress = 1.0;
          });
          
          // محاولة ملء بيانات الدخول تلقائياً بعد قليل
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await _autoFillFromStoredCredentials();
          }
        }
      } else {
        // الصفحة لم تكتمل بعد، أظهر loader
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking preloaded page status: $e');
      // في حالة الخطأ، افترض أن الصفحة تحتاج تحميل
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }

  /// محاولة ملء نموذج تسجيل الدخول من البيانات المحفوظة في الهاتف
  Future<void> _autoFillFromStoredCredentials() async {
    final hasCredentials = await SecureStorageService.hasSavedCredentials();
    if (!hasCredentials) return;

    final credentials = await SecureStorageService.getCredentials();
    final username = credentials['username'];
    final password = credentials['password'];

    if (username == null || password == null) return;

    try {
      await _controller.runJavaScript('''
        (function() {
          var usernameInput = document.querySelector('input[type="email"], input[name="login"], input[id*="login"], input[placeholder*="email" i], input[placeholder*="username" i]');
          var passwordInput = document.querySelector('input[type="password"]');
          
          if (usernameInput) {
            usernameInput.value = '$username';
            usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
          }
          
          if (passwordInput) {
            passwordInput.value = '$password';
            passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
          }
        })();
      ''');
    } catch (e) {
      debugPrint('Error auto filling credentials: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final navigator = Navigator.of(context);
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('إغلاق التطبيق؟'),
              content: const Text('هل أنت متأكد من إغلاق التطبيق؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('نعم، إغلاق'),
                ),
              ],
            ),
          );

          if (shouldExit == true) {
            navigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 0.5,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: Stack(
          children: [
            if (!_isError) WebViewWidget(controller: _controller),

            if (_isError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'فشل الاتصال',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'فشل تحميل الصفحة. يرجى التحقق من اتصال الإنترنت.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () {
                          // محاولة إعادة التحميل
                          setState(() {
                            _isError = false;
                            _isLoading = true;
                          });
                          _controller.reload();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('حاول مرة أخرى'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isLoading && !_isError)
              ProfessionalLoader(
                rotationController: _loadingAnimationController,
              ),
          ],
        ),
      ),
    );
  }
}
