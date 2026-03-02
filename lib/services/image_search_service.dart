import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

/// Image search service with 2-level cache (memory + Supabase).
/// Mirrors web's src/lib/imageSearch.ts caching strategy.
class ImageSearchService {
  ImageSearchService._();
  static final ImageSearchService instance = ImageSearchService._();

  // Level 1: In-memory cache (fast, session-only)
  final _memoryCache = <String, String>{};

  // Circuit breaker state
  int _consecutiveFailures = 0;
  static const _maxFailures = 5;
  DateTime? _circuitOpenedAt;
  static const _circuitResetDuration = Duration(minutes: 2);

  bool get _isCircuitOpen {
    if (_consecutiveFailures < _maxFailures) return false;
    if (_circuitOpenedAt == null) return false;
    if (DateTime.now().difference(_circuitOpenedAt!) > _circuitResetDuration) {
      // Half-open: allow one attempt
      _consecutiveFailures = _maxFailures - 1;
      return false;
    }
    return true;
  }

  void _recordSuccess() {
    _consecutiveFailures = 0;
    _circuitOpenedAt = null;
  }

  void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _maxFailures) {
      _circuitOpenedAt = DateTime.now();
    }
  }

  String _withProxy(String url) {
    if (url.isEmpty || url.contains('image-proxy')) return url;
    return '${SupabaseConfig.supabaseUrl}/functions/v1/image-proxy?url=${Uri.encodeComponent(url)}';
  }

  /// Search for an image URL by query string.
  /// Returns cached URL if available, otherwise searches via edge function.
  Future<String> searchImage(String query, {Set<String>? seenUrls}) async {
    if (query.isEmpty) return '';

    final normalizedQuery = query.trim().toLowerCase();

    // Default fallback image if everything fails
    const defaultImage =
        'https://images.unsplash.com/photo-1488646953014-c8c0f5280b5c?q=80&w=800&auto=format&fit=crop';

    // Level 1: Memory cache
    if (_memoryCache.containsKey(normalizedQuery)) {
      final cached = _memoryCache[normalizedQuery]!;
      if (seenUrls == null || !seenUrls.contains(cached)) {
        return _withProxy(cached);
      }
    }

    // Level 2: Supabase image_cache table
    try {
      final rows = await SupabaseConfig.client
          .from('image_cache')
          .select('image_url')
          .eq('query', normalizedQuery)
          .limit(1);

      if (rows.isNotEmpty) {
        final url = rows[0]['image_url'] as String? ?? '';
        if (url.isNotEmpty) {
          if (seenUrls == null || !seenUrls.contains(url)) {
            _memoryCache[normalizedQuery] = url;
            return _withProxy(url);
          }
        }
      }
    } catch (e) {
      debugPrint('[ImageSearch] Supabase cache lookup failed: $e');
    }

    // Circuit breaker check
    if (_isCircuitOpen) {
      debugPrint('[ImageSearch] Circuit breaker open, skipping API call');
      return _withProxy(defaultImage);
    }

    // Level 3: Search via edge function
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'google-search',
        body: {
          'query': '$query travel destination photo',
          'type': 'image',
          'limit': 5, // Get more for dedup
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final results = data?['results'] as List?;

      String bestUrl = '';
      if (results != null) {
        for (final r in results) {
          final u = (r as Map<String, dynamic>)['link'] as String?;
          if (u != null && u.isNotEmpty) {
            if (seenUrls == null ||
                (!seenUrls.contains(u) && !seenUrls.contains(_withProxy(u)))) {
              bestUrl = u;
              break;
            }
          }
        }
      }

      if (bestUrl.isNotEmpty) {
        _recordSuccess();
        _memoryCache[normalizedQuery] = bestUrl;

        // Persist to Supabase cache (fire-and-forget)
        SupabaseConfig.client
            .from('image_cache')
            .upsert({'query': normalizedQuery, 'image_url': bestUrl})
            .then((_) {})
            .catchError((e) {
              debugPrint('[ImageSearch] Cache write failed: $e');
            });

        return _withProxy(bestUrl);
      }

      _recordFailure();
      return _withProxy(defaultImage);
    } catch (e) {
      debugPrint('[ImageSearch] Search failed: $e');
      _recordFailure();
      return _withProxy(defaultImage);
    }
  }

  /// Search for multiple images for a single query (gallery).
  /// Bypasses database cache to ensure we get a gallery from the edge function.
  Future<List<String>> searchImageGallery(String query, {int limit = 3}) async {
    if (query.isEmpty) return [];

    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'google-search',
        body: {
          'query': '$query travel destination photo',
          'type': 'image',
          'limit': limit,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final results = data?['results'] as List?;

      final urls = <String>[];
      if (results != null) {
        for (final r in results) {
          final u = (r as Map<String, dynamic>)['link'] as String?;
          if (u != null && u.isNotEmpty) {
            urls.add(_withProxy(u));
            if (urls.length >= limit) break;
          }
        }
      }
      return urls;
    } catch (e) {
      debugPrint('[ImageSearch] Gallery search failed: $e');
      return [];
    }
  }

  /// Batch search for multiple image queries.
  /// Returns map of query → URL.
  Future<Map<String, String>> searchImages(List<String> queries) async {
    final results = <String, String>{};
    final seenUrls = <String>{};

    // Sequential search to ensure we can correctly populate `seenUrls` for dedup
    for (final query in queries) {
      final url = await searchImage(query, seenUrls: seenUrls);
      if (url.isNotEmpty) {
        results[query] = url;
        seenUrls.add(url);
      }
    }

    return results;
  }

  /// Pre-populate memory cache (e.g., from Hive on startup).
  void warmUpCache(Map<String, String> entries) {
    _memoryCache.addAll(entries);
  }

  /// Clear all caches.
  void clearCache() {
    _memoryCache.clear();
    _consecutiveFailures = 0;
    _circuitOpenedAt = null;
  }
}

// ── Riverpod provider ──
final imageSearchServiceProvider = Provider((_) => ImageSearchService.instance);
