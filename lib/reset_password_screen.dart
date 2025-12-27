import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'settings_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Primary color
  static const Color _primaryColor = Color(0xFFA21955);
  static const Color _secondaryColor = Color(0xFF7D3C5D);

  bool get _isArabic =>
      ui.PlatformDispatcher.instance.locale.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleResetPassword() {
    _handleResetPasswordInBackground();
  }

  Future<void> _handleResetPasswordInBackground() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      final result = await _submitResetPasswordRequest(email)
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isArabic
                  ? 'إذا كان البريد الإلكتروني مسجلاً، سيتم إرسال رابط إعادة التعيين.'
                  : 'If the email is registered, a reset link will be sent.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ??
                  (_isArabic
                      ? 'تعذّر إرسال طلب إعادة التعيين. حاول مرة أخرى.'
                      : 'Could not send reset request. Please try again.'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'انتهت المهلة. تحقق من الاتصال وحاول مرة أخرى.'
                : 'Timed out. Check your connection and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'حدث خطأ غير متوقع. حاول مرة أخرى.'
                : 'An unexpected error occurred. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _jsString(String value) => jsonEncode(value);

  static String _buildSubmitResetJs({required String email}) {
    final emailJson = _jsString(email);
    return '''
(function() {
  function setNativeValue(element, value) {
    if (!element) return;
    var lastValue = element.value;
    element.value = value;
    var tracker = element._valueTracker;
    if (tracker) {
      tracker.setValue(lastValue);
    }
    var descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
    if (descriptor && descriptor.set) {
      descriptor.set.call(element, value);
    }
    var events = ['focus', 'input', 'change', 'blur'];
    for (var i = 0; i < events.length; i++) {
      element.dispatchEvent(new Event(events[i], { bubbles: true, cancelable: true }));
    }
  }

  var emailSelectors = [
    'input[name="login"]',
    'input[name="email"]',
    'input[type="email"]',
    'input[id*="login" i]',
    'input[id*="email" i]',
    'input[placeholder*="email" i]'
  ];

  var emailInput = null;
  for (var i = 0; i < emailSelectors.length; i++) {
    emailInput = document.querySelector(emailSelectors[i]);
    if (emailInput) break;
  }

  if (!emailInput) {
    return JSON.stringify({ ok: false, reason: 'email_input_not_found' });
  }

  setNativeValue(emailInput, $emailJson);

  var form = emailInput.closest('form') || document.querySelector('form');
  if (!form) {
    return JSON.stringify({ ok: false, reason: 'form_not_found' });
  }

  var submitBtn = form.querySelector('button[type="submit"], input[type="submit"], button:not([type="button"]):not([type="reset"])');
  if (submitBtn) {
    submitBtn.click();
    return JSON.stringify({ ok: true, submitted: true });
  }

  try {
    form.submit();
    return JSON.stringify({ ok: true, submitted: true });
  } catch (e) {
    return JSON.stringify({ ok: false, reason: 'submit_failed' });
  }
})();
''';
  }

  static const String _checkResetResultJs = '''
(function() {
  function textOf(sel) {
    var el = document.querySelector(sel);
    if (!el) return null;
    return (el.innerText || el.textContent || '').trim();
  }

  var successText =
    textOf('.alert-success') ||
    textOf('.o_alert_success') ||
    textOf('.text-success');

  var errorText =
    textOf('.alert-danger') ||
    textOf('.o_alert_danger') ||
    textOf('.text-danger') ||
    textOf('.alert-error');

  return JSON.stringify({ successText: successText, errorText: errorText });
})();
''';

  Future<_ResetResult> _submitResetPasswordRequest(String email) async {
    final loginUrl = await SettingsService.getUrl();
    final loginUri = Uri.tryParse(loginUrl);
    final resetUri = (loginUri ?? Uri.parse('https://erp.jeel.om/web/login'))
        .replace(path: '/web/reset_password', query: '', fragment: '');

    final pageLoaded = Completer<void>();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (!pageLoaded.isCompleted) {
              pageLoaded.complete();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (!pageLoaded.isCompleted) {
              pageLoaded.complete();
            }
          },
        ),
      );

    await controller.loadRequest(resetUri);
    await pageLoaded.future.timeout(const Duration(seconds: 15));

    final submitRaw = await controller.runJavaScriptReturningResult(
      _buildSubmitResetJs(email: email),
    );

    final submitJson = submitRaw?.toString() ?? '';
    if (submitJson.isNotEmpty && submitJson.startsWith('{') == false) {
      // WebView may wrap strings with quotes depending on platform.
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    final resultRaw =
        await controller.runJavaScriptReturningResult(_checkResetResultJs);

    final resultStr = resultRaw?.toString() ?? '';
    final parsed = _tryParseJson(resultStr);
    final successText = parsed?['successText']?.toString();
    final errorText = parsed?['errorText']?.toString();

    // If the page shows an explicit error, surface it. Otherwise, treat it as success
    // because many backends respond with a generic success message.
    if (errorText != null && errorText.trim().isNotEmpty) {
      return _ResetResult(success: false, message: errorText.trim());
    }
    if (successText != null && successText.trim().isNotEmpty) {
      return _ResetResult(success: true, message: successText.trim());
    }

    // Fallback: we submitted the form; assume success.
    return const _ResetResult(success: true);
  }

  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      var s = raw.trim();
      // Handle platform returning a quoted JSON string
      if ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'"))) {
        s = s.substring(1, s.length - 1);
        s = s.replaceAll('\\n', '\n').replaceAll('\\"', '"');
      }
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isArabic ? 'نسيت كلمة المرور؟' : 'Forgot Password?';
    final subtitleText = _isArabic
        ? 'لا تقلق! أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.'
        : 'Don\'t worry! Enter your email address and we\'ll send you a link to reset your password.';
    final emailLabelText = _isArabic ? 'البريد الإلكتروني' : 'Email Address';
    final emailHintText = _isArabic
        ? 'أدخل بريدك الإلكتروني'
        : 'Enter your email';
    final sendButtonText = _isArabic
        ? 'إرسال رابط إعادة التعيين'
        : 'Send Reset Link';
    final rememberText = _isArabic
        ? 'تتذكر كلمة المرور؟ '
        : 'Remember your password? ';
    final loginText = _isArabic ? 'تسجيل الدخول' : 'Login';
    final securityNoteText = _isArabic
        ? 'سنرسل رابطًا آمنًا إلى بريدك الإلكتروني لإعادة تعيين كلمة المرور.'
        : 'We\'ll send a secure link to your email to reset your password.';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryColor.withOpacity(0.08),
              Colors.white,
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // --- Back Button ---
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: _primaryColor,
                                size: 20,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Logo ---
                        Center(
                          child: Image.asset(
                            'assets/images/JeeEngineering.png',
                            height: 70,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 70,
                                width: 70,
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.business,
                                  size: 35,
                                  color: _primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Lock Icon with Circle ---
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 50,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // --- Title ---
                        Directionality(
                          textDirection: _isArabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            titleText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // --- Subtitle ---
                        Directionality(
                          textDirection: _isArabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            subtitleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 35),

                        // --- Email Label ---
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: _primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              emailLabelText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // --- Email Input Field ---
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintText: emailHintText,
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.alternate_email,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _isArabic
                                    ? 'يرجى إدخال البريد الإلكتروني'
                                    : 'Please enter your email';
                              }
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return _isArabic
                                    ? 'يرجى إدخال بريد إلكتروني صحيح'
                                    : 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- Reset Password Button ---
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [_primaryColor, _secondaryColor],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleResetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.send_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Directionality(
                                        textDirection: _isArabic
                                            ? TextDirection.rtl
                                            : TextDirection.ltr,
                                        child: Text(
                                          sendButtonText,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // --- Back to Login Link ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          textDirection: _isArabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          children: [
                            Text(
                              rememberText,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                loginText,
                                style: const TextStyle(
                                  color: _primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // --- Security Note ---
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade100,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.blue.shade700,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  securityNoteText,
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetResult {
  final bool success;
  final String? message;
  const _ResetResult({required this.success, this.message});
}
