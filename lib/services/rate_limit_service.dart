import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Rate limit service — check usage before AI calls
// ──────────────────────────────────────────────

class UsageInfo {
  final int used;
  final int limit;
  final String plan;
  final bool canUse;

  UsageInfo({
    required this.used,
    required this.limit,
    required this.plan,
  }) : canUse = used < limit;

  double get usagePercent => limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
  int get remaining => (limit - used).clamp(0, limit);
}

class RateLimitService {
  final _client = SupabaseConfig.client;

  /// Check current AI usage for the authenticated user.
  Future<UsageInfo> checkAiUsage() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Get user's plan limits
    final planRes = await _client
        .from('plan_limits')
        .select('plan_name, ai_requests_limit')
        .eq('user_id', userId)
        .maybeSingle();

    final plan = planRes?['plan_name'] as String? ?? 'free';
    final limit = planRes?['ai_requests_limit'] as int? ?? 10;

    // Get current month usage
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

    final usageRes = await _client
        .from('ai_usage')
        .select('id')
        .eq('user_id', userId)
        .gte('created_at', monthStart);

    final used = (usageRes as List).length;

    return UsageInfo(used: used, limit: limit, plan: plan);
  }

  /// Check API rate limit (general).
  Future<bool> checkRateLimit({String endpoint = 'default'}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final res = await _client
          .from('api_rate_limits')
          .select('requests_count, max_requests, window_start')
          .eq('user_id', userId)
          .eq('endpoint', endpoint)
          .maybeSingle();

      if (res == null) return true; // No limit record = allowed

      final count = res['requests_count'] as int? ?? 0;
      final max = res['max_requests'] as int? ?? 60;
      final windowStart = DateTime.tryParse(res['window_start'] as String? ?? '');

      // Check if window has expired (1 hour window)
      if (windowStart != null) {
        final windowEnd = windowStart.add(const Duration(hours: 1));
        if (DateTime.now().isAfter(windowEnd)) return true; // Window reset
      }

      return count < max;
    } catch (_) {
      return true; // Allow on error (fail-open for UX)
    }
  }

  /// Record an AI usage event.
  Future<void> recordUsage({
    required String requestType,
    int tokensUsed = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('ai_usage').insert({
      'user_id': userId,
      'request_type': requestType,
      'tokens_used': tokensUsed,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

// ── Riverpod providers ──

final rateLimitServiceProvider = Provider<RateLimitService>((ref) {
  return RateLimitService();
});

/// Async provider to fetch current usage (auto-refresh).
final aiUsageProvider = FutureProvider.autoDispose<UsageInfo>((ref) async {
  final svc = ref.watch(rateLimitServiceProvider);
  return svc.checkAiUsage();
});
