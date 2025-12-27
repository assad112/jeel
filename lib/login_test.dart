import 'package:flutter/material.dart';
import 'dart:ui' as ui;
// Pastikan import file-file service Anda yang sebelumnya
import 'services/biometric_service.dart';
import 'services/secure_storage_service.dart';
import 'splash_screen.dart'; // Navigate to SplashScreen for auto-login
// Used in biometric function
import 'reset_password_screen.dart'; // Reset password screen

class LoginPage extends StatefulWidget {
  final String? initialErrorCode;

  const LoginPage({super.key, this.initialErrorCode});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isBiometricAvailable = false;

  // Brand Colors
  final Color _primaryColor = const Color(0xFFA21955); // Pink/Magenta
  final Color _accentColor = const Color(0xFFA21955); // Pink/Magenta

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadSavedCredentials(); // Auto-fill jika ada data tersimpan

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialErrorCode == 'invalid_credentials') {
        final message = _isArabic
            ? 'بيانات الدخول غير صحيحة. تحقق من اسم المستخدم وكلمة المرور.'
            : 'Invalid credentials. Check your username and password.';

        final colorScheme = Theme.of(context).colorScheme;

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              duration: const Duration(seconds: 3),
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.onError),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: colorScheme.onError),
                    ),
                  ),
                ],
              ),
            ),
          );
      }
    });
  }

  bool get _isArabic =>
      ui.PlatformDispatcher.instance.locale.languageCode == 'ar';

  Future<bool> _askEnableBiometricOnFirstLogin() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 34,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isArabic ? 'تفعيل البصمة' : 'Enable biometric login',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isArabic
                      ? 'هل تريد استخدام بصمة الإصبع لتسجيل الدخول في المرات القادمة؟'
                      : 'Do you want to use fingerprint for future sign-ins?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: BorderSide(color: _primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_isArabic ? 'لا' : 'Not now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_isArabic ? 'نعم' : 'Enable'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    setState(() {
      _isBiometricAvailable = available;
    });
  }

  // Cek apakah ada data tersimpan untuk auto-fill field (bukan auto-login)
  Future<void> _loadSavedCredentials() async {
    final credentials = await SecureStorageService.getCredentials();
    if (credentials['username'] != null) {
      setState(() {
        _usernameController.text = credentials['username']!;
        // Optional: _passwordController.text = credentials['password']!;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Fungsi Login Manual
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hadCredentials = await SecureStorageService.hasSavedCredentials();

      // Save credentials in secure storage before navigating to WebView
      await SecureStorageService.saveCredentials(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await SecureStorageService.setAutoLoginEnabled(true);

      // Ask once on first successful login whether to enable biometric.
      // This only sets the preference; SplashScreen will enforce it on next app start.
      if (!hadCredentials) {
        final biometricAvailable = await BiometricService.isAvailable();
        if (biometricAvailable && mounted) {
          final enableBiometric = await _askEnableBiometricOnFirstLogin();
          await SecureStorageService.setBiometricEnabled(enableBiometric);
        } else {
          // If biometric isn't available, keep it disabled.
          await SecureStorageService.setBiometricEnabled(false);
        }
      }

      debugPrint('✅ Credentials saved: ${_usernameController.text.trim()}');

      // Navigate to SplashScreen for auto-login in background
      // User will only see SplashScreen then direct entry to the system
      // Skip biometric on first login since user just entered credentials
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SplashScreen(skipBiometric: true),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving credentials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Fungsi Login Biometrik
  Future<void> _handleBiometricLogin() async {
    // 1. Cek Credentials
    final hasCredentials = await SecureStorageService.hasSavedCredentials();

    if (!hasCredentials) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada data tersimpan. Silakan login manual sekali.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Lakukan Autentikasi
    final authenticated = await BiometricService.authenticate(
      reason: 'Scan sidik jari untuk masuk',
    );

    if (authenticated) {
      setState(() => _isLoading = true);

      // Ambil data
      final creds = await SecureStorageService.getCredentials();
      final username = creds['username'];
      final password = creds['password'];

      // TODO: Panggil API Login Native disini menggunakan user/pass tersebut
      // NOTE: Avoid artificial delay; SplashScreen handles the real web login.

      if (mounted) {
        // Navigate to SplashScreen for auto-login in background
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
        );
      }
    }
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: _primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isArabic ? 'مرحباً بعودتك' : 'Welcome Back';
    final subtitleText = _isArabic
        ? 'سجّل الدخول للوصول إلى نظام جيل'
        : 'Sign in to access your Jeel ERP';
    final usernameLabelText = _isArabic
        ? 'اسم المستخدم / البريد الإلكتروني'
        : 'Username / Email';
    final passwordLabelText = _isArabic ? 'كلمة المرور' : 'Password';
    final forgotPasswordText = _isArabic
        ? 'نسيت كلمة المرور؟'
        : 'Forgot Password?';
    final loginButtonText = _isArabic ? 'تسجيل الدخول' : 'LOGIN';
    final usernameRequiredText = _isArabic
        ? 'يرجى إدخال اسم المستخدم'
        : 'Please enter username';
    final passwordRequiredText = _isArabic
        ? 'يرجى إدخال كلمة المرور'
        : 'Please enter password';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- LOGO ---
                    Center(
                      child: Image.asset(
                        'assets/images/JeeEngineering.png',
                        height: 84,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 84,
                            width: 84,
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.business,
                              size: 40,
                              color: _primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitleText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Card(
                      elevation: 1,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _usernameController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  textDirection: TextDirection.ltr,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  decoration: _inputDecoration(
                                    labelText: usernameLabelText,
                                    prefixIcon: Icons.person_outline,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return usernameRequiredText;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  textInputAction: TextInputAction.done,
                                  textDirection: TextDirection.ltr,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) {
                                      _handleLogin();
                                    }
                                  },
                                  decoration: _inputDecoration(
                                    labelText: passwordLabelText,
                                    prefixIcon: Icons.lock_outline,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return passwordRequiredText;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ResetPasswordScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      forgotPasswordText,
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            loginButtonText,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
