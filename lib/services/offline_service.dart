import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';
import '../models/pending_change.dart';

// ──────────────────────────────────────────────
// Offline service — Hive-based cache + pending sync queue
// ──────────────────────────────────────────────

class OfflineService {
  OfflineService._();
  static final OfflineService instance = OfflineService._();

  static const _tripsBoxName = 'trips_cache';
  static const _tripDetailsBoxName = 'trip_details_cache';
  static const _expensesBoxName = 'expenses_cache';
  static const _pendingBoxName = 'pending_changes';

  late Box<String> _tripsBox;
  late Box<String> _tripDetailsBox;
  late Box<String> _expensesBox;
  late Box<String> _pendingBox;

  /// Call once during app startup (after Hive.initFlutter).
  Future<void> init() async {
    _tripsBox = await Hive.openBox<String>(_tripsBoxName);
    _tripDetailsBox = await Hive.openBox<String>(_tripDetailsBoxName);
    _expensesBox = await Hive.openBox<String>(_expensesBoxName);
    _pendingBox = await Hive.openBox<String>(_pendingBoxName);
  }

  // ── Trips cache ──

  Future<void> cacheTrips(List<Trip> trips) async {
    final encoded =
        jsonEncode(trips.map((t) => t.toInsertJson()..['id'] = t.id..['user_id'] = t.userId).toList());
    await _tripsBox.put('all', encoded);
  }

  List<Trip>? getCachedTrips() {
    final raw = _tripsBox.get('all');
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Trip detail cache ──

  Future<void> cacheTripDetail(String tripId, Map<String, dynamic> data) async {
    await _tripDetailsBox.put(tripId, jsonEncode(data));
  }

  Map<String, dynamic>? getCachedTripDetail(String tripId) {
    final raw = _tripDetailsBox.get(tripId);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Expenses cache ──

  Future<void> cacheExpenses(String tripId, List<ManualExpense> expenses) async {
    final encoded = jsonEncode(expenses.map((e) => e.toInsertJson()..['id'] = e.id..['user_id'] = e.userId).toList());
    await _expensesBox.put(tripId, encoded);
  }

  List<ManualExpense>? getCachedExpenses(String tripId) {
    final raw = _expensesBox.get(tripId);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => ManualExpense.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Pending changes queue ──

  Future<void> queueChange(PendingChange change) async {
    final key = DateTime.now().microsecondsSinceEpoch.toString();
    await _pendingBox.put(key, change.encode());
  }

  Future<void> syncPendingChanges() async {
    final client = SupabaseConfig.client;
    final keys = _pendingBox.keys.toList();

    for (final key in keys) {
      final raw = _pendingBox.get(key);
      if (raw == null) continue;

      try {
        final change = PendingChange.decode(raw);
        switch (change.operation) {
          case 'insert':
            await client.from(change.table).insert(change.data);
            break;
          case 'update':
            final id = change.data.remove('id');
            if (id != null) {
              await client.from(change.table).update(change.data).eq('id', id);
            }
            break;
          case 'delete':
            final id = change.data['id'];
            if (id != null) {
              await client.from(change.table).delete().eq('id', id);
            }
            break;
        }
        await _pendingBox.delete(key);
      } catch (e) {
        debugPrint('OfflineService: failed to sync change $key: $e');
        // Leave in queue for next attempt.
      }
    }
  }

  bool get hasPendingChanges => _pendingBox.isNotEmpty;

  Future<void> clearCache() async {
    await _tripsBox.clear();
    await _tripDetailsBox.clear();
    await _expensesBox.clear();
    await _pendingBox.clear();
  }
}
