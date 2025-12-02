import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import '../services/biometric_service.dart';

/// Dialog to ask user if they want to save credentials and enable biometric login
class CredentialSaverDialog extends StatefulWidget {
  final String username;
  final String password;

  const CredentialSaverDialog({
    super.key,
    required this.username,
    required this.password,
  });

  @override
  State<CredentialSaverDialog> createState() => _CredentialSaverDialogState();
}

class _CredentialSaverDialogState extends State<CredentialSaverDialog> {
  bool _isSaving = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricService.isAvailable();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
      });
    }
  }

  Future<void> _saveCredentials({bool enableBiometric = false}) async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Save credentials
      await SecureStorageService.saveCredentials(
        username: widget.username,
        password: widget.password,
      );

      // Enable biometric if requested
      if (enableBiometric && _biometricAvailable) {
        await SecureStorageService.setBiometricEnabled(true);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving credentials: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تفعيل تسجيل الدخول بالبصمة؟'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تم حفظ بيانات تسجيل الدخول بنجاح.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (_biometricAvailable)
              const Text(
                'هل تريد تفعيل تسجيل الدخول بالبصمة / Face ID؟\n\n'
                'ستتمكن من تسجيل الدخول باستخدام بصمة الإصبع أو Face ID في المرة القادمة.',
                style: TextStyle(fontSize: 14),
              )
            else
              const Text(
                'يمكنك تسجيل الدخول بشكل أسرع في المرة القادمة.',
                style: TextStyle(fontSize: 14),
              ),
          ],
        ),
      ),
      actions: [
        if (_biometricAvailable) ...[
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
            child: const Text('لا، شكراً'),
          ),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () => _saveCredentials(enableBiometric: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('نعم، تفعيل البصمة'),
          ),
        ] else
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(true),
            child: const Text('موافق'),
          ),
      ],
    );
  }
}

