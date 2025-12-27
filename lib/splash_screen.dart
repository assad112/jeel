import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_test.dart';
import 'webview_screen.dart';
import 'settings_service.dart';
import 'utils/assets_helper.dart';
import 'services/secure_storage_service.dart';
import 'services/biometric_service.dart';
import 'utils/javascript_helpers.dart';

class SplashScreen extends StatefulWidget {
  final bool skipBiometric;

  const SplashScreen({super.key, this.skipBiometric = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  Timer? _timeoutTimer;
  WebViewController? _preloadedController;
  String _url = '';
  String _title = '';
  bool _hasNavigated = false;
  String _statusMessage = 'Loading...';

  // Control auto-login process
  bool _isAutoLoginInProgress = false;
  bool _loginSuccessful = false;
  bool _hasAttemptedLogin = false; // Track if login was attempted
  Completer<void>? _loginCompleter;
  bool _isReadyForBiometric = false;

  // Debug-only perf tracing (no UX changes)
  final Stopwatch _perf = Stopwatch();
  int _perfStep = 0;

  void _perfMark(String label) {
    if (!kDebugMode) return;
    if (!_perf.isRunning) _perf.start();
    _perfStep += 1;
    debugPrint('⏱️ [SplashLogin ${_perfStep.toString().padLeft(2, '0')}] '
        '${_perf.elapsedMilliseconds}ms - $label');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start immediately after first frame to reduce perceived latency.
      if (mounted) {
        _perfMark('First frame -> initialize');
        _isReadyForBiometric = true;
        _initializeAndPreload();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 App state changed: $state');
  }

  Future<void> _initializeAndPreload() async {
    try {
      _perfMark('Initialize: load settings');
      // Get URL and Title
      _url = await SettingsService.getUrl();
      _title = await SettingsService.getTitle();

      if (_url.isEmpty) {
        _url = 'https://erp.jeel.om/web/login';
      }
      if (_title.isEmpty) {
        _title = 'Jeel ERP';
      }

      if (!mounted) return;

      _perfMark('Initialize: check saved credentials');

      // Check for saved credentials
      final hasCredentials = await SecureStorageService.hasSavedCredentials();

      if (hasCredentials) {
        // Check if we should skip biometric (first login)
        if (widget.skipBiometric) {
          // Skip biometric on first login - go directly to auto-login
          debugPrint('✅ First login - skipping biometric verification');
          _updateStatus('Signing in...');
          _perfMark('Skip biometric -> auto-login');
          await _performAutoLoginInBackground();
          return;
        }

        // Saved credentials exist - check if biometric is enabled
        final isBiometricEnabled =
            await SecureStorageService.isBiometricEnabled();

        if (!isBiometricEnabled) {
          // Biometric disabled by user - login directly without biometric
          debugPrint('⚠️ Biometric disabled by user - direct login');
          _updateStatus('Signing in...');
          _perfMark('Biometric disabled -> auto-login');
          await _performAutoLoginInBackground();
          return;
        }

        // Biometric is enabled - request verification
        debugPrint(
          '✅ Saved credentials found - requesting biometric verification',
        );
        _updateStatus('Verifying identity...');

        _perfMark('Biometric: availability check');
        if (!mounted) return;

        // Check biometric availability
        final isBiometricAvailable = await BiometricService.isAvailable();

        if (isBiometricAvailable) {
          // Request biometric verification
          _perfMark('Biometric: prompt start');
          final authResult = await BiometricService.authenticateWithResult(
            reason: 'Use your fingerprint to access the app',
          );

          _perfMark(
            'Biometric: prompt end (status=${authResult.status.name})',
          );

          if (!mounted) return;

          if (authResult.isSuccess) {
            // Biometric verified - start auto-login
            debugPrint('✅ Biometric verification successful');
            _updateStatus('Signing in...');
            _perfMark('Biometric success -> auto-login');
            await _performAutoLoginInBackground();
          } else {
            if (authResult.isCanceled) {
              // User tapped cancel/back on the biometric prompt.
              // Expected UX: return to login page (no failure dialog).
              debugPrint('⚠️ Biometric prompt canceled - navigating to login');
              _perfMark('Biometric canceled -> login');
              _navigateToLoginPage();
              return;
            }

            // Biometric failed - do not login
            debugPrint(
              '❌ Biometric verification failed: ${authResult.errorCode ?? 'unknown'}',
            );
            _updateStatus('Identity verification failed');
            await Future.delayed(const Duration(milliseconds: 300));
            // Show message and request biometric again
            if (mounted) {
              _perfMark('Biometric failed -> show dialog');
              _showBiometricFailedDialog();
            }
          }
        } else {
          // Biometric not available - login directly
          debugPrint('⚠️ Biometric not available - direct login');
          _updateStatus('Signing in...');
          _perfMark('Biometric unavailable -> auto-login');
          await _performAutoLoginInBackground();
        }
      } else {
        // No saved credentials - navigate to login page
        debugPrint('❌ No saved credentials - navigating to login page');
        _updateStatus('Loading...');
        _perfMark('No credentials -> login');
        _navigateToLoginPage();
      }
    } catch (e) {
      debugPrint('Error initializing: $e');
      _perfMark('Initialize error -> login');
      _navigateToLoginPage();
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }

  /// Perform auto-login in background
  Future<void> _performAutoLoginInBackground() async {
    if (_isAutoLoginInProgress) return;
    _isAutoLoginInProgress = true;
    _loginCompleter = Completer<void>();

    try {
      _perfMark('Auto-login: read credentials');
      // Read saved credentials
      final credentials = await SecureStorageService.getCredentials();
      final username = credentials['username'];
      final password = credentials['password'];

      if (username == null ||
          password == null ||
          username.isEmpty ||
          password.isEmpty) {
        debugPrint('❌ Saved credentials are empty');
        _navigateToLoginPage();
        return;
      }

      debugPrint('✅ Credentials: $username');
      _updateStatus('Loading page...');

      _perfMark('Auto-login: create WebViewController');

      // Create WebViewController and load page
      _preloadedController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFA21955))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('📄 Loading started: $url');
              _perfMark('WebView: onPageStarted');
            },
            onPageFinished: (String url) async {
              debugPrint('✅ Page loaded: $url');
              _perfMark('WebView: onPageFinished');

              // Check if login was successful (URL changed from login)
              if (_isAutoLoginInProgress &&
                  !url.toLowerCase().contains('login')) {
                // Login successful!
                debugPrint('🎉 Login successful! URL: $url');
                _perfMark('Auto-login: detected success redirect');
                _loginSuccessful = true;
                if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
                  _loginCompleter!.complete();
                }
                return;
              }

              // If we're on the login page
              if (url.toLowerCase().contains('login')) {
                // If we already tried to login and returned to login page = failed
                if (_hasAttemptedLogin) {
                  debugPrint('❌ Login failed - Invalid credentials');
                  _updateStatus('Login failed - Check your credentials');

                  // Delete saved credentials because they're wrong
                  await SecureStorageService.deleteCredentials();

                  // Wait a moment then navigate to login page
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (_loginCompleter != null &&
                      !_loginCompleter!.isCompleted) {
                    _loginCompleter!.complete();
                  }
                  _navigateToLoginPage(errorCode: 'invalid_credentials');
                  return;
                }

                _updateStatus('Filling credentials...');
                await Future.delayed(const Duration(milliseconds: 150));

                _perfMark('Auto-login: inject credentials JS');

                // Auto-fill credentials
                final autoFillScript = JavaScriptHelpers.generateAutoFillScript(
                  username: username,
                  password: password,
                  autoSubmit: true,
                );

                await _preloadedController!.runJavaScript(autoFillScript);
                _hasAttemptedLogin = true; // Login attempt made
                debugPrint('✅ Credentials filled and login button clicked');
                _updateStatus('Signing in...');
                _perfMark('Auto-login: JS injected (submit triggered)');
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ Page loading error: ${error.description}');
              _perfMark('WebView error: ${error.errorCode}');
            },
            onNavigationRequest: (NavigationRequest request) async {
              // Allow navigation within the same domain
              if (request.url.contains('jeel.om')) {
                return NavigationDecision.navigate;
              }

              // Open external links in browser
              if (!request.url.startsWith('http')) {
                final Uri uri = Uri.parse(request.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            },
          ),
        );

      // Start loading login page
      _perfMark('Auto-login: loadRequest start');
      await _preloadedController!.loadRequest(Uri.parse(_url));
      _perfMark('Auto-login: loadRequest issued');

      // Start timeout timer (30 seconds max)
      _startLoginTimeout();

      // Wait for login completion
      _perfMark('Auto-login: waiting for completion');
      await _loginCompleter!.future;
      _perfMark('Auto-login: completion signaled');

      // Check the result
      if (_loginSuccessful && mounted && !_hasNavigated) {
        _updateStatus('Login successful!');
        _perfMark('Navigate: WebViewScreen');
        await _navigateToWebView();
      }
    } catch (e) {
      debugPrint('❌ Auto-login error: $e');
      _perfMark('Auto-login error -> login');
      _navigateToLoginPage();
    }
  }

  void _startLoginTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('⏰ Timeout reached');
      if (!_loginSuccessful && mounted && !_hasNavigated) {
        // Timeout without success - navigate to manual login page
        _updateStatus('Auto-login failed...');
        if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
          _loginCompleter!.complete();
        }
        // Navigate to login page for manual attempt
        _navigateToLoginPage();
      }
    });
  }

  void _navigateToLoginPage({String? errorCode}) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _timeoutTimer?.cancel();

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginPage(initialErrorCode: errorCode),
      ),
      (route) => false,
    );
  }

  Future<void> _navigateToWebView() async {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _timeoutTimer?.cancel();

    // Use the actual current URL (post-login) to reduce any chance of
    // initializing the WebView screen with /web/login.
    String finalUrl = _url;
    try {
      final current = await _preloadedController?.currentUrl();
      if (current != null && current.isNotEmpty) {
        finalUrl = current;
      }
    } catch (_) {
      // Ignore and keep default.
    }

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          url: finalUrl,
          title: _title,
          preloadedController: _preloadedController,
        ),
      ),
      (route) => false,
    );
  }

  /// Show dialog when biometric verification fails
  void _showBiometricFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verification Failed'),
        content: const Text(
          'Your identity could not be verified.\nWould you like to try again?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Close the app
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            },
            child: const Text('Close App'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Retry biometric verification
              _retryBiometricAuth();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0099A3),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Retry biometric verification
  Future<void> _retryBiometricAuth() async {
    // Check if biometric is still enabled
    final isBiometricEnabled = await SecureStorageService.isBiometricEnabled();

    if (!isBiometricEnabled) {
      // Biometric was disabled - login directly
      debugPrint('⚠️ Biometric disabled - direct login');
      _updateStatus('Signing in...');
      await _performAutoLoginInBackground();
      return;
    }

    _updateStatus('Verifying identity...');

    final authResult = await BiometricService.authenticateWithResult(
      reason: 'Use your fingerprint to access the app',
    );

    if (authResult.isSuccess) {
      debugPrint('✅ Biometric verification successful');
      _updateStatus('Signing in...');
      await _performAutoLoginInBackground();
    } else {
      if (authResult.isCanceled) {
        debugPrint('⚠️ Biometric prompt canceled - navigating to login');
        _navigateToLoginPage();
        return;
      }

      debugPrint(
        '❌ Biometric verification failed again: ${authResult.errorCode ?? 'unknown'}',
      );
      _updateStatus('Identity verification failed');
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _showBiometricFailedDialog();
      }
    }
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
            const SizedBox(height: 20),
            // Status message
            Text(
              _statusMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
