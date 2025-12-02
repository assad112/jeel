import 'package:flutter/material.dart';
import 'biometric_gate_screen.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      home: BiometricGateScreen(),
    ),
  );
}
