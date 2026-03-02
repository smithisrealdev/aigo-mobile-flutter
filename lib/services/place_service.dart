import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Place service — matches usePlaceDetails.ts
// Checks place_details_cache, then calls place-details edge function
// ──────────────────────────────────────────────

class PlaceReview {
  final String author;
  final double rating;
  final String text;
  final String time;
  final String? profilePhoto;

  PlaceReview({
    required this.author,
    required this.rating,
    required this.text,
    required this.time,
    this.profilePhoto,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) => PlaceReview(
        author: json['author'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        text: json['text'] as String? ?? '',
        time: json['time'] as String? ?? '',
        profilePhoto: json['profilePhoto'] as String?,
      );
}

class OpeningHours {
  final bool? isOpen;
  final List<String> weekdayText;

  OpeningHours({this.isOpen, this.weekdayText = const []});

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
        isOpen: json['isOpen'] as bool?,
        weekdayText: (json['weekdayText'] as List?)?.cast<String>() ?? [],
      );
}

class PlaceDetails {
  final String? image;
  final String? description;
  final List<String> tips;
  final double? rating;
  final int? reviewCount;
  final String? website;
  final String? phone;
  final String? googleMapsUrl;
  final int? priceLevel;
  final OpeningHours? openingHours;
  final List<PlaceReview> reviews;

  PlaceDetails({
    this.image,
    this.description,
    this.tips = const [],
    this.rating,
    this.reviewCount,
    this.website,
    this.phone,
    this.googleMapsUrl,
    this.priceLevel,
    this.openingHours,
    this.reviews = const [],
  });
}

// In-memory cache matching website pattern
class _CachedEntry {
  final PlaceDetails details;
  final DateTime fetchedAt;
  _CachedEntry(this.details) : fetchedAt = DateTime.now();
}

final Map<String, _CachedEntry> _memoryCache = {};
const _memoryCacheDurationMs = 60 * 60 * 1000; // 1 hour
const _dbCacheDurationMs = 30 * 24 * 60 * 60 * 1000; // 30 days

/// Generate place key matching website pattern.
String _generatePlaceKey(String placeName, String? placeAddress) =>
    '${placeName.toLowerCase().trim()}|${(placeAddress ?? '').toLowerCase().trim()}';

class PlaceService {
  PlaceService._();
  static final PlaceService instance = PlaceService._();

  /// Fetch place details (matches usePlaceDetails.ts).
  /// Checks memory cache → DB cache → edge function.
  Future<PlaceDetails> getPlaceDetails(
    String placeId,
    String placeName, {
    String? placeAddress,
  }) async {
    // Check memory cache
    final memoryCached = _memoryCache[placeId];
    if (memoryCached != null &&
        DateTime.now().difference(memoryCached.fetchedAt).inMilliseconds <
            _memoryCacheDurationMs) {
      return memoryCached.details;
    }

    final placeKey = _generatePlaceKey(placeName, placeAddress);

    // Check database cache
    try {
      final dbCached = await SupabaseConfig.client
          .from('place_details_cache')
          .select()
          .eq('place_key', placeKey)
          .maybeSingle();

      if (dbCached != null) {
        final updatedAt =
            DateTime.tryParse(dbCached['updated_at'] as String? ?? '');
        final cacheAge = updatedAt != null
            ? DateTime.now().difference(updatedAt).inMilliseconds
            : _dbCacheDurationMs + 1;

        if (cacheAge < _dbCacheDurationMs) {
          final details = PlaceDetails(
            image: dbCached['image_url'] as String?,
            rating: (dbCached['rating'] as num?)?.toDouble(),
            reviewCount: dbCached['review_count'] as int?,
            website: dbCached['website'] as String?,
            phone: dbCached['phone'] as String?,
            googleMapsUrl: dbCached['google_maps_url'] as String?,
            priceLevel: dbCached['price_level'] as int?,
            openingHours: dbCached['opening_hours'] != null
                ? OpeningHours.fromJson(
                    dbCached['opening_hours'] as Map<String, dynamic>)
                : null,
            reviews: (dbCached['reviews'] as List?)
                    ?.map((r) =>
                        PlaceReview.fromJson(r as Map<String, dynamic>))
                    .toList() ??
                [],
          );

          _memoryCache[placeId] = _CachedEntry(details);
          return details;
        }
      }
    } catch (e) {
      debugPrint('DB cache check failed: $e');
    }

    // Fetch from edge function with retry
    try {
      final res = await _invokeWithRetry('place-details', body: {
        'placeName': placeName,
        'placeAddress': ?placeAddress,
      });

      final data = res.data as Map<String, dynamic>?;
      if (data?['success'] == true && data?['data'] != null) {
        final d = data!['data'] as Map<String, dynamic>;

        final details = PlaceDetails(
          image: d['photoUrl'] as String?,
          rating: (d['rating'] as num?)?.toDouble(),
          reviewCount: (d['reviewCount'] as num?)?.toInt(),
          website: d['website'] as String?,
          phone: d['phone'] as String?,
          googleMapsUrl: d['googleMapsUrl'] as String?,
          priceLevel: (d['priceLevel'] as num?)?.toInt(),
          openingHours: d['openingHours'] != null
              ? OpeningHours.fromJson(
                  d['openingHours'] as Map<String, dynamic>)
              : null,
          reviews: (d['reviews'] as List?)
                  ?.map((r) =>
                      PlaceReview.fromJson(r as Map<String, dynamic>))
                  .toList() ??
              [],
        );

        _memoryCache[placeId] = _CachedEntry(details);
        return details;
      }
    } catch (e) {
      debugPrint('Place details fetch failed: $e');
    }

    return PlaceDetails();
  }

  /// Get nearby places (matches website nearby-places call).
  Future<List<Map<String, dynamic>>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required String type,
  }) async {
    try {
      final res = await SupabaseConfig.client.functions
          .invoke('nearby-places', body: {
        'lat': latitude,
        'lng': longitude,
        'type': type,
      });

      final data = res.data as Map<String, dynamic>?;
      return (data?['places'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
    } catch (e) {
      debugPrint('Nearby places error: $e');
      return [];
    }
  }

  /// Get cached place image (returns null if not cached).
  String? getCachedPlaceImage(String placeId) {
    final cached = _memoryCache[placeId];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMilliseconds <
            _memoryCacheDurationMs) {
      return cached.details.image;
    }
    return null;
  }

  Future<dynamic> _invokeWithRetry(String functionName,
      {Map<String, dynamic>? body, int maxRetries = 3}) async {
    dynamic lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await SupabaseConfig.client.functions
          .invoke(functionName, body: body);
      final d = result.data;
      final isBootError = d is Map && d['code'] == 'BOOT_ERROR';
      if (isBootError && attempt < maxRetries) {
        lastError = Exception('BOOT_ERROR');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
        continue;
      }
      return result;
    }
    throw lastError ?? Exception('All retries exhausted');
  }

  /// Web search fallback via google-search edge function.
  Future<List<Map<String, dynamic>>> googleSearch(String query,
      {int limit = 5}) async {
    try {
      final res = await _invokeWithRetry('google-search', body: {
        'query': query,
        'limit': limit,
      });
      final data = res.data as Map<String, dynamic>?;
      return ((data?['results'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[PlaceService] googleSearch error: $e');
      return [];
    }
  }

  /// Read place_details_cache directly.
  Future<Map<String, dynamic>?> getPlaceDetailsFromCache(
      String placeKey) async {
    try {
      return await SupabaseConfig.client
          .from('place_details_cache')
          .select()
          .eq('place_key', placeKey)
          .maybeSingle();
    } catch (e) {
      debugPrint('[PlaceService] getPlaceDetailsFromCache error: $e');
      return null;
    }
  }
}

// ── Riverpod providers ──

final placeServiceProvider =
    Provider((_) => PlaceService.instance);

/// Place details for a specific place.
final placeDetailsProvider = FutureProvider.family<PlaceDetails,
    ({String placeId, String placeName, String? placeAddress})>(
  (ref, params) async {
    return PlaceService.instance.getPlaceDetails(
      params.placeId,
      params.placeName,
      placeAddress: params.placeAddress,
    );
  },
);
