import 'package:flutter/material.dart';

class AppColors {
  static const Color brandBlue = Color(0xFF1A5EFF);       // Looka primary
  static const Color brandBlueLight = Color(0xFF4D82FF);   // Looka light blue
  static const Color brandBlueDark = Color(0xFF0044E6);    // Looka dark blue
  static const Color brandBluePale = Color(0xFF80A6FF);    // Looka pale blue
  static const Color brandGrey = Color(0xFFE6E6E6);        // Looka light grey
  static const Color background = Color(0xFFF9FAFB);       // slightly warmer
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1B2232);      // dark navy (from website)
  static const Color textSecondary = Color(0xFF676E7E);    // grey (from website)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color border = Color(0xFFE2E4E9);           // website border
  static const Color cardShadow = Color(0x0A000000);
  static const Color cardDark = Color(0xFF2A2D35);
  static const Color surfaceDark = Color(0xFF1E2028);

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A5EFF), Color(0xFF0044E6)],
  );

  static const LinearGradient blueGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A5EFF), Color(0xFF4D82FF)],
  );
}
