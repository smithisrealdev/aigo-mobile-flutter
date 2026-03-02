/// Detects and extracts Smart Info Boxes from AI responses.
/// Mirrors web's ChatMessage.tsx info box auto-detection.
/// Supports Thai + English patterns.
library;

import 'package:flutter/material.dart';

enum InfoBoxType { tip, warning, info, success }

class InfoBoxData {
  final InfoBoxType type;
  final String content;

  const InfoBoxData({required this.type, required this.content});

  Color get backgroundColor {
    switch (type) {
      case InfoBoxType.tip:
        return const Color(0xFFEFF6FF);
      case InfoBoxType.warning:
        return const Color(0xFFFEF3C7);
      case InfoBoxType.info:
        return const Color(0xFFECFDF5);
      case InfoBoxType.success:
        return const Color(0xFFF0FDF4);
    }
  }

  Color get borderColor {
    switch (type) {
      case InfoBoxType.tip:
        return const Color(0xFFBFDBFE);
      case InfoBoxType.warning:
        return const Color(0xFFFDE68A);
      case InfoBoxType.info:
        return const Color(0xFFA7F3D0);
      case InfoBoxType.success:
        return const Color(0xFFBBF7D0);
    }
  }

  Color get accentColor {
    switch (type) {
      case InfoBoxType.tip:
        return const Color(0xFF2563EB);
      case InfoBoxType.warning:
        return const Color(0xFFF59E0B);
      case InfoBoxType.info:
        return const Color(0xFF0EA5E9);
      case InfoBoxType.success:
        return const Color(0xFF10B981);
    }
  }

  IconData get icon {
    switch (type) {
      case InfoBoxType.tip:
        return Icons.lightbulb_outline;
      case InfoBoxType.warning:
        return Icons.warning_amber_rounded;
      case InfoBoxType.info:
        return Icons.info_outline;
      case InfoBoxType.success:
        return Icons.check_circle_outline;
    }
  }

  // Dark mode variants
  Color get backgroundColorDark {
    switch (type) {
      case InfoBoxType.tip:
        return const Color(0xFF1E293B);
      case InfoBoxType.warning:
        return const Color(0xFF422006);
      case InfoBoxType.info:
        return const Color(0xFF0F2922);
      case InfoBoxType.success:
        return const Color(0xFF052E16);
    }
  }

  Color get borderColorDark {
    switch (type) {
      case InfoBoxType.tip:
        return const Color(0xFF1E40AF);
      case InfoBoxType.warning:
        return const Color(0xFF92400E);
      case InfoBoxType.info:
        return const Color(0xFF065F46);
      case InfoBoxType.success:
        return const Color(0xFF166534);
    }
  }
}

class InfoBoxDetector {
  // Patterns for each type (English + Thai)
  static final _tipPatterns = [
    RegExp(r'^💡\s*(?:Tip|เคล็ดลับ|Pro tip)?:?\s*', caseSensitive: false),
    RegExp(r'^\*\*(?:💡\s*)?(?:Tip|เคล็ดลับ|Pro tip)\*\*:?\s*', caseSensitive: false),
  ];
  static final _warningPatterns = [
    RegExp(r'^⚠️\s*(?:Warning|คำเตือน|Caution|ระวัง)?:?\s*', caseSensitive: false),
    RegExp(r'^\*\*(?:⚠️\s*)?(?:Warning|คำเตือน|Caution)\*\*:?\s*', caseSensitive: false),
  ];
  static final _infoPatterns = [
    RegExp(r'^ℹ️\s*(?:Note|หมายเหตุ|Info|Important|สำคัญ)?:?\s*', caseSensitive: false),
    RegExp(r'^\*\*(?:ℹ️\s*)?(?:Note|หมายเหตุ|Info|Important)\*\*:?\s*', caseSensitive: false),
  ];
  static final _successPatterns = [
    RegExp(r'^✅\s*(?:Recommended|แนะนำ|Best|ดีที่สุด)?:?\s*', caseSensitive: false),
    RegExp(r'^\*\*(?:✅\s*)?(?:Recommended|แนะนำ|Best)\*\*:?\s*', caseSensitive: false),
  ];

  /// Detect the info box type for a given line.
  static InfoBoxType? detectType(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    for (final p in _tipPatterns) {
      if (p.hasMatch(trimmed)) return InfoBoxType.tip;
    }
    for (final p in _warningPatterns) {
      if (p.hasMatch(trimmed)) return InfoBoxType.warning;
    }
    for (final p in _infoPatterns) {
      if (p.hasMatch(trimmed)) return InfoBoxType.info;
    }
    for (final p in _successPatterns) {
      if (p.hasMatch(trimmed)) return InfoBoxType.success;
    }
    return null;
  }

  /// Strip the info box prefix from a line, keeping only the content.
  static String stripPrefix(String line) {
    var result = line.trim();
    final allPatterns = [
      ..._tipPatterns,
      ..._warningPatterns,
      ..._infoPatterns,
      ..._successPatterns,
    ];
    for (final p in allPatterns) {
      result = result.replaceFirst(p, '');
    }
    return result.trim();
  }

  /// Scan text for info box blocks. Returns list of (type, content) pairs
  /// and remaining text with info boxes removed.
  static ({List<InfoBoxData> boxes, String remainingText}) extractInfoBoxes(
      String text) {
    final lines = text.split('\n');
    final boxes = <InfoBoxData>[];
    final remaining = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final type = detectType(lines[i]);
      if (type != null) {
        // Collect consecutive lines for this info box
        final content = StringBuffer(stripPrefix(lines[i]));
        // Check if next lines are continuation (indented or no new prefix)
        while (i + 1 < lines.length &&
            lines[i + 1].trim().isNotEmpty &&
            detectType(lines[i + 1]) == null &&
            !lines[i + 1].startsWith('#') &&
            !lines[i + 1].startsWith('- ') &&
            !lines[i + 1].startsWith('* ')) {
          i++;
          content.write(' ${lines[i].trim()}');
        }
        boxes.add(InfoBoxData(type: type, content: content.toString().trim()));
      } else {
        remaining.add(lines[i]);
      }
    }

    return (boxes: boxes, remainingText: remaining.join('\n').trim());
  }
}
