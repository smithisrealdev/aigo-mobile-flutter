import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';
import '../models/pending_change.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'offline_service.dart';

// ──────────────────────────────────────────────
// Trip service — CRUD via Supabase client (with offline fallback)
// Matches website direct Supabase CRUD patterns
// ──────────────────────────────────────────────

class TripService {
  TripService._();
  static final TripService instance = TripService._();

  SupabaseClient get _client => SupabaseConfig.client;
  String? get _uid => _client.auth.currentUser?.id;

  OfflineService get _cache => OfflineService.instance;
  bool get _online => ConnectivityService.instance.isOnline;

  // ── Trips (matches website .from('trips') patterns) ──

  Future<List<Trip>> listTrips({int limit = 50, int offset = 0}) async {
    try {
      final data = await _client
          .from('trips')
          .select()
          .eq('user_id', _uid!)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final trips = (data as List).map((e) => Trip.fromJson(e)).toList();
      _cache.cacheTrips(trips);
      return trips;
    } catch (e) {
      debugPrint('TripService.listTrips online failed: $e');
      final cached = _cache.getCachedTrips();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Trip?> getTrip(String id) async {
    try {
      final data =
          await _client.from('trips').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      final trip = Trip.fromJson(data);
      _cache.cacheTripDetail(id, data);
      return trip;
    } catch (e) {
      debugPrint('TripService.getTrip online failed: $e');
      final cached = _cache.getCachedTripDetail(id);
      if (cached != null) return Trip.fromJson(cached);
      rethrow;
    }
  }

  Future<Trip> createTrip(Trip trip) async {
    if (!_online) {
      await _cache.queueChange(PendingChange(
        table: 'trips',
        operation: 'insert',
        data: trip.toInsertJson(),
      ));
      return trip;
    }
    final data = await _client
        .from('trips')
        .insert(trip.toInsertJson())
        .select()
        .single();
    return Trip.fromJson(data);
  }

  Future<Trip> updateTrip(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    final data = await _client
        .from('trips')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Trip.fromJson(data);
  }

  Future<void> deleteTrip(String id) async {
    await _client.from('trips').delete().eq('id', id);
  }

  /// Save a generated trip from itinerary generation response.
  /// Matches website's saveGeneratedTrip pattern.
  Future<Trip> saveGeneratedTrip({
    required String title,
    required String destination,
    required Map<String, dynamic> itineraryData,
    String? startDate,
    String? endDate,
    double? budgetTotal,
    String? budgetCurrency,
    String? coverImage,
  }) async {
    final userId = _uid;
    if (userId == null) throw Exception('Not authenticated');

    final data = await _client
        .from('trips')
        .insert({
          'user_id': userId,
          'title': title,
          'destination': destination,
          'itinerary_data': itineraryData,
          'status': 'completed',
          if (startDate != null) 'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
          if (budgetTotal != null) 'budget_total': budgetTotal,
          if (budgetCurrency != null) 'budget_currency': budgetCurrency,
          if (coverImage != null) 'cover_image': coverImage,
        })
        .select()
        .single();
    return Trip.fromJson(data);
  }

  // ── Manual Expenses ──

  Future<List<ManualExpense>> listExpenses(String tripId) async {
    try {
      final data = await _client
          .from('manual_expenses')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false);
      final expenses =
          (data as List).map((e) => ManualExpense.fromJson(e)).toList();
      _cache.cacheExpenses(tripId, expenses);
      return expenses;
    } catch (e) {
      debugPrint('TripService.listExpenses online failed: $e');
      final cached = _cache.getCachedExpenses(tripId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<ManualExpense> addExpense(ManualExpense expense) async {
    if (!_online) {
      await _cache.queueChange(PendingChange(
        table: 'manual_expenses',
        operation: 'insert',
        data: expense.toInsertJson(),
      ));
      return expense;
    }
    final data = await _client
        .from('manual_expenses')
        .insert(expense.toInsertJson())
        .select()
        .single();
    return ManualExpense.fromJson(data);
  }

  Future<ManualExpense> updateExpense(
      String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('manual_expenses')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return ManualExpense.fromJson(data);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('manual_expenses').delete().eq('id', id);
  }

  // ── Reservations ──

  Future<List<Reservation>> listReservations(String tripId) async {
    final data = await _client
        .from('reservations')
        .select()
        .eq('trip_id', tripId)
        .order('reservation_date');
    return (data as List).map((e) => Reservation.fromJson(e)).toList();
  }

  Future<Reservation> addReservation(Reservation r) async {
    final data = await _client
        .from('reservations')
        .insert(r.toInsertJson())
        .select()
        .single();
    return Reservation.fromJson(data);
  }

  Future<void> deleteReservation(String id) async {
    await _client.from('reservations').delete().eq('id', id);
  }

  // ── Place Comments ──

  Future<List<PlaceComment>> listComments(String tripId,
      {String? placeId}) async {
    var query = _client.from('place_comments').select().eq('trip_id', tripId);
    if (placeId != null) query = query.eq('place_id', placeId);
    final data = await query.order('created_at');
    return (data as List).map((e) => PlaceComment.fromJson(e)).toList();
  }

  Future<PlaceComment> addComment(PlaceComment comment) async {
    final data = await _client
        .from('place_comments')
        .insert(comment.toInsertJson())
        .select()
        .single();
    return PlaceComment.fromJson(data);
  }

  // ── Checklists ──

  Future<List<TripChecklist>> listChecklists(String tripId) async {
    final data = await _client
        .from('trip_checklists')
        .select()
        .eq('trip_id', tripId)
        .order('urgency', ascending: false);
    return (data as List).map((e) => TripChecklist.fromJson(e)).toList();
  }

  Future<TripChecklist> addChecklistItem(TripChecklist item) async {
    final data = await _client
        .from('trip_checklists')
        .insert(item.toInsertJson())
        .select()
        .single();
    return TripChecklist.fromJson(data);
  }

  Future<void> toggleChecklistItem(String id, bool completed) async {
    await _client.from('trip_checklists').update({
      'is_completed': completed,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Alerts ──

  Future<List<TripAlert>> listAlerts(String tripId) async {
    final data = await _client
        .from('trip_alerts')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => TripAlert.fromJson(e)).toList();
  }

  Future<void> markAlertRead(String id) async {
    await _client.from('trip_alerts').update({'is_read': true}).eq('id', id);
  }

  // ── Place Details Cache ──

  Future<PlaceDetailsCache?> getPlaceDetails(String placeKey) async {
    final data = await _client
        .from('place_details_cache')
        .select()
        .eq('place_key', placeKey)
        .maybeSingle();
    if (data == null) return null;
    return PlaceDetailsCache.fromJson(data);
  }

  // ── Destination Images ──

  Future<List<DestinationImage>> getDestinationImages(
      String destinationName) async {
    final data = await _client
        .from('destination_images')
        .select()
        .eq('destination_name', destinationName);
    return (data as List).map((e) => DestinationImage.fromJson(e)).toList();
  }
}

// ──────────────────────────────────────────────
// Riverpod providers
// ──────────────────────────────────────────────

final tripServiceProvider = Provider((_) => TripService.instance);

final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return TripService.instance.listTrips();
});

final tripProvider = FutureProvider.family<Trip?, String>((ref, id) async {
  return TripService.instance.getTrip(id);
});

final tripExpensesProvider =
    FutureProvider.family<List<ManualExpense>, String>((ref, tripId) async {
  return TripService.instance.listExpenses(tripId);
});

// ──────────────────────────────────────────────
// Trip Follows (trip_follows table)
// Mirrors: useTripFollows.ts
// ──────────────────────────────────────────────

class TripFollowService {
  TripFollowService._();
  static final TripFollowService instance = TripFollowService._();

  final _client = SupabaseConfig.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<bool> isFollowing(String tripId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final data = await _client
          .from('trip_follows')
          .select('id')
          .eq('user_id', uid)
          .eq('trip_id', tripId)
          .maybeSingle();
      return data != null;
    } catch (e) {
      debugPrint('TripFollowService.isFollowing error: $e');
      return false;
    }
  }

  Future<void> follow(String tripId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('trip_follows').insert({
        'user_id': uid,
        'trip_id': tripId,
      });
    } catch (e) {
      debugPrint('TripFollowService.follow error: $e');
    }
  }

  Future<void> unfollow(String tripId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client
          .from('trip_follows')
          .delete()
          .eq('user_id', uid)
          .eq('trip_id', tripId);
    } catch (e) {
      debugPrint('TripFollowService.unfollow error: $e');
    }
  }

  Future<void> toggleFollow(String tripId) async {
    final following = await isFollowing(tripId);
    if (following) {
      await unfollow(tripId);
    } else {
      await follow(tripId);
    }
  }
}

final tripFollowServiceProvider =
    Provider((_) => TripFollowService.instance);

final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, tripId) async {
  return TripFollowService.instance.isFollowing(tripId);
});
