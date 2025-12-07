import 'dart:async';
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

class _WebViewScreenState extends State<WebViewScreen>
    with TickerProviderStateMixin {
  late final WebViewController _controller;
  // ignore: unused_field
  double _progress = 0; // Kept for potential future use with progress indicator
  bool _isError = false;
  bool _isLoading = true;
  late AnimationController _loadingAnimationController;
  late AnimationController _biometricAnimationController;
  late Animation<double> _biometricScaleAnimation;
  late Animation<double> _biometricPulseAnimation;
  String? _initialUrl;
  bool _hasCheckedForLogin = false;
  String? _capturedUsername;
  String? _capturedPassword;
  bool _showBiometricButton = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // تهيئة أنيميشن البصمة
    _biometricAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _biometricScaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _biometricAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _biometricPulseAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _biometricAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // تهيئة التحقق من البصمة
    _initBiometric();

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

  /// Initialize biometric availability check
  Future<void> _initBiometric() async {
    try {
      _isBiometricAvailable = await BiometricService.isAvailable();
      debugPrint('👆 Biometric initialized: $_isBiometricAvailable');
    } catch (e) {
      debugPrint('Error initializing biometric: $e');
      _isBiometricAvailable = false;
    }
  }

  void _initializeController() {
    _initialUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        Colors.white,
      ) // White background to prevent black screen
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

            // Check if we're on login page and show biometric button
            await _checkLoginPageAndShowBiometric(url);

            // Check if login was successful (URL changed from login page)
            await _checkForSuccessfulLogin(url);

            // Auto-fill credentials if saved in login page (without auto-submit)
            // User must press biometric button to login
            await _autoFillFromStoredCredentials(autoSubmit: false);
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
            if (_initialUrl != null &&
                request.url != _initialUrl &&
                !_hasCheckedForLogin) {
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

            // Check if we're on login page and show biometric button
            await _checkLoginPageAndShowBiometric(url);

            // محاولة ملء بيانات الدخول تلقائياً (إن وُجدت) في صفحة تسجيل الدخول
            // بدون إرسال تلقائي - المستخدم يجب أن يضغط زر البصمة
            await _autoFillFromStoredCredentials(autoSubmit: false);
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

          // Check for biometric button immediately (no delay!)
          if (mounted && currentUrl.isNotEmpty) {
            await _checkLoginPageAndShowBiometric(currentUrl);
          }

          // محاولة ملء بيانات الدخول تلقائياً بعد قليل
          // بدون إرسال تلقائي - المستخدم يجب أن يضغط زر البصمة
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await _autoFillFromStoredCredentials(autoSubmit: false);
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
    _biometricAnimationController.dispose();
    _credentialPollingTimer?.cancel();
    super.dispose();
  }

  /// Handle messages from WebView JavaScript
  void _handleWebViewMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['action'] == 'captureCredentials') {
        _capturedUsername = data['username'] as String?;
        _capturedPassword = data['password'] as String?;
        debugPrint('Credentials captured from form: $_capturedUsername');
      }
    } catch (e) {
      debugPrint('Error parsing WebView message: $e');
    }
  }

  Timer? _credentialPollingTimer;

  /// Set up form capture script to monitor form inputs
  Future<void> _setupFormCapture() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final captureScript = FormCaptureHelper.generateFormCaptureScript();
      await _controller.runJavaScript(captureScript);
      debugPrint('✅ Form capture script installed');

      // Start continuous polling
      _credentialPollingTimer?.cancel();
      _credentialPollingTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          await _extractCredentialsFromForm();

          if (_capturedUsername != null &&
              _capturedUsername!.isNotEmpty &&
              _capturedPassword != null &&
              _capturedPassword!.isNotEmpty) {
            debugPrint(
              '✅ Credentials captured via polling: $_capturedUsername',
            );
            timer.cancel(); // Stop polling once we have both
          }
        },
      );

      // Also try immediately and after delays
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _extractCredentialsFromForm();

        if (_capturedUsername != null &&
            _capturedUsername!.isNotEmpty &&
            _capturedPassword != null &&
            _capturedPassword!.isNotEmpty) {
          debugPrint('✅ Credentials captured from form: $_capturedUsername');
          _credentialPollingTimer?.cancel();
          break;
        }
      }
    } catch (e) {
      debugPrint('Error setting up form capture: $e');
    }
  }

  /// Attempt to auto-fill login form with stored credentials
  /// This method checks if credentials exist and if we're on a login page
  /// [autoSubmit] - if true, automatically submit the form after filling
  Future<void> _autoFillFromStoredCredentials({bool autoSubmit = false}) async {
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
          autoSubmit: autoSubmit, // Only submit if explicitly requested
        );

        await _controller.runJavaScript(autoFillScript);
        debugPrint('✅ Auto-fill script executed (autoSubmit: $autoSubmit)');
      }
    } catch (e) {
      debugPrint('Error auto filling credentials: $e');
    }
  }

  /// Check if login was successful by monitoring URL changes
  // Cari function ini:
  Future<void> _checkForSuccessfulLogin(String currentUrl) async {
    if (_hasCheckedForLogin) return;

    try {
      if (_initialUrl != null && currentUrl != _initialUrl) {
        await Future.delayed(const Duration(seconds: 1));
        final isLoginPage = await _isLoginPage(currentUrl);

        if (!isLoginPage) {
          _hasCheckedForLogin = true;

          if (mounted) {
            setState(() {
              _showBiometricButton = false;
            });
          }

          // --- BAGIAN INI DI-COMMENT / DIMATIKAN ---
          // Kita tidak mau auto-save lagi. Kita mau manual save via tombol.

          /* if (_capturedUsername == null || _capturedPassword == null) {
            await _extractCredentialsFromForm();
          }

          if (mounted) {
            final hasExistingCredentials = await SecureStorageService.hasSavedCredentials();
            
            if (!hasExistingCredentials) {
              if (_capturedUsername != null &&
                  _capturedUsername!.isNotEmpty &&
                  _capturedPassword != null &&
                  _capturedPassword!.isNotEmpty) {
                 // ... kode auto save lama ...
              }
            }
          } 
          */
          // -----------------------------------------
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

  /// Check if we're on login page and show biometric button
  Future<void> _checkLoginPageAndShowBiometric(String url) async {
    try {
      // Check if biometric is available on device (no delay - show immediately!)
      if (!_isBiometricAvailable) {
        _isBiometricAvailable = await BiometricService.isAvailable();
        debugPrint('👆 Biometric available on device: $_isBiometricAvailable');
      }

      // Check if we're on login page (check URL first)
      bool isLoginPageNow = url.toLowerCase().contains('login');

      debugPrint('🔍 URL: $url');
      debugPrint('🔍 URL contains login: $isLoginPageNow');

      // If URL doesn't contain 'login', check for login form
      if (!isLoginPageNow) {
        isLoginPageNow = await _isLoginPage(url);
        debugPrint('🔍 Has login form: $isLoginPageNow');
      }

      if (mounted) {
        // Always show button if biometric is available AND we're on login page
        // Even if no credentials are saved yet (will show welcome dialog)
        setState(() {
          _showBiometricButton = _isBiometricAvailable && isLoginPageNow;
        });

        debugPrint(
          '👆 Biometric button visibility: $_showBiometricButton (Available: $_isBiometricAvailable, LoginPage: $isLoginPageNow)',
        );

        // Force visibility for testing
        if (_isBiometricAvailable && isLoginPageNow) {
          debugPrint('✅ Biometric button SHOULD BE VISIBLE NOW!');
        } else {
          if (!_isBiometricAvailable) {
            debugPrint('❌ Biometric NOT available on device');
          }
          if (!isLoginPageNow) {
            debugPrint('❌ NOT on login page');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking login page for biometric: $e');
    }
  }

  /// Handle biometric authentication button press
  /// Handle biometric authentication button press
  /// Logic Baru:
  /// 1. Jika belum ada data tersimpan -> Ambil dari form & Simpan (Save Mode)
  /// 2. Jika sudah ada data tersimpan -> Autentikasi & Isi Form (Fill Mode)
  Future<void> _handleBiometricLogin() async {
    if (_isBiometricAuthenticating) return;

    setState(() {
      _isBiometricAuthenticating = true;
    });

    try {
      // 1. Cek apakah sudah ada data tersimpan di HP?
      final hasCredentials = await SecureStorageService.hasSavedCredentials();

      if (!hasCredentials) {
        // ============================================================
        // MODE SIMPAN (SAVE MODE)
        // ============================================================
        debugPrint('💾 Mode: Storing New Credentials');

        // Ambil teks yang sedang diketik user di WebView saat ini
        await _extractCredentialsFromForm();

        if (_capturedUsername != null &&
            _capturedUsername!.isNotEmpty &&
            _capturedPassword != null &&
            _capturedPassword!.isNotEmpty) {
          // Minta konfirmasi sidik jari untuk menyimpan
          final authenticated = await BiometricService.authenticate(
            reason: 'Confirm fingerprint to SAVE this password',
          );

          if (authenticated) {
            // Simpan ke Secure Storage
            await SecureStorageService.saveCredentials(
              username: _capturedUsername!,
              password: _capturedPassword!,
            );
            await SecureStorageService.setBiometricEnabled(true);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Password SAVED! Next time, just scan your finger.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );

              // Opsional: Langsung submit form setelah simpan
              await _autoFillFromStoredCredentials(autoSubmit: true);
            }
          }
        } else {
          // Jika user menekan tombol tapi form masih kosong
          debugPrint('⚠️ Form is empty, cannot save');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Enter your Username & Password first, then press this button to save.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // ============================================================
        // MODE LOGIN (FILL MODE)
        // ============================================================
        debugPrint('🔑 Mode: Login with Saved Data');

        final authenticated = await BiometricService.authenticate(
          reason: 'Scan fingerprint to LOGIN',
        );

        if (authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication Successful, Logging in...'),
                backgroundColor: Colors.green,
                duration: Duration(milliseconds: 1000),
              ),
            );
          }
          // Isi form dengan data tersimpan & auto submit
          await _autoFillFromStoredCredentials(autoSubmit: true);
        }
      }
    } catch (e) {
      debugPrint('Error during biometric process: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricAuthenticating = false;
        });
      }
    }
  }

  /// Show dialog to save credentials immediately
  /// Note: Currently not used - credentials are saved automatically
  // ignore: unused_element
  Future<void> _showSaveCredentialsDialog() async {
    if (!mounted) return;

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    // Try to get current form values first
    try {
      final currentUrl = await _controller.currentUrl();
      if (currentUrl != null && currentUrl.toLowerCase().contains('login')) {
        final result = await _controller.runJavaScriptReturningResult(
          FormCaptureHelper.generateExtractCredentialsScript(),
        );
        try {
          final resultString = result.toString();
          if (resultString.isNotEmpty) {
            final data = jsonDecode(resultString);
            if (data['hasValues'] == true) {
              usernameController.text = data['username'] ?? '';
              passwordController.text = data['password'] ?? '';
            }
          }
        } catch (e) {
          debugPrint('Error parsing form values: $e');
        }
      }
    } catch (e) {
      debugPrint('Error getting form values: $e');
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFA21955).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fingerprint,
                color: Color(0xFFA21955),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Save Credentials for Biometric Login',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your login credentials to enable biometric login:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username / Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                autofocus: usernameController.text.isEmpty,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                textCapitalization: TextCapitalization.none,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (usernameController.text.trim().isNotEmpty &&
                  passwordController.text.isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA21955),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Enable Biometric'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final username = usernameController.text.trim();
      final password = passwordController.text;

      if (username.isNotEmpty && password.isNotEmpty) {
        try {
          // Save credentials securely
          await SecureStorageService.saveCredentials(
            username: username,
            password: password,
          );

          // Verify save
          final verified = await SecureStorageService.hasSavedCredentials();
          if (!verified) {
            throw Exception('Failed to verify saved credentials');
          }

          debugPrint('✅ Credentials saved successfully from biometric dialog');

          // Auto-enable biometric if available
          final isBiometricAvailable = await BiometricService.isAvailable();
          if (isBiometricAvailable) {
            try {
              await SecureStorageService.setBiometricEnabled(true);
              debugPrint('✅ Biometric enabled automatically');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Credentials saved and biometric enabled! You can now use fingerprint login.',
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              // Auto-login with saved credentials (after saving from biometric button)
              // Don't auto-submit here - user should press biometric button
              await Future.delayed(const Duration(milliseconds: 500));
              await _autoFillFromStoredCredentials(autoSubmit: false);
            } catch (e) {
              debugPrint('⚠️ Error enabling biometric: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Credentials saved but biometric failed to enable',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Credentials saved! Biometric not available on device.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Error saving credentials: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Error: ${e.toString()}')),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }

    usernameController.dispose();
    passwordController.dispose();
  }

  /// Show welcome dialog for first-time biometric setup
  /// Currently not used, but kept for future reference
  // ignore: unused_element
  Future<void> _showBiometricWelcomeDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFA21955).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fingerprint,
                color: Color(0xFFA21955),
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Biometric Login', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Biometric Authentication! 👋',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'How it works:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA21955),
                ),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep(
                '1',
                'Login with your username and password',
              ),
              const SizedBox(height: 8),
              _buildInstructionStep('2', 'Choose to enable biometric login'),
              const SizedBox(height: 8),
              _buildInstructionStep(
                '3',
                'Next time, just use your fingerprint! 👆',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your credentials are stored securely and encrypted.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA21955),
              foregroundColor: Colors.white,
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFA21955),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  /// Show dialog to ask user if they want to enable biometric login
  /// This should be called after successful login
  /// Note: Currently biometric is enabled automatically, but this function
  /// can be used if manual confirmation is needed in the future
  // ignore: unused_element
  Future<void> _showBiometricEnableDialog(
    String username,
    String password,
  ) async {
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

      try {
        dynamic data;

        // Handle different result types
        if (result is String) {
          String resultString = result.trim();

          // Remove outer quotes if present (double-quoted JSON string)
          if (resultString.startsWith('"') && resultString.endsWith('"')) {
            resultString = resultString.substring(1, resultString.length - 1);
            // Unescape escaped quotes
            resultString = resultString.replaceAll('\\"', '"');
          }

          // Try to parse as JSON
          if (resultString.isNotEmpty &&
              resultString != 'null' &&
              resultString != 'undefined' &&
              resultString != '""') {
            data = jsonDecode(resultString);
          } else {
            return; // Empty result
          }
        } else if (result is Map) {
          data = result;
        } else {
          debugPrint('⚠️ Unexpected result type: ${result.runtimeType}');
          return;
        }

        // Process the data
        if (data is Map<String, dynamic>) {
          final username = data['username']?.toString().trim() ?? '';
          final password = data['password']?.toString() ?? '';

          if (username.isNotEmpty && password.isNotEmpty) {
            _capturedUsername = username;
            _capturedPassword = password;
            debugPrint('✅ Credentials extracted from form: $_capturedUsername');
          } else {
            debugPrint(
              '⚠️ Form incomplete: username=${username.isNotEmpty ? username : "empty"}, password=${password.isNotEmpty ? "***" : "empty"}',
            );
          }
        }
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error parsing extracted credentials: $e');
        debugPrint(
          'Raw result type: ${result.runtimeType}, value: ${result.toString()}',
        );
        debugPrint('Stack: $stackTrace');
      }
    } catch (e) {
      debugPrint('❌ Error extracting credentials: $e');
    }
  }

  /// Save captured credentials and ask about biometric
  /// Note: This function is replaced by _promptToSaveCredentialsWithData
  // ignore: unused_element
  Future<void> _saveCredentialsAndAskBiometric() async {
    if (!mounted || _capturedUsername == null || _capturedPassword == null) {
      debugPrint('⚠️ Cannot save: missing credentials');
      return;
    }

    // Validate credentials
    if (_capturedUsername!.isEmpty || _capturedPassword!.isEmpty) {
      debugPrint('⚠️ Cannot save: empty credentials');
      return;
    }

    try {
      // Save credentials securely with verification
      await SecureStorageService.saveCredentials(
        username: _capturedUsername!.trim(),
        password: _capturedPassword!,
      );

      // Verify that credentials were saved successfully
      final verification = await SecureStorageService.hasSavedCredentials();
      if (!verification) {
        throw Exception('Failed to verify saved credentials');
      }

      debugPrint('✅ Credentials saved and verified successfully');

      // Check if biometric is available
      final isBiometricAvailable = await BiometricService.isAvailable();

      if (isBiometricAvailable) {
        // Auto-enable biometric if available (no dialog - automatic)
        try {
          await SecureStorageService.setBiometricEnabled(true);
          debugPrint('✅ Biometric enabled automatically');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Credentials saved and biometric enabled!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error enabling biometric: $e');
          // Continue even if biometric enabling fails
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Credentials saved! ${e.toString()}')),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        // Biometric not available - just show save success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Credentials saved successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        debugPrint('⚠️ Biometric not available on device');
      }
    } catch (e) {
      debugPrint('❌ Error saving credentials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error saving credentials: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Show dialog to save credentials with captured data
  /// Note: Currently not used - credentials are saved automatically
  // ignore: unused_element
  Future<void> _promptToSaveCredentialsWithData(
    String username,
    String password,
  ) async {
    if (!mounted) return;

    final hasExistingCredentials =
        await SecureStorageService.hasSavedCredentials();
    if (hasExistingCredentials) return;

    final biometricAvailable = await BiometricService.isAvailable();
    if (!biometricAvailable) {
      // Biometric not available - still save credentials
      await _saveCredentialsAndEnableBiometric(username, password, false);
      return;
    }

    // Show dialog asking user to save credentials
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock, color: Color(0xFFA21955)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Save Login Credentials?',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Would you like to save your login credentials for faster access?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFA21955).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFA21955).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fingerprint,
                    color: Color(0xFFA21955),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Biometric login (Fingerprint/Face ID) will be enabled automatically!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your credentials are encrypted and stored securely.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA21955),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Save'),
          ),
        ],
      ),
    );

    if (shouldSave == true && mounted) {
      await _saveCredentialsAndEnableBiometric(username, password, true);
    }
  }

  /// Save credentials and enable biometric
  Future<void> _saveCredentialsAndEnableBiometric(
    String username,
    String password,
    bool enableBiometric,
  ) async {
    if (!mounted) return;

    // Save ScaffoldMessenger before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Save credentials securely
      await SecureStorageService.saveCredentials(
        username: username.trim(),
        password: password,
      );

      // Verify save
      final verified = await SecureStorageService.hasSavedCredentials();
      if (!verified) {
        throw Exception('Failed to verify saved credentials');
      }

      debugPrint('✅ Credentials saved successfully');

      // Auto-enable biometric if requested and available
      if (enableBiometric) {
        final isBiometricAvailable = await BiometricService.isAvailable();
        if (isBiometricAvailable) {
          try {
            await SecureStorageService.setBiometricEnabled(true);
            debugPrint('✅ Biometric enabled automatically');

            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Credentials saved and biometric login enabled! You can now use fingerprint/Face ID.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            debugPrint('⚠️ Error enabling biometric: $e');
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Credentials saved, but biometric failed to enable. You can enable it later from Settings.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Credentials saved! Biometric not available on this device.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Credentials saved successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving credentials: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error saving credentials: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Show dialog to save credentials after successful login
  /// Note: Currently not used - credentials are saved automatically
  // ignore: unused_element
  Future<void> _promptToSaveCredentials() async {
    if (!mounted) return;

    final hasExistingCredentials =
        await SecureStorageService.hasSavedCredentials();
    if (hasExistingCredentials) return;

    final biometricAvailable = await BiometricService.isAvailable();

    // Show dialog asking user to save credentials
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock, color: Color(0xFFA21955)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Save Login Credentials?',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Would you like to save your login credentials for faster access?',
              style: TextStyle(fontSize: 16),
            ),
            if (biometricAvailable) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFA21955).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFA21955).withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.fingerprint, color: Color(0xFFA21955), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Biometric login (Fingerprint/Face ID) will be enabled automatically!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your credentials are encrypted and stored securely.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA21955),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Save'),
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

    // Save ScaffoldMessenger before dialog to avoid BuildContext errors
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Login Credentials'),
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
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (usernameController.text.isNotEmpty &&
                  passwordController.text.isNotEmpty) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Dispose controllers
    usernameController.dispose();
    passwordController.dispose();

    if (result == true && mounted) {
      final username = usernameController.text.trim();
      final password = passwordController.text;

      if (username.isNotEmpty && password.isNotEmpty) {
        try {
          // Save credentials securely
          await SecureStorageService.saveCredentials(
            username: username,
            password: password,
          );

          // Verify save
          final verified = await SecureStorageService.hasSavedCredentials();
          if (!verified) {
            throw Exception('Failed to verify saved credentials');
          }

          debugPrint('✅ Credentials saved successfully from manual input');

          // Auto-enable biometric if available
          final isBiometricAvailable = await BiometricService.isAvailable();
          if (isBiometricAvailable) {
            try {
              await SecureStorageService.setBiometricEnabled(true);
              debugPrint('✅ Biometric enabled automatically');

              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Credentials saved and biometric login enabled! You can now use fingerprint/Face ID.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              debugPrint('⚠️ Error enabling biometric: $e');
              // Continue even if biometric enabling fails
            }
          } else {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Credentials saved successfully!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('❌ Error saving credentials: $e');
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Error saving: ${e.toString()}')),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  /// Handle logout - clear session and reload login page
  Future<void> _handleLogout() async {
    try {
      // Check current URL to see if user is already on login page
      final currentUrl = await _controller.currentUrl();

      if (currentUrl != null && currentUrl.toLowerCase().contains('login')) {
        // User is already on login page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already on the login page'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if login form exists on current page
      final isLoginPage = await _isLoginPage(currentUrl ?? '');
      if (isLoginPage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not logged in yet'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
    }

    // User is logged in, confirm logout
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout?\n\n'
          'Note: Saved credentials will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // Reset login check flag
        _hasCheckedForLogin = false;

        // Show loading state
        if (mounted) {
          setState(() {
            _isLoading = true;
            _isError = false;
          });
        }

        // Clear cache and cookies first
        await _controller.clearCache();
        await _controller.clearLocalStorage();

        // Reset captured credentials
        _capturedUsername = null;
        _capturedPassword = null;

        // Reset biometric button state
        if (mounted) {
          setState(() {
            _showBiometricButton = false;
          });
        }

        // Reload the login page
        await _controller.loadRequest(Uri.parse(widget.url));

        // Reset initial URL
        _initialUrl = widget.url;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Logged out successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error during logout: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isError = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error occurred during logout: ${e.toString()}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Handle clear cache - remove all cached data
  Future<void> _handleClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'Do you want to clear all cached data?\n'
          'The page will be reloaded afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // Clear cache and local storage
        await _controller.clearCache();
        await _controller.clearLocalStorage();

        // Reload the page
        await _controller.reload();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error clearing cache: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error occurred while clearing cache'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Handle settings navigation
  Future<void> _handleSettings() async {
    // Show settings dialog
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.blue),
              title: const Text('Manage Login Credentials'),
              onTap: () async {
                Navigator.pop(context);
                await _showCredentialsManagement();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint, color: Colors.green),
              title: const Text('Biometric Settings'),
              onTap: () async {
                Navigator.pop(context);
                await _showBiometricSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.grey),
              title: const Text('App Information'),
              onTap: () {
                Navigator.pop(context);
                _showAppInfo();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show credentials management dialog
  Future<void> _showCredentialsManagement() async {
    final hasCredentials = await SecureStorageService.hasSavedCredentials();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Login Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasCredentials
                  ? 'Login credentials are saved'
                  : 'No login credentials saved',
              style: TextStyle(
                color: hasCredentials ? Colors.green : Colors.grey,
              ),
            ),
            if (hasCredentials) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await SecureStorageService.deleteCredentials();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Login credentials deleted'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete Saved Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show biometric settings dialog
  Future<void> _showBiometricSettings() async {
    final isEnabled = await SecureStorageService.isBiometricEnabled();
    final isAvailable = await BiometricService.isAvailable();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Biometric Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.cancel,
                  color: isAvailable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isAvailable
                      ? 'Biometric available on device'
                      : 'Biometric not available on device',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isEnabled ? Icons.check_circle : Icons.cancel,
                  color: isEnabled ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(isEnabled ? 'Biometric enabled' : 'Biometric disabled'),
              ],
            ),
            if (isAvailable) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await SecureStorageService.setBiometricEnabled(!isEnabled);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          !isEnabled
                              ? 'Biometric enabled'
                              : 'Biometric disabled',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnabled ? Colors.orange : Colors.green,
                ),
                child: Text(
                  isEnabled ? 'Disable Biometric' : 'Enable Biometric',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show app info dialog
  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Name: Jeel ERP'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('© 2024 Jeel Engineering'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
              title: const Text('Close App?'),
              content: const Text('Are you sure you want to close the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes, Close'),
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0099A3),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 0.5,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (String value) {
                switch (value) {
                  case 'logout':
                    _handleLogout();
                    break;
                  case 'clear_cache':
                    _handleClearCache();
                    break;
                  case 'settings':
                    _handleSettings();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Logout'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'clear_cache',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Clear Cache'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ],
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
                        'Connection Failed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Failed to load page. Please check your internet connection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Reload the page
                          setState(() {
                            _isError = false;
                            _isLoading = true;
                          });
                          _controller.reload();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
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

            // Professional Floating Biometric Button with Animation
            if (_showBiometricButton && !_isLoading && !_isError)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _biometricAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _biometricScaleAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: const Color(0xFFA21955),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA21955).withOpacity(0.4),
                                spreadRadius:
                                    _biometricPulseAnimation.value / 2,
                                blurRadius: 20 + _biometricPulseAnimation.value,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isBiometricAuthenticating
                                  ? null
                                  : _handleBiometricLogin,
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: _isBiometricAuthenticating
                                    ? const SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.fingerprint,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
