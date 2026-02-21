import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class QuickChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const QuickChip({super.key, required this.label, this.icon, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? AppColors.brandBlue : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
