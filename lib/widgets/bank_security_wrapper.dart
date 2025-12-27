import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';
import '../services/security_service.dart';

/// Bank-Level Security Wrapper
class BankSecurityWrapper extends StatefulWidget {
  final Widget child;
  final bool enableScreenshotProtection;
  final bool enableJailbreakDetection;
  final bool enableInactivityTimeout;
  final Duration inactivityTimeout;
  final VoidCallback? onInactivityTimeout;
  final VoidCallback? onSecurityViolation;
  final bool showSecurityWarnings;

  const BankSecurityWrapper({
    super.key,
    required this.child,
    this.enableScreenshotProtection = true,
    this.enableJailbreakDetection = true,
    this.enableInactivityTimeout = true,
    this.inactivityTimeout = const Duration(minutes: 5),
    this.onInactivityTimeout,
    this.onSecurityViolation,
    this.showSecurityWarnings = true,
  });

  @override
  State<BankSecurityWrapper> createState() => _BankSecurityWrapperState();
}

class _BankSecurityWrapperState extends State<BankSecurityWrapper>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  bool _isSecurityCheckPassed = true;
  bool _showBlurOverlay = false;
  String? _securityError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSecurity();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeSecurity() async {
    try {
      if (widget.enableScreenshotProtection) {
        await _enableScreenshotProtection();
      }

      if (widget.enableJailbreakDetection) {
        await _performJailbreakCheck();
      }

      if (mounted) {
        await SecurityService.printSecurityInfo();
      }
    } catch (e) {
      debugPrint('Error initializing security: $e');
    }
  }

  Future<void> _enableScreenshotProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
      
      await ScreenProtector.preventScreenshotOn();
      
      debugPrint('🔒 Screenshot protection enabled');
    } catch (e) {
      debugPrint('Error enabling screenshot protection: $e');
    }
  }

  Future<void> _performJailbreakCheck() async {
    try {
      final result = await SecurityService.performSecurityCheck(
        allowEmulator: true,
        allowRootedDevices: false,
        allowDeveloperMode: true,
      );

      if (mounted) {
        setState(() {
          _isSecurityCheckPassed = result.isPassed;
          
          if (!result.isPassed) {
            _securityError = result.errors.join('\n');
            widget.onSecurityViolation?.call();
          }
        });

        if (result.warnings.isNotEmpty && widget.showSecurityWarnings) {
          for (final warning in result.warnings) {
            debugPrint('⚠️ Security Warning: $warning');
          }
        }
      }
    } catch (e) {
      debugPrint('Error performing jailbreak check: $e');
    }
  }

  void _startInactivityTimer() {
    if (!widget.enableInactivityTimeout) return;

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.inactivityTimeout, () {
      if (mounted) {
        debugPrint('⏰ Inactivity timeout reached');
        widget.onInactivityTimeout?.call();
        _showInactivityDialog();
      }
    });
  }

  void _resetInactivityTimer() {
    if (!widget.enableInactivityTimeout) return;
    _startInactivityTimer();
  }

  void _showInactivityDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.orange),
            SizedBox(width: 12),
            Text('Session Timeout'),
          ],
        ),
        content: const Text(
          'Your session has expired due to inactivity. Please authenticate again.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startInactivityTimer();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        if (mounted) {
          setState(() {
            _showBlurOverlay = false;
          });
          _resetInactivityTimer();
          debugPrint('📱 App resumed');
        }
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        if (mounted) {
          setState(() {
            _showBlurOverlay = true;
          });
          _inactivityTimer?.cancel();
          debugPrint('📱 App paused/inactive');
        }
        break;

      case AppLifecycleState.detached:
        debugPrint('📱 App detached');
        break;

      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSecurityCheckPassed) {
      return _buildSecurityErrorScreen();
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: Stack(
        children: [
          widget.child,

          if (_showBlurOverlay)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Secured',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 60,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Security Violation Detected',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_securityError != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _securityError!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 30),
                const Text(
                  'This application cannot run on compromised devices for security reasons.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Exit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

