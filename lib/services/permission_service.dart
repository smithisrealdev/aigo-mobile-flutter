import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Centralized Permission Service
// ──────────────────────────────────────────────

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  final _client = SupabaseConfig.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Get user's role in a trip: 'owner' | 'editor' | 'viewer' | 'none'
  Future<String> getTripRole(String tripId) async {
    final uid = _uid;
    if (uid == null) return 'none';

    try {
      final result = await _client.rpc('get_trip_role', params: {
        '_trip_id': tripId,
        '_user_id': uid,
      });
      if (result is String && result.isNotEmpty) return result;
      if (result is Map && result['role'] is String) return result['role'];
    } catch (e) {
      debugPrint('get_trip_role RPC failed, using fallback: $e');
    }

    // Fallback: check trips.user_id for owner, then trip_members
    return _getTripRoleFallback(tripId, uid);
  }

  Future<String> _getTripRoleFallback(String tripId, String uid) async {
    try {
      // Check if user is trip owner
      final trip = await _client
          .from('trips')
          .select('user_id')
          .eq('id', tripId)
          .maybeSingle();
      if (trip != null && trip['user_id'] == uid) return 'owner';

      // Check trip_members
      final member = await _client
          .from('trip_members')
          .select('role')
          .eq('trip_id', tripId)
          .eq('user_id', uid)
          .maybeSingle();
      if (member != null && member['role'] is String) {
        return member['role'] as String;
      }
      return 'none';
    } catch (e) {
      debugPrint('PermissionService._getTripRoleFallback error: $e');
      return 'none';
    }
  }

  /// Check if user can edit a trip (owner or editor).
  Future<bool> canEditTrip(String tripId) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final result = await _client.rpc('can_edit_trip', params: {
        '_trip_id': tripId,
        '_user_id': uid,
      });
      if (result is bool) return result;
      if (result is Map && result['can_edit'] is bool) return result['can_edit'];
    } catch (e) {
      debugPrint('can_edit_trip RPC failed, using fallback: $e');
    }

    final role = await getTripRole(tripId);
    return role == 'owner' || role == 'editor';
  }

  /// Check if user is a member of the trip (any role).
  Future<bool> isTripMember(String tripId) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final result = await _client.rpc('is_trip_member', params: {
        '_trip_id': tripId,
        '_user_id': uid,
      });
      if (result is bool) return result;
    } catch (e) {
      debugPrint('is_trip_member RPC failed, using fallback: $e');
    }

    final role = await getTripRole(tripId);
    return role != 'none';
  }

  /// Check if user is the trip owner.
  Future<bool> isTripOwner(String tripId) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final result = await _client.rpc('is_trip_owner', params: {
        '_trip_id': tripId,
        '_user_id': uid,
      });
      if (result is bool) return result;
    } catch (e) {
      debugPrint('is_trip_owner RPC failed, using fallback: $e');
    }

    final role = await getTripRole(tripId);
    return role == 'owner';
  }

  /// Permission matrix helpers
  bool canViewItinerary(String role) => role != 'none';
  bool canEditActivities(String role) => role == 'owner' || role == 'editor';
  bool canAiReplan(String role) => role == 'owner' || role == 'editor';
  bool canAddExpenses(String role) => role == 'owner' || role == 'editor';
  bool canManageMembers(String role) => role == 'owner';
  bool canDeleteTrip(String role) => role == 'owner';
  bool canShareTrip(String role) => role == 'owner';
}

// ── Riverpod Providers ──

final permissionServiceProvider =
    Provider((_) => PermissionService.instance);

/// Trip role provider — returns 'owner' | 'editor' | 'viewer' | 'none'
final tripRoleProvider =
    FutureProvider.family<String, String>((ref, tripId) async {
  return PermissionService.instance.getTripRole(tripId);
});

/// Can edit trip provider
final canEditTripProvider =
    FutureProvider.family<bool, String>((ref, tripId) async {
  return PermissionService.instance.canEditTrip(tripId);
});
