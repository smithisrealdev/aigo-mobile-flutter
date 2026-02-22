import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Smart Replan + AI Swap Service
// Mirrors: useSmartReplan.ts, useAIUsage.ts, useFeatureGating.ts
// ──────────────────────────────────────────────

class ReplanIssue {
  final String title;
  final String message;
  final String priority; // high | medium | low
  final String type; // weather | closure | traffic | schedule | crowd | budget | fatigue | preference | other

  const ReplanIssue({
    required this.title,
    required this.message,
    this.priority = 'medium',
    this.type = 'other',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'priority': priority,
        'type': type,
      };
}

class ReplanResult {
  final bool success;
  final String summary;
  final int? affectedDayIndex;
  final List<Map<String, dynamic>> updatedPlaces;
  final List<Map<String, dynamic>> newSuggestions;
  final List<String> removePlaceIds;
  final List<String> tips;

  ReplanResult({
    required this.success,
    required this.summary,
    this.affectedDayIndex,
    this.updatedPlaces = const [],
    this.newSuggestions = const [],
    this.removePlaceIds = const [],
    this.tips = const [],
  });

  factory ReplanResult.fromJson(Map<String, dynamic> json) => ReplanResult(
        success: json['success'] as bool? ?? false,
        summary: json['summary'] as String? ?? '',
        affectedDayIndex: json['affectedDayIndex'] as int?,
        updatedPlaces: (json['updatedPlaces'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        newSuggestions: (json['newSuggestions'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [],
        removePlaceIds: (json['removePlaceIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        tips:
            (json['tips'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class NearbyPlaceResult {
  final String id;
  final String name;
  final String category;
  final String? description;
  final double? lat;
  final double? lng;
  final String? address;
  final String? duration;
  final double? cost;
  final String? currency;
  final String? priceLevel;

  NearbyPlaceResult({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.lat,
    this.lng,
    this.address,
    this.duration,
    this.cost,
    this.currency,
    this.priceLevel,
  });

  factory NearbyPlaceResult.fromJson(Map<String, dynamic> json) =>
      NearbyPlaceResult(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String?,
        lat: (json['lat'] as num?)?.toDouble() ??
            (json['coordinates'] is Map
                ? (json['coordinates']['lat'] as num?)?.toDouble()
                : null),
        lng: (json['lng'] as num?)?.toDouble() ??
            (json['coordinates'] is Map
                ? (json['coordinates']['lng'] as num?)?.toDouble()
                : null),
        address: json['address'] as String?,
        duration: json['duration'] as String?,
        cost: (json['cost'] is Map
            ? (json['cost']['amount'] as num?)?.toDouble()
            : (json['cost'] as num?)?.toDouble()),
        currency: json['cost'] is Map
            ? json['cost']['currency'] as String?
            : json['currency'] as String?,
        priceLevel: json['priceLevel'] as String?,
      );
}

class AIUsageInfo {
  final bool canUse;
  final int currentUsage;
  final int monthlyLimit;
  final int remaining;

  const AIUsageInfo({
    required this.canUse,
    required this.currentUsage,
    required this.monthlyLimit,
    required this.remaining,
  });
}

class ReplanService {
  ReplanService._();
  static final ReplanService instance = ReplanService._();

  final _client = SupabaseConfig.client;
  String? get _uid => _client.auth.currentUser?.id;

  // ── AI Quota Check ──

  Future<AIUsageInfo> checkAIQuota() async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const AIUsageInfo(
            canUse: false, currentUsage: 0, monthlyLimit: 0, remaining: 0);
      }

      // Try can_use_ai RPC first
      try {
        final result = await _client.rpc('can_use_ai', params: {'p_user_id': uid});
        if (result is List && result.isNotEmpty) {
          final row = result[0] as Map<String, dynamic>;
          final canUse = row['can_use'] as bool? ?? true;
          final current = (row['current_usage'] as num?)?.toInt() ?? 0;
          final limit = (row['monthly_limit'] as num?)?.toInt() ?? 10;
          return AIUsageInfo(
            canUse: canUse,
            currentUsage: current,
            monthlyLimit: limit,
            remaining: (limit - current).clamp(0, limit),
          );
        }
      } catch (e) {
        debugPrint('can_use_ai RPC not available, falling back: $e');
      }

      // Fallback: check ai_usage + plan_limits
      try {
        final now = DateTime.now();
        final monthStart =
            DateTime(now.year, now.month, 1).toIso8601String();

        final usage = await _client
            .from('ai_usage')
            .select('id')
            .eq('user_id', uid)
            .gte('created_at', monthStart);

        final currentUsage = (usage as List).length;
        const defaultLimit = 10;

        return AIUsageInfo(
          canUse: currentUsage < defaultLimit,
          currentUsage: currentUsage,
          monthlyLimit: defaultLimit,
          remaining: (defaultLimit - currentUsage).clamp(0, defaultLimit),
        );
      } catch (e) {
        debugPrint('ai_usage fallback failed: $e');
        // Permissive on error
        return const AIUsageInfo(
            canUse: true, currentUsage: 0, monthlyLimit: 10, remaining: 10);
      }
    } catch (e) {
      debugPrint('checkAIQuota error: $e');
      return const AIUsageInfo(
          canUse: true, currentUsage: 0, monthlyLimit: 10, remaining: 10);
    }
  }

  Future<void> incrementAIUsage() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _client.rpc('increment_ai_usage', params: {'p_user_id': uid});
    } catch (e) {
      debugPrint('increment_ai_usage RPC failed, manual insert: $e');
      try {
        await _client.from('ai_usage').insert({
          'user_id': uid,
          'feature': 'replan',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e2) {
        debugPrint('Manual ai_usage insert failed: $e2');
      }
    }
  }

  // ── Smart Replan ──

  Future<ReplanResult> smartReplan({
    required ReplanIssue issue,
    required Map<String, dynamic> tripData,
    required int affectedDayIndex,
  }) async {
    // Check quota first
    final quota = await checkAIQuota();
    if (!quota.canUse) {
      return ReplanResult(
        success: false,
        summary: 'AI usage limit reached. Upgrade your plan for more requests.',
      );
    }

    try {
      final days = tripData['days'] ?? tripData['itinerary']?['days'] ?? [];
      final daysList = days is List ? days : [];
      final affectedDay =
          affectedDayIndex < daysList.length ? daysList[affectedDayIndex] : null;

      final response = await _client.functions.invoke(
        'smart-replan',
        body: {
          'issue': issue.toJson(),
          'currentItinerary': {
            'title': tripData['title'] ?? '',
            'destination': tripData['destination'] ?? '',
            'days': daysList,
          },
          'affectedDay': affectedDay ?? {},
        },
      );

      if (response.status != 200) {
        throw Exception('Replan failed with status ${response.status}');
      }

      await incrementAIUsage();

      final data = response.data as Map<String, dynamic>? ?? {};
      return ReplanResult.fromJson(data);
    } catch (e) {
      debugPrint('smartReplan error: $e');
      return ReplanResult(success: false, summary: 'Replan failed: $e');
    }
  }

  // ── AI Swap (Nearby Places) ──

  Future<List<NearbyPlaceResult>> suggestAlternatives({
    required String placeId,
    required String placeName,
    required String category,
    required String destination,
    double? lat,
    double? lng,
  }) async {
    final quota = await checkAIQuota();
    if (!quota.canUse) return [];

    try {
      final response = await _client.functions.invoke(
        'nearby-places',
        body: {
          'placeId': placeId,
          'placeName': placeName,
          'category': category,
          'destination': destination,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );

      if (response.status != 200) return [];

      await incrementAIUsage();

      final data = response.data;
      if (data is Map && data['places'] is List) {
        return (data['places'] as List)
            .map((e) =>
                NearbyPlaceResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is List) {
        return data
            .map((e) =>
                NearbyPlaceResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('suggestAlternatives error: $e');
      return [];
    }
  }

  // ── Full Trip Replan ──

  Future<ReplanResult> fullTripReplan({
    required String tripId,
    required Map<String, dynamic> tripData,
    String reason = 'User requested full replan',
  }) async {
    return smartReplan(
      issue: ReplanIssue(
        title: 'Full Trip Replan',
        message: reason,
        priority: 'high',
        type: 'preference',
      ),
      tripData: tripData,
      affectedDayIndex: 0,
    );
  }

  // ── Per-Day Replan ──

  Future<ReplanResult> replanDay({
    required String tripId,
    required Map<String, dynamic> tripData,
    required int dayIndex,
    String reason = 'User requested day replan',
    String issueType = 'preference',
  }) async {
    return smartReplan(
      issue: ReplanIssue(
        title: 'Day ${dayIndex + 1} Replan',
        message: reason,
        priority: 'medium',
        type: issueType,
      ),
      tripData: tripData,
      affectedDayIndex: dayIndex,
    );
  }
}

// ── Providers ──

final replanServiceProvider = Provider<ReplanService>((_) => ReplanService.instance);

final aiQuotaProvider = FutureProvider<AIUsageInfo>((ref) async {
  return ReplanService.instance.checkAIQuota();
});
