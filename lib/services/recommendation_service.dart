import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// AI Recommendation Service
// Mirrors: useAIRecommendation.ts
// ──────────────────────────────────────────────

class RecommendationItem {
  final String emoji;
  final String label;
  final String value;
  final String? detail;

  RecommendationItem({
    required this.emoji,
    required this.label,
    required this.value,
    this.detail,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) =>
      RecommendationItem(
        emoji: json['emoji'] as String? ?? '✨',
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
        detail: json['detail'] as String?,
      );
}

class StructuredRecommendation {
  final List<RecommendationItem> items;
  final String? tip;

  StructuredRecommendation({required this.items, this.tip});

  factory StructuredRecommendation.fromJson(Map<String, dynamic> json) =>
      StructuredRecommendation(
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((i) =>
                RecommendationItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        tip: json['tip'] as String?,
      );
}

class AIRecommendationResult {
  final String? recommendation;
  final StructuredRecommendation? structured;

  AIRecommendationResult({this.recommendation, this.structured});
}

class RecommendationService {
  RecommendationService._();
  static final instance = RecommendationService._();

  final _client = SupabaseConfig.client;

  /// Get AI recommendation for flights.
  Future<AIRecommendationResult> getFlightRecommendation(
      List<Map<String, dynamic>> flights) async {
    return _getRecommendation(type: 'flights', data: {'flights': flights});
  }

  /// Get AI recommendation for hotels.
  Future<AIRecommendationResult> getHotelRecommendation(
      List<Map<String, dynamic>> hotels) async {
    return _getRecommendation(type: 'hotels', data: {'hotels': hotels});
  }

  /// Get personalized recommendations based on user profile.
  Future<AIRecommendationResult> getPersonalizedRecommendations() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return AIRecommendationResult();
      }

      // Fetch user's travel style
      final profile = await _client
          .from('profiles')
          .select('travel_style')
          .eq('id', userId)
          .maybeSingle();

      final travelStyle = profile?['travel_style'] as String?;

      return _getRecommendation(
        type: 'personalized',
        data: {
          if (travelStyle != null) 'travelStyle': travelStyle,
        },
      );
    } catch (e) {
      debugPrint('[RecommendationService] getPersonalized error: $e');
      return AIRecommendationResult();
    }
  }

  Future<AIRecommendationResult> _getRecommendation({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'recommend-deals',
        body: {...data, 'type': type},
      );

      final result = response.data as Map<String, dynamic>?;
      return AIRecommendationResult(
        recommendation: result?['recommendation'] as String?,
        structured: result?['structured'] != null
            ? StructuredRecommendation.fromJson(
                result!['structured'] as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      debugPrint('[RecommendationService] _getRecommendation error: $e');
      return AIRecommendationResult();
    }
  }
}

// ── Riverpod Providers ──

final aiRecommendationsProvider =
    FutureProvider<AIRecommendationResult>((ref) async {
  return RecommendationService.instance.getPersonalizedRecommendations();
});
