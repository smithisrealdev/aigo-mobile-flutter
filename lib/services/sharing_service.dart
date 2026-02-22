import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Trip Sharing Service
// Mirrors: useTripSharing.ts
// ──────────────────────────────────────────────

class ShareInfo {
  final String? shareToken;
  final bool isPublic;
  final int shareViews;

  const ShareInfo({
    this.shareToken,
    this.isPublic = false,
    this.shareViews = 0,
  });

  String? get shareUrl =>
      shareToken != null ? 'https://theaigo.co/shared/$shareToken' : null;
}

class SharingService {
  SharingService._();
  static final SharingService instance = SharingService._();

  final _client = SupabaseConfig.client;

  Future<ShareInfo> enableSharing(String tripId) async {
    try {
      final result =
          await _client.rpc('enable_trip_sharing', params: {'p_trip_id': tripId});
      final token = result is Map
          ? result['share_token'] as String?
          : result?.toString();
      return ShareInfo(shareToken: token, isPublic: true);
    } catch (e) {
      debugPrint('SharingService.enableSharing error: $e');
      rethrow;
    }
  }

  Future<void> disableSharing(String tripId) async {
    try {
      await _client.rpc('disable_trip_sharing', params: {'p_trip_id': tripId});
    } catch (e) {
      debugPrint('SharingService.disableSharing error: $e');
      rethrow;
    }
  }

  Future<String?> regenerateToken(String tripId) async {
    try {
      final result =
          await _client.rpc('regenerate_share_token', params: {'p_trip_id': tripId});
      if (result is Map) return result['share_token'] as String?;
      return result?.toString();
    } catch (e) {
      debugPrint('SharingService.regenerateToken error: $e');
      return null;
    }
  }

  Future<void> incrementViews(String shareToken) async {
    try {
      await _client
          .rpc('increment_share_views', params: {'p_share_token': shareToken});
    } catch (e) {
      debugPrint('SharingService.incrementViews error: $e');
    }
  }

  Future<void> togglePublic(String tripId, bool isPublic) async {
    try {
      await _client
          .from('trips')
          .update({'is_public': isPublic})
          .eq('id', tripId);
    } catch (e) {
      debugPrint('SharingService.togglePublic error: $e');
    }
  }

  Future<ShareInfo> getShareInfo(String tripId) async {
    try {
      final data = await _client
          .from('trips')
          .select('share_token, is_public, share_views')
          .eq('id', tripId)
          .single();
      return ShareInfo(
        shareToken: data['share_token'] as String?,
        isPublic: data['is_public'] as bool? ?? false,
        shareViews: (data['share_views'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('SharingService.getShareInfo error: $e');
      return const ShareInfo();
    }
  }
}

// ── Providers ──

final sharingServiceProvider =
    Provider<SharingService>((_) => SharingService.instance);

final tripShareInfoProvider =
    FutureProvider.family<ShareInfo, String>((ref, tripId) async {
  return SharingService.instance.getShareInfo(tripId);
});
