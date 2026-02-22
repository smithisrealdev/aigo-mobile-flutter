import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Trip Collaboration Service
// Mirrors: useTripMembers.ts, useTripRole.ts
// ──────────────────────────────────────────────

/// Invitation status values.
enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired;

  static InvitationStatus fromString(String s) {
    switch (s) {
      case 'accepted': return InvitationStatus.accepted;
      case 'declined': return InvitationStatus.declined;
      case 'expired': return InvitationStatus.expired;
      default: return InvitationStatus.pending;
    }
  }
}

class TripMember {
  final String id;
  final String tripId;
  final String? userId;
  final String role; // owner | editor | viewer
  final String? invitedEmail;
  final String status; // pending | accepted | declined | expired
  final String? createdAt;

  TripMember({
    required this.id,
    required this.tripId,
    this.userId,
    required this.role,
    this.invitedEmail,
    this.status = 'pending',
    this.createdAt,
  });

  factory TripMember.fromJson(Map<String, dynamic> json) => TripMember(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        userId: json['user_id'] as String?,
        role: json['role'] as String? ?? 'viewer',
        invitedEmail: json['invited_email'] as String?,
        status: json['status'] as String? ?? 'pending',
        createdAt: json['created_at'] as String?,
      );

  InvitationStatus get invitationStatus => InvitationStatus.fromString(status);
}

class CollaborationService {
  CollaborationService._();
  static final CollaborationService instance = CollaborationService._();

  final _client = SupabaseConfig.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<TripMember>> getMembers(String tripId) async {
    try {
      final data = await _client
          .from('trip_members')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: true);
      return (data as List).map((e) => TripMember.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CollaborationService.getMembers error: $e');
      return [];
    }
  }

  Future<TripMember?> inviteByEmail({
    required String tripId,
    required String email,
    String role = 'editor',
  }) async {
    try {
      final data = await _client
          .from('trip_members')
          .insert({
            'trip_id': tripId,
            'invited_email': email,
            'role': role,
            'status': 'pending',
          })
          .select()
          .single();
      return TripMember.fromJson(data);
    } catch (e) {
      debugPrint('CollaborationService.inviteByEmail error: $e');
      return null;
    }
  }

  /// Accept an invitation — sets status to accepted and links user_id.
  Future<void> acceptInvitation(String memberId) async {
    try {
      await _client
          .from('trip_members')
          .update({'status': 'accepted', 'user_id': _uid})
          .eq('id', memberId);
    } catch (e) {
      debugPrint('CollaborationService.acceptInvitation error: $e');
    }
  }

  /// Decline an invitation.
  Future<void> declineInvitation(String memberId) async {
    try {
      await _client
          .from('trip_members')
          .update({'status': 'declined'})
          .eq('id', memberId);
    } catch (e) {
      debugPrint('CollaborationService.declineInvitation error: $e');
    }
  }

  /// Remove a member from a trip (owner only).
  Future<void> removeMember(String memberId) async {
    try {
      await _client.from('trip_members').delete().eq('id', memberId);
    } catch (e) {
      debugPrint('CollaborationService.removeMember error: $e');
    }
  }

  /// Update a member's role (owner only).
  Future<void> updateMemberRole(String memberId, String newRole) async {
    try {
      await _client
          .from('trip_members')
          .update({'role': newRole})
          .eq('id', memberId);
    } catch (e) {
      debugPrint('CollaborationService.updateMemberRole error: $e');
    }
  }

  /// Get the current user's role for a trip.
  Future<String?> getTripRole(String tripId) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final result = await _client.rpc('get_trip_role', params: {
        'p_trip_id': tripId,
        'p_user_id': uid,
      });
      if (result is String) return result;
      if (result is Map) return result['role'] as String?;
    } catch (e) {
      debugPrint('get_trip_role RPC failed, fallback: $e');
    }

    // Fallback: check trips.user_id then trip_members
    try {
      final trip = await _client
          .from('trips')
          .select('user_id')
          .eq('id', tripId)
          .maybeSingle();
      if (trip != null && trip['user_id'] == uid) return 'owner';

      final data = await _client
          .from('trip_members')
          .select('role')
          .eq('trip_id', tripId)
          .eq('user_id', uid)
          .maybeSingle();
      return data?['role'] as String?;
    } catch (e2) {
      debugPrint('CollaborationService.getTripRole fallback error: $e2');
      return null;
    }
  }

  Future<bool> canEditTrip(String tripId) async {
    final role = await getTripRole(tripId);
    return role == 'owner' || role == 'editor';
  }

  Future<bool> isTripMember(String tripId) async {
    final role = await getTripRole(tripId);
    return role != null;
  }

  /// Get pending invitations for the current user.
  Future<List<TripMember>> getPendingInvitations() async {
    final uid = _uid;
    final email = _client.auth.currentUser?.email;
    if (uid == null && email == null) return [];

    try {
      final query = _client
          .from('trip_members')
          .select()
          .eq('status', 'pending');

      // Match by user_id or invited_email
      List<dynamic> data;
      if (email != null) {
        data = await query.eq('invited_email', email);
      } else {
        data = await query.eq('user_id', uid!);
      }
      return (data).map((e) => TripMember.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('CollaborationService.getPendingInvitations error: $e');
      return [];
    }
  }
}

// ── Providers ──

final collaborationServiceProvider =
    Provider<CollaborationService>((_) => CollaborationService.instance);

final tripMembersProvider =
    FutureProvider.family<List<TripMember>, String>((ref, tripId) async {
  return CollaborationService.instance.getMembers(tripId);
});

final tripRoleFromCollabProvider =
    FutureProvider.family<String?, String>((ref, tripId) async {
  return CollaborationService.instance.getTripRole(tripId);
});

final pendingInvitationsProvider =
    FutureProvider<List<TripMember>>((ref) async {
  return CollaborationService.instance.getPendingInvitations();
});
