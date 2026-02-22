import 'package:flutter/foundation.dart';
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

  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  /// Check if user can use AI — calls RPC with fallback.
  /// Returns: {can_use, current_usage, monthly_limit, remaining}
  Future<Map<String, dynamic>> canUseAi() async {
    final uid = _uid;
    if (uid == null) {
      return {'can_use': false, 'current_usage': 0, 'monthly_limit': 0, 'remaining': 0};
    }

    try {
      final result = await SupabaseConfig.client.rpc('can_use_ai', params: {
        'p_user_id': uid,
      });
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('can_use_ai RPC failed, using fallback: $e');
    }

    // Fallback: query tables directly
    final usage = await checkAiUsage(uid);
    return {
      'can_use': usage.canUseAI,
      'current_usage': usage.currentUsage,
      'monthly_limit': usage.monthlyLimit,
      'remaining': usage.remainingRequests,
    };
  }

  /// Increment AI usage after successful AI action.
  /// Returns: {success, current_usage, remaining}
  Future<Map<String, dynamic>> incrementAiUsage() async {
    final uid = _uid;
    if (uid == null) {
      return {'success': false, 'current_usage': 0, 'remaining': 0};
    }

    try {
      final result = await SupabaseConfig.client.rpc('increment_ai_usage', params: {
        'p_user_id': uid,
      });
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('increment_ai_usage RPC failed, using fallback: $e');
    }

    // Fallback: insert directly
    final inc = await incrementUsage(uid);
    return {
      'success': inc.success,
      'current_usage': inc.currentUsage,
      'remaining': inc.remaining,
    };
  }

  /// Detailed usage tracking with operation type and tokens.
  Future<Map<String, dynamic>> incrementUserUsage(String operationType, int tokensUsed) async {
    final uid = _uid;
    if (uid == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    try {
      final result = await SupabaseConfig.client.rpc('increment_user_usage', params: {
        'p_user_id': uid,
        'p_operation_type': operationType,
        'p_tokens_used': tokensUsed,
      });
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('increment_user_usage RPC failed, using fallback: $e');
    }

    // Fallback: insert into ai_usage with extra fields
    try {
      await SupabaseConfig.client.from('ai_usage').insert({
        'user_id': uid,
        'request_type': operationType,
        'tokens_used': tokensUsed,
        'created_at': DateTime.now().toIso8601String(),
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Full quota info for UI.
  /// Returns: {has_quota, current_usage, monthly_limit, remaining, reset_at, tier}
  Future<Map<String, dynamic>> checkUserQuota() async {
    final uid = _uid;
    if (uid == null) {
      return {
        'has_quota': false, 'current_usage': 0, 'monthly_limit': 0,
        'remaining': 0, 'reset_at': null, 'tier': 'free',
      };
    }

    try {
      final result = await SupabaseConfig.client.rpc('check_user_quota', params: {
        'p_user_id': uid,
      });
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('check_user_quota RPC failed, using fallback: $e');
    }

    // Fallback
    final usage = await checkAiUsage(uid);
    final now = DateTime.now();
    final resetAt = DateTime(now.year, now.month + 1, 1);
    return {
      'has_quota': usage.canUseAI,
      'current_usage': usage.currentUsage,
      'monthly_limit': usage.monthlyLimit,
      'remaining': usage.remainingRequests,
      'reset_at': resetAt.toIso8601String(),
      'tier': 'free',
    };
  }

  /// Check if user can use AI — queries usage tables.
  Future<AIUsageState> checkAiUsage(String userId) async {
    try {
      final subRes = await SupabaseConfig.client
          .from('user_subscriptions')
          .select('plan_name, ai_requests_limit')
          .eq('user_id', userId)
          .maybeSingle();

      final monthlyLimit = subRes?['ai_requests_limit'] as int? ?? 10;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

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
        usagePercent: monthlyLimit > 0 ? (currentUsage / monthlyLimit) * 100 : 0,
        isLoading: false,
      );
    } catch (e) {
      return AIUsageState(isLoading: false, error: e.toString());
    }
  }

  /// Increment AI usage count.
  Future<({bool success, int currentUsage, int remaining, String? error})>
      incrementUsage(String userId) async {
    try {
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
      final remaining = (usage.monthlyLimit - newUsage).clamp(0, usage.monthlyLimit);

      return (success: true, currentUsage: newUsage, remaining: remaining, error: null);
    } catch (e) {
      return (success: false, currentUsage: 0, remaining: 0, error: e.toString());
    }
  }

  /// Check API rate limit (general).
  Future<bool> checkRateLimit({String endpoint = 'default'}) async {
    final userId = _uid;
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
      final windowStart = DateTime.tryParse(res['window_start'] as String? ?? '');

      if (windowStart != null) {
        final windowEnd = windowStart.add(const Duration(hours: 1));
        if (DateTime.now().isAfter(windowEnd)) return true;
      }

      return count < max;
    } catch (_) {
      return true; // Fail-open
    }
  }

  // ── API Usage Tracking (api_usage table) ──

  /// Log API usage for tracking/billing purposes.
  Future<void> logApiUsage({
    required String apiName,
    required String endpoint,
    int requestCount = 1,
    double? estimatedCost,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await SupabaseConfig.client.from('api_usage').upsert({
        'api_name': apiName,
        'endpoint': endpoint,
        'request_count': requestCount,
        'estimated_cost': estimatedCost ?? 0,
        'usage_date': today,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'api_name,endpoint,usage_date');
    } catch (e) {
      debugPrint('[RateLimitService] logApiUsage error: $e');
    }
  }

  /// Get API usage stats for a date range.
  Future<List<Map<String, dynamic>>> getApiUsageStats({
    String? apiName,
    int days = 30,
  }) async {
    try {
      final startDate = DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String()
          .substring(0, 10);

      var query = SupabaseConfig.client
          .from('api_usage')
          .select()
          .gte('usage_date', startDate);

      if (apiName != null) {
        query = query.eq('api_name', apiName);
      }

      final data = await query.order('usage_date', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[RateLimitService] getApiUsageStats error: $e');
      return [];
    }
  }
}

// ── Riverpod providers ──

final rateLimitServiceProvider = Provider((_) => RateLimitService.instance);

/// AI usage state provider.
final aiUsageProvider = FutureProvider.autoDispose<AIUsageState>((ref) async {
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

/// AI quota provider (Map with full details, auto-refresh).
final aiQuotaProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return RateLimitService.instance.checkUserQuota();
});

/// Simple boolean: can use AI?
final canUseAiProvider = FutureProvider.autoDispose<bool>((ref) async {
  final result = await RateLimitService.instance.canUseAi();
  return result['can_use'] == true;
});
