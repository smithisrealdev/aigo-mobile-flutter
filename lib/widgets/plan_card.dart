import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/billing_models.dart';
import '../services/billing_service.dart';

const Color _brandBlue = Color(0xFF1A5EFF);
const Color _grey = Color(0xFFE6E6E6);

/// Displays current plan with usage stats and upgrade button.
class PlanCard extends ConsumerWidget {
  const PlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(currentPlanProvider);

    return planAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(color: _brandBlue)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (plan) {
        if (plan == null) return const SizedBox.shrink();
        return _buildCard(context, ref, plan);
      },
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, PlanLimit plan) {
    final badgeColor = plan.isFree
        ? Colors.grey
        : plan.isPro
            ? _brandBlue
            : const Color(0xFF7C3AED); // purple for Team

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _grey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your Plan',
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  plan.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${plan.name} Plan',
            style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 12),
          _UsageBar(
            label: 'Trips',
            icon: Icons.flight_takeoff,
            max: plan.maxTrips,
          ),
          const SizedBox(height: 8),
          _UsageBar(
            label: 'AI Requests',
            icon: Icons.auto_awesome,
            max: plan.maxAiRequests,
          ),
          if (plan.isFree) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleUpgrade(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Upgrade to Pro',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleUpgrade(BuildContext context, WidgetRef ref) async {
    final billing = ref.read(billingServiceProvider);
    final url = await billing.createCheckoutSession('pro');
    if (url != null) {
      await billing.openCheckoutInBrowser(url);
    }
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final int max;

  const _UsageBar({
    required this.label,
    required this.icon,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    // Usage tracking would come from a real usage provider;
    // showing max for now as placeholder.
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $max available',
            style: GoogleFonts.dmSans(
                fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
