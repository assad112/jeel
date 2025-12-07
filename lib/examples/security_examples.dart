// ignore_for_file: unused_element, dead_code

import 'package:flutter/material.dart';
import '../widgets/bank_security_wrapper.dart';
import '../services/security_service.dart';

/// أمثلة على استخدام BankSecurityWrapper

// ══════════════════════════════════════════════════════════════
// مثال 1: الاستخدام الأساسي (جميع الميزات مفعّلة)
// ══════════════════════════════════════════════════════════════

class BasicSecurityExample extends StatelessWidget {
  const BasicSecurityExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const BankSecurityWrapper(
      child: MyApp(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// مثال 2: تخصيص مهلة عدم النشاط
// ══════════════════════════════════════════════════════════════

class CustomTimeoutExample extends StatelessWidget {
  const CustomTimeoutExample({super.key});

  @override
  Widget build(BuildContext context) {
    return BankSecurityWrapper(
      inactivityTimeout: const Duration(minutes: 3), // 3 دقائق
      onInactivityTimeout: () {
        debugPrint('⏰ User has been inactive for 3 minutes');
        // يمكنك إضافة منطق تسجيل الخروج هنا
      },
      child: const MyApp(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// مثال 3: تعطيل بعض الميزات
// ══════════════════════════════════════════════════════════════

class DisabledFeaturesExample extends StatelessWidget {
  const DisabledFeaturesExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const BankSecurityWrapper(
      enableScreenshotProtection: true,  // مفعّل
      enableJailbreakDetection: false,   // معطّل
      enableInactivityTimeout: false,    // معطّل
      child: MyApp(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// مثال 4: معالجة الأحداث الأمنية
// ══════════════════════════════════════════════════════════════

class SecurityEventsExample extends StatelessWidget {
  const SecurityEventsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return BankSecurityWrapper(
      onInactivityTimeout: () {
        // معالجة انتهاء الجلسة
        debugPrint('⏰ Session timeout');
        Navigator.of(context).pushReplacementNamed('/login');
      },
      onSecurityViolation: () {
        // معالجة انتهاك أمني
        debugPrint('⚠️ Security violation detected');
        // إرسال تنبيه للسيرفر
        _reportSecurityViolation();
      },
      child: const MyApp(),
    );
  }

  void _reportSecurityViolation() {
    // إرسال تقرير للسيرفر
    debugPrint('Reporting security violation to server...');
  }
}

// ══════════════════════════════════════════════════════════════
// مثال 5: فحص أمني يدوي
// ══════════════════════════════════════════════════════════════

class ManualSecurityCheckExample extends StatefulWidget {
  const ManualSecurityCheckExample({super.key});

  @override
  State<ManualSecurityCheckExample> createState() =>
      _ManualSecurityCheckExampleState();
}

class _ManualSecurityCheckExampleState
    extends State<ManualSecurityCheckExample> {
  bool _isSecure = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _performSecurityCheck();
  }

  Future<void> _performSecurityCheck() async {
    setState(() => _isLoading = true);

    try {
      final result = await SecurityService.performSecurityCheck(
        allowEmulator: false,
        allowRootedDevices: false,
        allowDeveloperMode: false,
      );

      setState(() {
        _isSecure = result.isPassed;
        _isLoading = false;
        if (!result.isPassed) {
          _errorMessage = result.errors.join('\n');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isSecure) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.security,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'Security Check Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return const BankSecurityWrapper(
      child: MyApp(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// مثال 6: عرض معلومات الأمان
// ══════════════════════════════════════════════════════════════

class SecurityInfoScreen extends StatefulWidget {
  const SecurityInfoScreen({super.key});

  @override
  State<SecurityInfoScreen> createState() => _SecurityInfoScreenState();
}

class _SecurityInfoScreenState extends State<SecurityInfoScreen> {
  Map<String, dynamic>? _securityInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityInfo();
  }

  Future<void> _loadSecurityInfo() async {
    setState(() => _isLoading = true);

    try {
      final info = await SecurityService.getDeviceSecurityInfo();
      setState(() {
        _securityInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading security info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Information'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _securityInfo == null
              ? const Center(child: Text('No security info available'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoCard(
                      'Platform',
                      _securityInfo!['platform']?.toString() ?? 'Unknown',
                      Icons.phone_android,
                    ),
                    _buildInfoCard(
                      'Version',
                      _securityInfo!['version']?.toString() ?? 'Unknown',
                      Icons.info,
                    ),
                    _buildInfoCard(
                      'Model',
                      _securityInfo!['model']?.toString() ?? 'Unknown',
                      Icons.devices,
                    ),
                    _buildInfoCard(
                      'Physical Device',
                      _securityInfo!['isPhysicalDevice']?.toString() ?? 'Unknown',
                      Icons.smartphone,
                    ),
                    _buildInfoCard(
                      'Compromised',
                      _securityInfo!['isCompromised']?.toString() ?? 'Unknown',
                      Icons.security,
                      isWarning: _securityInfo!['isCompromised'] == true,
                    ),
                    _buildInfoCard(
                      'Developer Mode',
                      _securityInfo!['isDeveloperMode']?.toString() ?? 'Unknown',
                      Icons.developer_mode,
                      isWarning: _securityInfo!['isDeveloperMode'] == true,
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon, {
    bool isWarning = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: isWarning ? Colors.orange : Colors.blue,
        ),
        title: Text(title),
        subtitle: Text(value),
        trailing: isWarning
            ? const Icon(Icons.warning, color: Colors.orange)
            : null,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// مثال 7: الوضع الآمن للغاية (Maximum Security)
// ══════════════════════════════════════════════════════════════

class MaximumSecurityExample extends StatelessWidget {
  const MaximumSecurityExample({super.key});

  @override
  Widget build(BuildContext context) {
    return BankSecurityWrapper(
      enableScreenshotProtection: true,
      enableJailbreakDetection: true,
      enableInactivityTimeout: true,
      inactivityTimeout: const Duration(minutes: 2), // جلسة قصيرة جداً
      showSecurityWarnings: true,
      onInactivityTimeout: () {
        // تسجيل خروج فوري
        _performLogout(context);
      },
      onSecurityViolation: () {
        // إغلاق التطبيق
        _closeApp();
      },
      child: const MyApp(),
    );
  }

  void _performLogout(BuildContext context) {
    debugPrint('🔒 Logging out due to inactivity');
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _closeApp() {
    debugPrint('🔒 Closing app due to security violation');
    // SystemNavigator.pop();
  }
}

// ══════════════════════════════════════════════════════════════
// التطبيق المثالي (Demo App)
// ══════════════════════════════════════════════════════════════

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              'App is Secured',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SecurityInfoScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.info),
              label: const Text('View Security Info'),
            ),
          ],
        ),
      ),
    );
  }
}


