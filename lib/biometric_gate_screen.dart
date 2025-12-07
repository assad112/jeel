import 'package:flutter/material.dart';
import 'services/biometric_service.dart';
import 'services/secure_storage_service.dart';
import 'splash_screen.dart';

/// Biometric Gate Screen - Shows biometric authentication before opening WebView
/// This screen checks if biometric login is enabled and shows authentication prompt
class BiometricGateScreen extends StatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  bool _isChecking = true;
  bool _biometricAvailable = false;
  bool _hasCredentials = false;
  bool _biometricEnabled = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    try {
      // Check if credentials exist
      final hasCredentials = await SecureStorageService.hasSavedCredentials();
      
      // Check if biometric is enabled
      final biometricEnabled = await SecureStorageService.isBiometricEnabled();
      
      // Check if biometric is available on device
      final biometricAvailable = await BiometricService.isAvailable();

      if (mounted) {
        setState(() {
          _hasCredentials = hasCredentials;
          _biometricEnabled = biometricEnabled;
          _biometricAvailable = biometricAvailable;
          _isChecking = false;
        });

        // تم تعطيل البصمة التلقائية - سيتم استخدام زر البصمة في صفحة تسجيل الدخول فقط
        // Always go directly to splash - biometric will be handled by the button in login page
        _navigateToSplash();
      }
    } catch (e) {
      debugPrint('Error checking initial state: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Error: $e';
        });
        _navigateToSplash();
      }
    }
  }

  Future<void> _authenticateAndNavigate() async {
    try {
      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to access Jeel ERP',
        useErrorDialogs: true,
        stickyAuth: true,
      );

      if (mounted) {
        if (authenticated) {
          // Authentication successful, navigate to splash screen
          _navigateToSplash();
        } else {
          // Authentication failed or cancelled
          setState(() {
            _errorMessage = 'Authentication failed. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('Error during authentication: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication error: $e';
        });
      }
    }
  }

  void _navigateToSplash() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SplashScreen(),
      ),
    );
  }

  void _skipBiometric() {
    _navigateToSplash();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Checking authentication...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // If no credentials or biometric not enabled, navigate immediately (invisible screen)
    if (!_hasCredentials || !_biometricEnabled || !_biometricAvailable) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Biometric Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    size: 60,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 40),

                // Title
                const Text(
                  'Biometric Authentication',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Please authenticate to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Error message if any
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Retry button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = '';
                    });
                    _authenticateAndNavigate();
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Authenticate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Skip button
                TextButton(
                  onPressed: _skipBiometric,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
