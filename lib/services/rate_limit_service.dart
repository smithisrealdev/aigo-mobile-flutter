import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import 'auth_service.dart';

// ──────────────────────────────────────────────
// Rate limit / AI usage service — matches useAIUsage.ts
// ──────────────────────────────────────────────

class AIUsageState {
  final bool canUseAI;
  final int currentUsage;
  final int monthlyLimit;
  final int remainingRequests;
  final double usagePercent;
  final bool isLoading;
  final String? error;

  AIUsageState({
    this.canUseAI = true,
    this.currentUsage = 0,
    this.monthlyLimit = 10,
    this.remainingRequests = 10,
    this.usagePercent = 0,
    this.isLoading = true,
    this.error,
  });

  bool get isNearLimit => usagePercent >= 80;
  bool get isAtLimit => usagePercent >= 100;

  String? get warningMessage {
    if (isAtLimit) {
      return "You've used all $monthlyLimit AI requests this month. Upgrade to continue.";
    }
    if (isNearLimit) {
      return 'You have $remainingRequests AI request${remainingRequests == 1 ? '' : 's'} remaining this month.';
    }
    return null;
  }

  AIUsageState copyWith({
    bool? canUseAI,
    int? currentUsage,
    int? monthlyLimit,
    int? remainingRequests,
    double? usagePercent,
    bool? isLoading,
    String? error,
  }) =>
      AIUsageState(
        canUseAI: canUseAI ?? this.canUseAI,
        currentUsage: currentUsage ?? this.currentUsage,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
        remainingRequests: remainingRequests ?? this.remainingRequests,
        usagePercent: usagePercent ?? this.usagePercent,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class RateLimitService {
  RateLimitService._();
  static final RateLimitService instance = RateLimitService._();

  /// Check if user can use AI — queries usage tables.
  /// Matches website canUseAI / getUserUsage / getUserSubscription.
  Future<AIUsageState> checkAiUsage(String userId) async {
    try {
      // Get user's subscription/plan limits
      final subRes = await SupabaseConfig.client
          .from('user_subscriptions')
          .select('plan_name, ai_requests_limit')
          .eq('user_id', userId)
          .maybeSingle();

      final monthlyLimit =
          subRes?['ai_requests_limit'] as int? ?? 10;

      // Get current month usage
      final now = DateTime.now();
      final monthStart =
          DateTime(now.year, now.month, 1).toIso8601String();

      final usageRes = await SupabaseConfig.client
          .from('ai_usage')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', monthStart);

      final currentUsage = (usageRes as List).length;
      final remaining = (monthlyLimit - currentUsage).clamp(0, monthlyLimit);

      return AIUsageState(
        canUseAI: remaining > 0,
        currentUsage: currentUsage,
        monthlyLimit: monthlyLimit,
        remainingRequests: remaining,
        usagePercent: monthlyLimit > 0
            ? (currentUsage / monthlyLimit) * 100
            : 0,
        isLoading: false,
      );
    } catch (e) {
      return AIUsageState(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Increment AI usage count.
  /// Matches website incrementAIUsage.
  Future<({bool success, int currentUsage, int remaining, String? error})>
      incrementUsage(String userId) async {
    try {
      // First check if can use
      final usage = await checkAiUsage(userId);
      if (!usage.canUseAI) {
        return (
          success: false,
          currentUsage: usage.currentUsage,
          remaining: 0,
          error: 'Usage limit exceeded',
        );
      }

      await SupabaseConfig.client.from('ai_usage').insert({
        'user_id': userId,
        'request_type': 'chat',
        'created_at': DateTime.now().toIso8601String(),
      });

      final newUsage = usage.currentUsage + 1;
      final remaining =
          (usage.monthlyLimit - newUsage).clamp(0, usage.monthlyLimit);

      return (
        success: true,
        currentUsage: newUsage,
        remaining: remaining,
        error: null,
      );
    } catch (e) {
      return (
        success: false,
        currentUsage: 0,
        remaining: 0,
        error: e.toString(),
      );
    }
  }

  /// Check API rate limit (general).
  Future<bool> checkRateLimit({String endpoint = 'default'}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final res = await SupabaseConfig.client
          .from('api_rate_limits')
          .select('requests_count, max_requests, window_start')
          .eq('user_id', userId)
          .eq('endpoint', endpoint)
          .maybeSingle();

      if (res == null) return true;

      final count = res['requests_count'] as int? ?? 0;
      final max = res['max_requests'] as int? ?? 60;
      final windowStart =
          DateTime.tryParse(res['window_start'] as String? ?? '');

      if (windowStart != null) {
        final windowEnd = windowStart.add(const Duration(hours: 1));
        if (DateTime.now().isAfter(windowEnd)) return true;
      }

      return count < max;
    } catch (_) {
      return true; // Fail-open
    }
  }
}

// ── Riverpod providers ──

final rateLimitServiceProvider =
    Provider((_) => RateLimitService.instance);

/// AI usage state provider.
final aiUsageProvider =
    FutureProvider.autoDispose<AIUsageState>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return AIUsageState(
      canUseAI: false,
      isLoading: false,
      error: 'Please sign in to use AI features',
    );
  }
  return RateLimitService.instance.checkAiUsage(user.id);
});
