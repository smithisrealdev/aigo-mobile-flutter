import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Social Mentions + Video Thumbnails Service
// Mirrors: usePlaceMentions.ts, video_thumbnail_cache
// ──────────────────────────────────────────────

class PlaceMention {
  final String source;
  final String platform; // tiktok, instagram, youtube, reddit, blog, x, twitter
  final String? title;
  final String excerpt;
  final String? engagement;
  final String? url;
  final bool trending;
  final bool isVideo;
  final String? thumbnailUrl;

  PlaceMention({
    required this.source,
    required this.platform,
    this.title,
    required this.excerpt,
    this.engagement,
    this.url,
    this.trending = false,
    this.isVideo = false,
    this.thumbnailUrl,
  });

  factory PlaceMention.fromJson(Map<String, dynamic> json) => PlaceMention(
        source: json['source'] as String? ?? '',
        platform: json['platform'] as String? ?? 'blog',
        title: json['title'] as String?,
        excerpt: json['excerpt'] as String? ?? '',
        engagement: json['engagement'] as String?,
        url: json['url'] as String?,
        trending: json['trending'] as bool? ?? false,
        isVideo: json['isVideo'] as bool? ?? false,
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );
}

class VideoThumbnail {
  final String placeId;
  final String platform;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String? cachedAt;

  VideoThumbnail({
    required this.placeId,
    required this.platform,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    this.cachedAt,
  });

  factory VideoThumbnail.fromJson(Map<String, dynamic> json) => VideoThumbnail(
        placeId: json['place_id'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        videoUrl: json['video_url'] as String? ?? '',
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cachedAt: json['cached_at'] as String?,
      );
}

class SocialService {
  SocialService._();
  static final instance = SocialService._();

  final _client = SupabaseConfig.client;

  /// Fetch social mentions for a place via edge function.
  Future<List<PlaceMention>> fetchMentions(
    String placeName, {
    String? placeAddress,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'place-mentions-multi',
        body: {
          'placeName': placeName,
          if (placeAddress != null) 'placeAddress': placeAddress,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final mentions = (data?['mentions'] as List<dynamic>?) ?? [];
      return mentions
          .map((m) => PlaceMention.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SocialService] fetchMentions error: $e');
      return [];
    }
  }

  /// Fetch video thumbnails from cache table.
  Future<List<VideoThumbnail>> fetchVideos(String placeId) async {
    try {
      final response = await _client
          .from('video_thumbnail_cache')
          .select()
          .eq('place_id', placeId)
          .order('cached_at', ascending: false);

      return (response as List<dynamic>)
          .map((v) => VideoThumbnail.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SocialService] fetchVideos error: $e');
      return [];
    }
  }
}

// ── Riverpod Providers ──

final placeMentionsProvider =
    FutureProvider.family<List<PlaceMention>, ({String name, String? address})>(
        (ref, params) async {
  return SocialService.instance
      .fetchMentions(params.name, placeAddress: params.address);
});

final placeVideosProvider =
    FutureProvider.family<List<VideoThumbnail>, String>((ref, placeId) async {
  return SocialService.instance.fetchVideos(placeId);
});
