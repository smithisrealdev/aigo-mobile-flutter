import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Saved Flight Searches Service
// Mirrors: useSavedFlightSearches.ts
// ──────────────────────────────────────────────

class SavedFlightSearch {
  final String id;
  final String name;
  final String originCode;
  final String? originName;
  final String destinationCode;
  final String? destinationName;
  final String travelClass;
  final int adults;
  final String createdAt;

  SavedFlightSearch({
    required this.id,
    required this.name,
    required this.originCode,
    this.originName,
    required this.destinationCode,
    this.destinationName,
    this.travelClass = 'ECONOMY',
    this.adults = 1,
    required this.createdAt,
  });

  factory SavedFlightSearch.fromJson(Map<String, dynamic> json) =>
      SavedFlightSearch(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        originCode: json['origin_code'] as String,
        originName: json['origin_name'] as String?,
        destinationCode: json['destination_code'] as String,
        destinationName: json['destination_name'] as String?,
        travelClass: json['travel_class'] as String? ?? 'ECONOMY',
        adults: json['adults'] as int? ?? 1,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class SavedSearchService {
  SavedSearchService._();
  static final instance = SavedSearchService._();

  final _client = SupabaseConfig.client;

  Future<List<SavedFlightSearch>> fetchSavedSearches() async {
    try {
      final data = await _client
          .from('saved_flight_searches')
          .select()
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => SavedFlightSearch.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SavedSearchService] fetchSavedSearches error: $e');
      return [];
    }
  }

  Future<SavedFlightSearch?> saveSearch({
    required String name,
    required String originCode,
    String? originName,
    required String destinationCode,
    String? destinationName,
    String travelClass = 'ECONOMY',
    int adults = 1,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _client
          .from('saved_flight_searches')
          .insert({
            'user_id': userId,
            'name': name,
            'origin_code': originCode,
            'origin_name': originName,
            'destination_code': destinationCode,
            'destination_name': destinationName,
            'travel_class': travelClass,
            'adults': adults,
          })
          .select()
          .single();
      return SavedFlightSearch.fromJson(data);
    } catch (e) {
      debugPrint('[SavedSearchService] saveSearch error: $e');
      return null;
    }
  }

  Future<bool> deleteSearch(String id) async {
    try {
      await _client.from('saved_flight_searches').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[SavedSearchService] deleteSearch error: $e');
      return false;
    }
  }
}

// ── Riverpod Providers ──

final savedFlightSearchesProvider =
    FutureProvider<List<SavedFlightSearch>>((ref) async {
  return SavedSearchService.instance.fetchSavedSearches();
});
