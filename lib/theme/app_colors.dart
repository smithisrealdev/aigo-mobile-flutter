import 'package:flutter/material.dart';

class AppColors {
  static const Color brandBlue = Color(0xFF2563EB);        // Primary blue
  static const Color brandBlueLight = Color(0xFF60A5FA);   // Light blue
  static const Color brandBlueDark = Color(0xFF1E40AF);    // Dark blue
  static const Color brandBluePale = Color(0xFFDBEAFE);    // Pale blue
  static const Color brandGrey = Color(0xFFE6E6E6);        // Light grey
  static const Color background = Color(0xFFFFFFFF);        // Pure white
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF111827);      // Figma primary
  static const Color textSecondary = Color(0xFF6B7280);    // Figma secondary
  static const Color searchBackground = Color(0xFFF3F4F6); // Search bar bg
  static const Color ratingGold = Color(0xFFF59E0B);       // Star rating
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color border = Color(0xFFE5E7EB);           // card border
  static const Color cardShadow = Color(0x0A000000);
  static const Color cardDark = Color(0xFF2A2D35);
  static const Color surfaceDark = Color(0xFF1E2028);

  // New theme colors
  static const Color blueBorder = Color(0xFFDBEAFE);       // Light blue border
  static const Color blueTint = Color(0xFFEFF6FF);          // Blue tint bg
  static const Color blueVeryLight = Color(0xFFF0F7FF);    // Very light blue
  static const Color iconInactive = Color(0xFF9CA3AF);     // Inactive icon
  static const Color searchBg = Color(0xFFF3F4F6);         // Search bg alias
  static const Color divider = Color(0xFFF3F4F6);          // Divider color
  static const Color chipOutline = Color(0xFFD1D5DB);      // Chip outline

  // Dark mode colors
  static const Color backgroundDark = Color(0xFF0F1117);
  static const Color surfaceDarkMode = Color(0xFF1A1D27);
  static const Color cardDarkMode = Color(0xFF242731);
  static const Color textPrimaryDark = Color(0xFFF1F3F5);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color borderDark = Color(0xFF2E3240);

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
  );

  static const LinearGradient blueGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
  );
}
