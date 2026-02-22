import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../models/public_guide.dart';

// ──────────────────────────────────────────────
// Public Guides Service
// Table: public_guides
// ──────────────────────────────────────────────

class PublicGuideService {
  PublicGuideService._();
  static final instance = PublicGuideService._();

  final _client = SupabaseConfig.client;

  /// Fetch all public guides, optionally filtered.
  Future<List<PublicGuide>> fetchGuides({
    String? region,
    String? tag,
    bool? featuredOnly,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('public_guides').select();
      if (region != null) query = query.eq('region', region);
      if (featuredOnly == true) query = query.eq('is_featured', true);
      if (tag != null) query = query.contains('tags', [tag]);

      final data = await query
          .order('views', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List)
          .map((e) => PublicGuide.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PublicGuideService] fetchGuides error: $e');
      return [];
    }
  }

  /// Fetch featured guides.
  Future<List<PublicGuide>> fetchFeatured({int limit = 10}) async {
    return fetchGuides(featuredOnly: true, limit: limit);
  }

  /// Fetch a single guide by slug or id.
  Future<PublicGuide?> fetchGuide(String idOrSlug) async {
    try {
      // Try by slug first, then by id
      var data = await _client
          .from('public_guides')
          .select()
          .eq('slug', idOrSlug)
          .maybeSingle();

      data ??= await _client
          .from('public_guides')
          .select()
          .eq('id', idOrSlug)
          .maybeSingle();

      if (data == null) return null;
      return PublicGuide.fromJson(data);
    } catch (e) {
      debugPrint('[PublicGuideService] fetchGuide error: $e');
      return null;
    }
  }

  /// Increment view count.
  Future<void> incrementViews(String guideId) async {
    try {
      await _client.rpc('increment_guide_views', params: {'p_guide_id': guideId});
    } catch (e) {
      // Fallback: direct update
      try {
        final current = await _client
            .from('public_guides')
            .select('views')
            .eq('id', guideId)
            .maybeSingle();
        final views = (current?['views'] as int? ?? 0) + 1;
        await _client.from('public_guides').update({'views': views}).eq('id', guideId);
      } catch (_) {}
    }
  }

  /// Search guides by text query.
  Future<List<PublicGuide>> searchGuides(String query, {int limit = 20}) async {
    try {
      final data = await _client
          .from('public_guides')
          .select()
          .or('title.ilike.%$query%,destination.ilike.%$query%,description.ilike.%$query%')
          .order('views', ascending: false)
          .limit(limit);

      return (data as List)
          .map((e) => PublicGuide.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PublicGuideService] searchGuides error: $e');
      return [];
    }
  }
}

// ── Riverpod Providers ──

final publicGuidesProvider = FutureProvider<List<PublicGuide>>((ref) async {
  return PublicGuideService.instance.fetchGuides();
});

final featuredGuidesProvider = FutureProvider<List<PublicGuide>>((ref) async {
  return PublicGuideService.instance.fetchFeatured();
});

final guideDetailProvider =
    FutureProvider.family<PublicGuide?, String>((ref, idOrSlug) async {
  return PublicGuideService.instance.fetchGuide(idOrSlug);
});

final guideSearchProvider =
    FutureProvider.family<List<PublicGuide>, String>((ref, query) async {
  return PublicGuideService.instance.searchGuides(query);
});
