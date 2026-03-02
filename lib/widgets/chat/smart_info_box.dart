import 'package:flutter/material.dart';
import '../../utils/info_box_detector.dart';

/// Renders a styled info box card (Tip/Warning/Info/Success).
/// Matches web's ChatMessage.tsx smart info box rendering.
class SmartInfoBox extends StatelessWidget {
  final InfoBoxData data;

  const SmartInfoBox({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? data.backgroundColorDark : data.backgroundColor;
    final border = isDark ? data.borderColorDark : data.borderColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
