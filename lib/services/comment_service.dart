import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Place Comments Service
// Mirrors: usePlaceComments.ts
// ──────────────────────────────────────────────

class PlaceComment {
  final String id;
  final String tripId;
  final String placeId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String content;
  final String createdAt;
  final String updatedAt;

  PlaceComment({
    required this.id,
    required this.tripId,
    required this.placeId,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlaceComment.fromJson(Map<String, dynamic> json,
      {Map<String, dynamic>? profile}) {
    return PlaceComment(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      placeId: json['place_id'] as String,
      userId: json['user_id'] as String,
      userName: profile?['full_name'] as String?,
      userAvatar: profile?['avatar_url'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class CommentService {
  CommentService._();
  static final instance = CommentService._();

  final _client = SupabaseConfig.client;

  /// Fetch comments for a place within a trip.
  Future<List<PlaceComment>> fetchComments(
      String tripId, String placeId) async {
    try {
      final data = await _client
          .from('place_comments')
          .select()
          .eq('trip_id', tripId)
          .eq('place_id', placeId)
          .order('created_at', ascending: true);

      final rows = data as List<dynamic>;
      final userIds =
          rows.map((r) => r['user_id'] as String).toSet().toList();

      Map<String, Map<String, dynamic>> profileMap = {};
      if (userIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', userIds);
        for (final p in (profiles as List<dynamic>)) {
          profileMap[p['id'] as String] = p as Map<String, dynamic>;
        }
      }

      return rows
          .map((r) => PlaceComment.fromJson(r as Map<String, dynamic>,
              profile: profileMap[r['user_id']]))
          .toList();
    } catch (e) {
      debugPrint('[CommentService] fetchComments error: $e');
      return [];
    }
  }

  /// Add a comment.
  Future<PlaceComment?> addComment({
    required String tripId,
    required String placeId,
    required String content,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _client
          .from('place_comments')
          .insert({
            'trip_id': tripId,
            'place_id': placeId,
            'user_id': userId,
            'content': content.trim(),
          })
          .select()
          .single();

      return PlaceComment.fromJson(data);
    } catch (e) {
      debugPrint('[CommentService] addComment error: $e');
      return null;
    }
  }

  /// Update a comment.
  Future<bool> updateComment(String commentId, String content) async {
    try {
      await _client
          .from('place_comments')
          .update({'content': content.trim()}).eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('[CommentService] updateComment error: $e');
      return false;
    }
  }

  /// Delete a comment.
  Future<bool> deleteComment(String commentId) async {
    try {
      await _client.from('place_comments').delete().eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('[CommentService] deleteComment error: $e');
      return false;
    }
  }
}

// ── Riverpod Providers ──

final placeCommentsProvider = FutureProvider.family<List<PlaceComment>,
    ({String tripId, String placeId})>((ref, params) async {
  return CommentService.instance.fetchComments(params.tripId, params.placeId);
});
