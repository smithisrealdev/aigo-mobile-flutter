import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/billing_service.dart';

/// Shows an upgrade dialog when AI quota is exhausted.
/// Call: showUpgradeDialog(context, ref, currentUsage: X, monthlyLimit: Y, planName: 'Free')
Future<void> showUpgradeDialog(
  BuildContext context,
  WidgetRef ref, {
  int currentUsage = 0,
  int monthlyLimit = 10,
  String planName = 'Free',
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _UpgradeDialog(
      currentUsage: currentUsage,
      monthlyLimit: monthlyLimit,
      planName: planName,
      ref: ref,
    ),
  );
}

class _UpgradeDialog extends StatelessWidget {
  final int currentUsage;
  final int monthlyLimit;
  final String planName;
  final WidgetRef ref;

  const _UpgradeDialog({
    required this.currentUsage,
    required this.monthlyLimit,
    required this.planName,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final pct = monthlyLimit > 0 ? (currentUsage / monthlyLimit).clamp(0.0, 1.0) : 1.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.brandBlue, size: 32),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'AI Quota Reached',
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),

            // Usage text
            Text(
              "You've used $currentUsage/$monthlyLimit AI requests this month",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$planName Plan',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      '${(pct * 100).toInt()}%',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      pct >= 1.0 ? AppColors.error : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final billing = ref.read(billingServiceProvider);
                  final url = await billing.createCheckoutSession('pro');
                  if (url != null) {
                    await billing.openCheckoutInBrowser(url);
                  }
                },
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: Text('Upgrade to Pro', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Dismiss
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Maybe Later',
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
