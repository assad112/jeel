import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/secure_storage_service.dart';
import 'services/biometric_service.dart';
import 'widgets/professional_loader.dart';
import 'utils/javascript_helpers.dart';
import 'utils/form_capture_helper.dart';

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
  // ignore: unused_field
  double _progress = 0; // Kept for potential future use with progress indicator
  bool _isError = false;
  bool _isLoading = true;
  late AnimationController _loadingAnimationController;
  String? _initialUrl;
  bool _hasCheckedForLogin = false;
  String? _capturedUsername;
  String? _capturedPassword;

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
    _initialUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleWebViewMessage(message.message);
        },
      )
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
            
            // Set up form capture to monitor form inputs
            await _setupFormCapture();
            
            // Check if login was successful (URL changed from login page)
            await _checkForSuccessfulLogin(url);
            
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
            // Check if navigation indicates successful login
            if (_initialUrl != null && request.url != _initialUrl && !_hasCheckedForLogin) {
              // URL changed, might be successful login
              // Delay check to allow page to load
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  _checkForSuccessfulLogin(request.url);
                }
              });
            }

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

  /// Handle messages from WebView JavaScript
  void _handleWebViewMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['action'] == 'captureCredentials') {
        _capturedUsername = data['username'] as String?;
        _capturedPassword = data['password'] as String?;
        debugPrint('Credentials captured from form: ${_capturedUsername}');
      }
    } catch (e) {
      debugPrint('Error parsing WebView message: $e');
    }
  }

  /// Set up form capture script to monitor form inputs
  Future<void> _setupFormCapture() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final captureScript = FormCaptureHelper.generateFormCaptureScript();
      await _controller.runJavaScript(captureScript);
      debugPrint('Form capture script installed');
    } catch (e) {
      debugPrint('Error setting up form capture: $e');
    }
  }

  /// Attempt to auto-fill login form with stored credentials
  /// This method checks if credentials exist and if we're on a login page
  Future<void> _autoFillFromStoredCredentials() async {
    final hasCredentials = await SecureStorageService.hasSavedCredentials();
    if (!hasCredentials) return;

    final credentials = await SecureStorageService.getCredentials();
    final username = credentials['username'];
    final password = credentials['password'];

    if (username == null || password == null) return;

    try {
      // Wait a bit for the page to fully load
      await Future.delayed(const Duration(milliseconds: 800));

      // Check if we're on a login page
      final currentUrl = await _controller.currentUrl();
      if (currentUrl == null) return;

      // Check if login form exists on the page
      final hasLoginForm = await _controller.runJavaScriptReturningResult(
        JavaScriptHelpers.generateCheckLoginFormScript(),
      );

      if (hasLoginForm == true || hasLoginForm == 'true') {
        // Generate and execute auto-fill script
        final autoFillScript = JavaScriptHelpers.generateAutoFillScript(
          username: username,
          password: password,
          autoSubmit: true, // Auto-submit form after filling
        );

        await _controller.runJavaScript(autoFillScript);
        debugPrint('Auto-fill script executed successfully');
      }
    } catch (e) {
      debugPrint('Error auto filling credentials: $e');
    }
  }

  /// Check if login was successful by monitoring URL changes
  Future<void> _checkForSuccessfulLogin(String currentUrl) async {
    if (_hasCheckedForLogin) return;
    
    try {
      // If URL changed from login page, user might have logged in successfully
      if (_initialUrl != null && currentUrl != _initialUrl) {
        // Wait a bit for page to fully load
        await Future.delayed(const Duration(seconds: 1));
        
        // Check if we're no longer on login page
        final isLoginPage = await _isLoginPage(currentUrl);
        
        if (!isLoginPage) {
          // User successfully logged in
          _hasCheckedForLogin = true;
          
          // Try to extract credentials if not already captured
          if (_capturedUsername == null || _capturedPassword == null) {
            await _extractCredentialsFromForm();
          }
          
          // Save captured credentials and ask about biometric
          if (mounted && _capturedUsername != null && _capturedPassword != null) {
            await _saveCredentialsAndAskBiometric();
          } else if (mounted) {
            // If credentials not captured, ask user to enter manually
            await _promptToSaveCredentials();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for successful login: $e');
    }
  }

  /// Check if current page is a login page
  Future<bool> _isLoginPage(String url) async {
    try {
      final hasLoginForm = await _controller.runJavaScriptReturningResult(
        JavaScriptHelpers.generateCheckLoginFormScript(),
      );
      return hasLoginForm == true || hasLoginForm == 'true';
    } catch (e) {
      debugPrint('Error checking if login page: $e');
      // If URL contains 'login', assume it's login page
      return url.toLowerCase().contains('login');
    }
  }


  /// Show dialog to ask user if they want to enable biometric login
  /// This should be called after successful login
  Future<void> _showBiometricEnableDialog(String username, String password) async {
    // Check if biometric is already enabled
    final isBiometricEnabled = await SecureStorageService.isBiometricEnabled();
    if (isBiometricEnabled) return;

    // Check if biometric is available
    final isBiometricAvailable = await BiometricService.isAvailable();
    if (!isBiometricAvailable) return;

    // Check if we have saved credentials
    final hasCredentials = await SecureStorageService.hasSavedCredentials();
    if (!hasCredentials) return;

    if (!mounted) return;

    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: const Text(
          'Would you like to enable biometric authentication (fingerprint/Face ID) for faster login next time?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (shouldEnable == true) {
      await SecureStorageService.setBiometricEnabled(true);
      debugPrint('Biometric login enabled');
    }
  }

  /// Extract credentials from form after successful login
  Future<void> _extractCredentialsFromForm() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        FormCaptureHelper.generateExtractCredentialsScript(),
      );
      
      if (result != null) {
        try {
          final resultString = result.toString();
          if (resultString.isNotEmpty) {
            final data = jsonDecode(resultString);
            if (data['hasValues'] == true) {
              _capturedUsername = data['username'] as String?;
              _capturedPassword = data['password'] as String?;
              debugPrint('Credentials extracted from form');
            }
          }
        } catch (e) {
          debugPrint('Error parsing extracted credentials: $e');
        }
      }
    } catch (e) {
      debugPrint('Error extracting credentials: $e');
    }
  }

  /// Save captured credentials and ask about biometric
  Future<void> _saveCredentialsAndAskBiometric() async {
    if (!mounted || _capturedUsername == null || _capturedPassword == null) return;

    // Check if credentials already exist
    final hasExistingCredentials = await SecureStorageService.hasSavedCredentials();
    if (hasExistingCredentials) return;

    try {
      // Save credentials securely
      await SecureStorageService.saveCredentials(
        username: _capturedUsername!,
        password: _capturedPassword!,
      );

      debugPrint('Credentials saved successfully');

      // Ask about biometric
      if (mounted) {
        await _showBiometricEnableDialog(_capturedUsername!, _capturedPassword!);
      }
    } catch (e) {
      debugPrint('Error saving credentials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في حفظ البيانات. يرجى المحاولة مرة أخرى.'),
          ),
        );
      }
    }
  }

  /// Show dialog to save credentials after successful login
  Future<void> _promptToSaveCredentials() async {
    if (!mounted) return;

    final hasExistingCredentials = await SecureStorageService.hasSavedCredentials();
    if (hasExistingCredentials) return;

    final biometricAvailable = await BiometricService.isAvailable();
    if (!biometricAvailable) return;

    // Show dialog asking user to manually enter credentials to save
    // This is a workaround since extracting from form after submission is difficult
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('حفظ بيانات تسجيل الدخول؟'),
        content: const Text(
          'هل تريد حفظ بيانات تسجيل الدخول لاستخدامها في المرة القادمة؟\n\n'
          'يمكنك تفعيل تسجيل الدخول بالبصمة / Face ID أيضاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لا، شكراً'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، حفظ'),
          ),
        ],
      ),
    );

    if (shouldSave == true && mounted) {
      // Show input dialog to get credentials
      await _showCredentialInputDialog();
    }
  }

  /// Show dialog to input credentials manually
  Future<void> _showCredentialInputDialog() async {
    if (!mounted) return;

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('إدخال بيانات تسجيل الدخول'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username / Email',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (usernameController.text.isNotEmpty && 
                  passwordController.text.isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final username = usernameController.text.trim();
      final password = passwordController.text;

      if (username.isNotEmpty && password.isNotEmpty) {
        // Save credentials
        await SecureStorageService.saveCredentials(
          username: username,
          password: password,
        );

        // Ask about biometric
        await _showBiometricEnableDialog(username, password);
      }
    }

    usernameController.dispose();
    passwordController.dispose();
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
