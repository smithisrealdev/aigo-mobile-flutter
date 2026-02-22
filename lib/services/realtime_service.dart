import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';

// ──────────────────────────────────────────────
// Realtime service — live subscriptions via Supabase Realtime
// ──────────────────────────────────────────────

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Watch a single trip row for changes.
  Stream<Trip> watchTrip(String tripId) {
    return _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((rows) {
          if (rows.isEmpty) throw Exception('Trip $tripId not found');
          return Trip.fromJson(rows.first);
        });
  }

  /// Watch expenses belonging to a trip.
  Stream<List<ManualExpense>> watchTripExpenses(String tripId) {
    return _client
        .from('manual_expenses')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .map((rows) => rows.map((e) => ManualExpense.fromJson(e)).toList());
  }

  /// Watch comments belonging to a trip.
  Stream<List<PlaceComment>> watchTripComments(String tripId) {
    return _client
        .from('place_comments')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .map((rows) => rows.map((e) => PlaceComment.fromJson(e)).toList());
  }
}

// ──────────────────────────────────────────────
// Riverpod providers
// ──────────────────────────────────────────────

final realtimeServiceProvider = Provider((_) => RealtimeService.instance);

/// Stream provider for a single trip (realtime).
final realtimeTripProvider =
    StreamProvider.family<Trip, String>((ref, tripId) {
  return RealtimeService.instance.watchTrip(tripId);
});

/// Stream provider for trip expenses (realtime).
final realtimeTripExpensesProvider =
    StreamProvider.family<List<ManualExpense>, String>((ref, tripId) {
  return RealtimeService.instance.watchTripExpenses(tripId);
});

/// Stream provider for trip comments (realtime).
final realtimeTripCommentsProvider =
    StreamProvider.family<List<PlaceComment>, String>((ref, tripId) {
  return RealtimeService.instance.watchTripComments(tripId);
});
