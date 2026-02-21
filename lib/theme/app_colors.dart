import 'package:flutter/material.dart';

class AppColors {
  static const Color brandBlue = Color(0xFF1A5EFF);
  static const Color brandBlueLight = Color(0xFF4A82FF);
  static const Color brandBlueDark = Color(0xFF0D3FCC);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color border = Color(0xFFE2E8F0);
  static const Color cardShadow = Color(0x0A000000);

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A5EFF), Color(0xFF0D3FCC)],
  );

  static const LinearGradient blueGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A5EFF), Color(0xFF3B7BFF)],
  );
}
