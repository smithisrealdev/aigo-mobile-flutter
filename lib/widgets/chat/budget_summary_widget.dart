import 'package:flutter/material.dart';

import '../../models/chat/widget_models.dart';
import '../../theme/app_colors.dart';

class BudgetSummaryWidget extends StatelessWidget {
  final BudgetSummaryInfo budgetInfo;
  final bool isDark;

  const BudgetSummaryWidget({
    super.key,
    required this.budgetInfo,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (budgetInfo.rawBlock.isEmpty) return const SizedBox.shrink();

    // Parse the block text logic
    // For simplicity, we just extract fields directly from the markdown rawblock
    // Or render it nicely structured
    final lines = budgetInfo.rawBlock.split('\n');
    final title =
        lines
            .where(
              (l) =>
                  l.trim().startsWith('#') ||
                  l.toLowerCase().contains('budget'),
            )
            .firstOrNull
            ?.replaceAll(RegExp(r'#+\s*'), '')
            .trim() ??
        'Budget Summary';

    final otherLines = lines
        .where((l) => l.trim().isNotEmpty && l != title)
        .toList();

    final bgColor = isDark
        ? const Color(0xFF2E2E2E).withValues(alpha: 0.5)
        : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF4B5563)
        : const Color(0xFFE5E7EB);
    final primaryColor = isDark ? AppColors.brandBlueDark : AppColors.brandBlue;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark
        ? Colors.white70
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 20,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: otherLines.map((line) {
                  // If line is a bullet point, render it as list item
                  if (line.trim().startsWith('-') ||
                      line.trim().startsWith('*')) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(
                              top: 6,
                              right: 8,
                              left: 4,
                            ),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(alpha: 0.5),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line
                                  .replaceFirst(RegExp(r'^[-*]\s*'), '')
                                  .replaceAll('**', ''),
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Else render as plain text bold if it contains numbers
                  final isAmount = RegExp(r'[\d,]+').hasMatch(line);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      line.replaceAll('**', ''),
                      style: TextStyle(
                        fontSize: isAmount ? 15 : 14,
                        fontWeight: isAmount
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isAmount ? textColor : secondaryTextColor,
                        height: 1.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
