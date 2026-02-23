import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../config/supabase_config.dart';
import '../services/billing_service.dart';
import '../models/billing_models.dart';

final allPlansProvider = FutureProvider<List<PlanLimit>>((ref) async {
  final data = await SupabaseConfig.client
      .from('plan_limits')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return (data as List).map((e) => PlanLimit.fromJson(e)).toList();
});

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(allPlansProvider);
    final currentPlanAsync = ref.watch(currentPlanProvider);
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text('Subscription', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                  ],
                ),
                const SizedBox(height: 16),
                // Monthly/Yearly toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _toggleButton('Monthly', !_isYearly, () => setState(() => _isYearly = false)),
                      _toggleButton('Yearly', _isYearly, () => setState(() => _isYearly = true)),
                    ],
                  ),
                ),
                if (_isYearly)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Save up to 20% with yearly billing', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          // Plans list
          Expanded(
            child: plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandBlue)),
              error: (e, _) => Center(child: Text('Failed to load plans: $e')),
              data: (plans) {
                if (plans.isEmpty) {
                  return _buildFallbackPlans(currentPlanAsync);
                }
                final currentPlanId = currentPlanAsync.valueOrNull?.id ?? 'free';
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: plans.length,
                  itemBuilder: (_, i) => _buildPlanCard(plans[i], plans[i].id == currentPlanId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: active ? AppColors.brandBlue : Colors.white70,
        )),
      ),
    );
  }

  Widget _buildPlanCard(PlanLimit plan, bool isCurrent) {
    final price = _isYearly ? (plan.yearlyPrice / 12) : plan.price;
    final priceStr = plan.isFree ? 'Free' : '\$${price.toStringAsFixed(2)}/mo';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent ? Border.all(color: AppColors.brandBlue, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.name, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('Current', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(priceStr, style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.brandBlue)),
          const SizedBox(height: 12),
          ...plan.features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary))),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flight_takeoff, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${plan.maxTrips} trips', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              Icon(Icons.auto_awesome, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${plan.maxAiRequests} AI/mo', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (!isCurrent && !plan.isFree) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _handleUpgrade(plan.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Upgrade to ${plan.name}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackPlans(AsyncValue<PlanLimit?> currentPlanAsync) {
    final currentId = currentPlanAsync.valueOrNull?.id ?? 'free';
    final fallback = [
      PlanLimit(id: 'free', name: 'Free', maxTrips: 3, maxAiRequests: 10, maxCollaborators: 1, price: 0, features: ['3 trips', '10 AI requests/month', 'Basic features']),
      PlanLimit(id: 'pro', name: 'Pro', maxTrips: 25, maxAiRequests: 100, maxCollaborators: 5, price: 9.99, features: ['25 trips', '100 AI requests/month', 'Priority support', 'Advanced analytics']),
      PlanLimit(id: 'team', name: 'Team', maxTrips: 100, maxAiRequests: 500, maxCollaborators: 20, price: 24.99, features: ['Unlimited trips', '500 AI requests/month', 'Team collaboration', 'Custom branding']),
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: fallback.length,
      itemBuilder: (_, i) => _buildPlanCard(fallback[i], fallback[i].id == currentId),
    );
  }

  Future<void> _handleUpgrade(String planId) async {
    final billing = ref.read(billingServiceProvider);
    final url = await billing.createCheckoutSession(planId);
    if (url != null) {
      await billing.openCheckoutInBrowser(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade coming soon!')),
      );
    }
  }
}
