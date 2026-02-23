import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';

class AiPicksService {
  AiPicksService._();
  static final instance = AiPicksService._();

  final _dio = Dio();
  List<AiPick>? _cachedPicks;
  DateTime? _lastFetch;

  /// Fetch AI-powered destination picks based on user's travel history
  Future<List<AiPick>> getAiPicks() async {
    // Cache for 1 hour
    if (_cachedPicks != null && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 60) {
      return _cachedPicks!;
    }

    try {
      // 1. Get user's past trips for lifestyle analysis
      final user = SupabaseConfig.client.auth.currentUser;
      String userContext = 'New user with no trip history';

      if (user != null) {
        final tripsResp = await SupabaseConfig.client
            .from('trips')
            .select('destination, category, budget_total')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(10);

        final trips = tripsResp as List;
        if (trips.isNotEmpty) {
          userContext = 'User past trips: ${trips.map((t) => '${t['destination']} (${t['category'] ?? 'general'})').join(', ')}';
        }
      }

      // 2. Get popular public trips from community
      final publicTrips = await SupabaseConfig.client
          .from('trips')
          .select('destination, category')
          .eq('is_public', true)
          .order('share_views', ascending: false)
          .limit(15);

      final community = (publicTrips as List)
          .map((t) => t['destination'] ?? '')
          .where((d) => d.isNotEmpty)
          .join(', ');

      // 3. Call AI for personalized recommendations
      final response = await _dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer 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',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'google/gemini-3-pro-preview',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a travel recommendation engine. Return ONLY valid JSON array, no markdown fences.'
            },
            {
              'role': 'user',
              'content': '''Recommend 5 travel destinations for this traveler.

$userContext
Popular community destinations: ${community.isEmpty ? 'none yet' : community}

Return JSON array:
[{"title":"Catchy name","subtitle":"2-3 words","destination":"City, Country","category":"nature|culture|food|adventure|beach|city","match_reason":"Why it matches","image_query":"unsplash search term"}]

Mix categories. If new user, recommend diverse popular destinations.'''
            }
          ],
          'temperature': 0.8,
          'max_tokens': 800,
        },
      );

      final content = response.data['choices']?[0]?['message']?['content'] ?? '[]';
      final cleaned = content.toString()
          .replaceAll(RegExp(r'```json?\n?'), '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> parsed = jsonDecode(cleaned);
      final picks = parsed.map((p) => AiPick(
        title: p['title'] ?? 'Unknown',
        subtitle: p['subtitle'] ?? '',
        destination: p['destination'] ?? '',
        category: p['category'] ?? 'city',
        matchReason: p['match_reason'] ?? '',
        imageUrl: _unsplashUrl(p['image_query'] ?? p['destination'] ?? 'travel'),
      )).toList();

      _cachedPicks = picks;
      _lastFetch = DateTime.now();
      return picks;
    } catch (e) {
      debugPrint('AiPicksService error: $e');
      return _fallbackPicks();
    }
  }

  static String _unsplashUrl(String query) {
    // Use a set of curated high-quality travel photos keyed by category keywords
    final q = query.toLowerCase();
    if (q.contains('japan') || q.contains('kyoto') || q.contains('tokyo')) {
      return 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&h=300&fit=crop';
    } else if (q.contains('bali') || q.contains('indonesia')) {
      return 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&h=300&fit=crop';
    } else if (q.contains('thai') || q.contains('chiang')) {
      return 'https://images.unsplash.com/photo-1506665531195-3566af2b4dfa?w=400&h=300&fit=crop';
    } else if (q.contains('greece') || q.contains('santorini')) {
      return 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=400&h=300&fit=crop';
    } else if (q.contains('paris') || q.contains('france')) {
      return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&h=300&fit=crop';
    } else if (q.contains('switzerland') || q.contains('alps')) {
      return 'https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=400&h=300&fit=crop';
    } else if (q.contains('italy') || q.contains('rome') || q.contains('venice')) {
      return 'https://images.unsplash.com/photo-1515859005217-8a1f08870f59?w=400&h=300&fit=crop';
    } else if (q.contains('beach') || q.contains('maldives') || q.contains('island')) {
      return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&h=300&fit=crop';
    } else if (q.contains('mountain') || q.contains('trek') || q.contains('nepal')) {
      return 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=400&h=300&fit=crop';
    } else if (q.contains('new york') || q.contains('nyc')) {
      return 'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=400&h=300&fit=crop';
    } else if (q.contains('london') || q.contains('england')) {
      return 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&h=300&fit=crop';
    } else if (q.contains('morocco') || q.contains('marrakech')) {
      return 'https://images.unsplash.com/photo-1489749798305-4fea3ae63d43?w=400&h=300&fit=crop';
    }
    // Generic travel fallback
    return 'https://images.unsplash.com/photo-1500835556837-99ac94a94552?w=400&h=300&fit=crop';
  }

  /// Curated fallback if AI fails
  static List<AiPick> _fallbackPicks() {
    return [
      AiPick(title: 'Hidden Kyoto', subtitle: 'Nature & temples', destination: 'Kyoto, Japan', category: 'culture', matchReason: 'Trending', imageUrl: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&h=300&fit=crop'),
      AiPick(title: 'Ubud Culture', subtitle: 'Rice fields & art', destination: 'Bali, Indonesia', category: 'nature', matchReason: 'Popular', imageUrl: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&h=300&fit=crop'),
      AiPick(title: 'Chiang Mai', subtitle: 'Food & nature', destination: 'Chiang Mai, Thailand', category: 'food', matchReason: 'Popular', imageUrl: 'https://images.unsplash.com/photo-1506665531195-3566af2b4dfa?w=400&h=300&fit=crop'),
      AiPick(title: 'Santorini Dream', subtitle: 'Island paradise', destination: 'Santorini, Greece', category: 'beach', matchReason: 'Trending', imageUrl: 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=400&h=300&fit=crop'),
      AiPick(title: 'Swiss Alps', subtitle: 'Mountain escape', destination: 'Interlaken, Switzerland', category: 'adventure', matchReason: 'Popular', imageUrl: 'https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=400&h=300&fit=crop'),
    ];
  }

  void clearCache() {
    _cachedPicks = null;
    _lastFetch = null;
  }
}

class AiPick {
  final String title;
  final String subtitle;
  final String destination;
  final String category;
  final String matchReason;
  final String imageUrl;

  AiPick({
    required this.title,
    required this.subtitle,
    required this.destination,
    required this.category,
    required this.matchReason,
    required this.imageUrl,
  });
}
