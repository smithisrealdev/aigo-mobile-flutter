import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Packing List Service
// Edge function: generate-packing-list
// ──────────────────────────────────────────────

class PackingItem {
  final String name;
  final String category;
  final String? reason;
  final bool essential;
  final int quantity;

  PackingItem({
    required this.name,
    required this.category,
    this.reason,
    this.essential = false,
    this.quantity = 1,
  });

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'general',
        reason: json['reason'] as String?,
        essential: json['essential'] as bool? ?? false,
        quantity: json['quantity'] as int? ?? 1,
      );
}

class PackingListResult {
  final List<PackingItem> items;
  final String? tip;
  final String? weatherNote;

  PackingListResult({
    this.items = const [],
    this.tip,
    this.weatherNote,
  });

  factory PackingListResult.fromJson(Map<String, dynamic> json) =>
      PackingListResult(
        items: ((json['items'] as List<dynamic>?) ?? [])
            .map((i) => PackingItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        tip: json['tip'] as String?,
        weatherNote: json['weatherNote'] as String?,
      );
}

class PackingService {
  PackingService._();
  static final instance = PackingService._();

  final _client = SupabaseConfig.client;

  /// Generate AI packing list for a trip.
  Future<PackingListResult> generatePackingList({
    required String destination,
    required int totalDays,
    String? startDate,
    String? tripCategory,
    List<String>? activities,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'generate-packing-list',
        body: {
          'destination': destination,
          'totalDays': totalDays,
          if (startDate != null) 'startDate': startDate,
          if (tripCategory != null) 'category': tripCategory,
          if (activities != null) 'activities': activities,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data != null) {
        return PackingListResult.fromJson(data);
      }
    } catch (e) {
      debugPrint('[PackingService] generatePackingList error: $e');
    }
    return PackingListResult();
  }
}

// ── Riverpod Providers ──

final packingListProvider = FutureProvider.family<PackingListResult,
    ({String destination, int totalDays, String? startDate, String? category})>(
  (ref, params) async {
    return PackingService.instance.generatePackingList(
      destination: params.destination,
      totalDays: params.totalDays,
      startDate: params.startDate,
      tripCategory: params.category,
    );
  },
);
