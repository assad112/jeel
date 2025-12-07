import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Pastikan import file-file service Anda yang sebelumnya
import 'services/biometric_service.dart';
import 'services/secure_storage_service.dart';
import 'webview_screen.dart'; // Asumsi nama file WebView Anda

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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

  // Warna Brand (Konsisten dengan WebView Anda)
  final Color _primaryColor = const Color(0xFF0099A3); // Teal
  final Color _accentColor = const Color(0xFFA21955); // Pink/Magenta

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadSavedCredentials(); // Auto-fill jika ada data tersimpan
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

    // Simulasi Request API Login Native
    await Future.delayed(const Duration(seconds: 2));

    // DISINI LOGIKA LOGIN API ANDA
    // Jika sukses:
    if (mounted) {
      // Navigasi ke WebView
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const WebViewScreen(
            url: 'https://erp.jeel.om', // URL Tujuan
            title: 'Jeel ERP',
          ),
        ),
      );
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
      await Future.delayed(const Duration(seconds: 1)); // Simulasi

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const WebViewScreen(
              url: 'https://erp.jeel.om',
              title: 'Jeel ERP',
              // Anda bisa menambahkan logic untuk passing token ke WebView di sini
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ukuran layar
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            height: size.height - MediaQuery.of(context).padding.top,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),

                  // --- LOGO AREA ---
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons
                            .layers, // Ganti dengan Image.asset('assets/logo.png')
                        size: 50,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to access your Jeel ERP',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),

                  const Spacer(flex: 1),

                  // --- INPUT USERNAME ---
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Username / Email',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: _primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- INPUT PASSWORD ---
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: _primaryColor,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),

                  // --- FORGOT PASSWORD ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Logic Forgot Password
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- LOGIN BUTTON ---
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- BIOMETRIC SECTION ---
                  if (_isBiometricAvailable) ...[
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR USE',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: InkWell(
                        onTap: _handleBiometricLogin,
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _accentColor.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            size: 40,
                            color: _accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Fingerprint',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  // --- FOOTER ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Logic Register
                          },
                          child: Text(
                            "Contact Admin",
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
