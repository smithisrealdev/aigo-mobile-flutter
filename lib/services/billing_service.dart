import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/supabase_config.dart';
import '../models/billing_models.dart';

/// Billing / subscription service via Supabase + Stripe.
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  /// Get current user's plan from `plan_limits`.
  Future<PlanLimit?> getCurrentPlan() async {
    try {
      final sub = await SupabaseConfig.client
          .from('user_subscriptions')
          .select('plan_id')
          .eq('user_id', _uid!)
          .maybeSingle();

      final planId = sub?['plan_id'] as String? ?? 'free';

      final data = await SupabaseConfig.client
          .from('plan_limits')
          .select()
          .eq('id', planId)
          .maybeSingle();

      if (data == null) return _defaultFreePlan;
      return PlanLimit.fromJson(data);
    } catch (e) {
      debugPrint('BillingService.getCurrentPlan failed: $e');
      return _defaultFreePlan;
    }
  }

  /// Get current user's subscription details.
  Future<UserSubscription?> getCurrentSubscription() async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final data = await SupabaseConfig.client
          .from('user_subscriptions')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (data == null) return null;
      return UserSubscription.fromJson(data);
    } catch (e) {
      debugPrint('BillingService.getCurrentSubscription failed: $e');
      return null;
    }
  }

  /// Get plan limits by plan ID.
  Future<PlanLimit?> getPlanLimits(String planId) async {
    try {
      final data = await SupabaseConfig.client
          .from('plan_limits')
          .select()
          .eq('id', planId)
          .maybeSingle();

      if (data == null) return null;
      return PlanLimit.fromJson(data);
    } catch (e) {
      debugPrint('BillingService.getPlanLimits failed: $e');
      return null;
    }
  }

  /// Get payment history.
  Future<List<PaymentRecord>> getPaymentHistory() async {
    try {
      final data = await SupabaseConfig.client
          .from('payment_history')
          .select()
          .eq('user_id', _uid!)
          .order('created_at', ascending: false);
      return (data as List).map((e) => PaymentRecord.fromJson(e)).toList();
    } catch (e) {
      debugPrint('BillingService.getPaymentHistory failed: $e');
      return [];
    }
  }

  /// Create a Stripe checkout session via edge function.
  Future<String?> createCheckoutSession(String planId) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'stripe-billing',
        body: {
          'action': 'create_checkout',
          'plan_id': planId,
          'user_id': _uid,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      return data?['checkout_url'] as String?;
    } catch (e) {
      debugPrint('BillingService.createCheckoutSession failed: $e');
      return null;
    }
  }

  /// Open Stripe checkout URL in browser.
  Future<void> openCheckoutInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Cancel current subscription.
  Future<bool> cancelSubscription() async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'stripe-billing',
        body: {
          'action': 'cancel',
          'user_id': _uid,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      return data?['success'] == true;
    } catch (e) {
      debugPrint('BillingService.cancelSubscription failed: $e');
      return false;
    }
  }

  static final _defaultFreePlan = PlanLimit(
    id: 'free',
    name: 'Free',
    maxTrips: 3,
    maxAiRequests: 10,
    maxCollaborators: 1,
    price: 0,
    features: ['3 trips', '10 AI requests/month', 'Basic features'],
  );
}

// ── Riverpod providers ──

final billingServiceProvider = Provider((_) => BillingService.instance);

final currentPlanProvider = FutureProvider<PlanLimit?>((ref) async {
  return BillingService.instance.getCurrentPlan();
});

final userSubscriptionProvider = FutureProvider<UserSubscription?>((ref) async {
  return BillingService.instance.getCurrentSubscription();
});

final paymentHistoryProvider = FutureProvider<List<PaymentRecord>>((ref) async {
  return BillingService.instance.getPaymentHistory();
});
