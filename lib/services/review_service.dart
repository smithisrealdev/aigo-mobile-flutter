import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/review_model.dart';

class ReviewService {
  ReviewService._();
  static final instance = ReviewService._();

  final _table = 'reviews';

  Future<List<Review>> getReviewsForTrip(String tripId) async {
    try {
      final data = await SupabaseConfig.client
          .from(_table)
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => Review.fromJson(e)).toList();
    } catch (e) {
      debugPrint('getReviewsForTrip error: $e');
      return [];
    }
  }

  Future<List<Review>> getReviewsForPlace(String placeId) async {
    try {
      final data = await SupabaseConfig.client
          .from(_table)
          .select()
          .eq('place_id', placeId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => Review.fromJson(e)).toList();
    } catch (e) {
      debugPrint('getReviewsForPlace error: $e');
      return [];
    }
  }

  Future<Review?> addReview(Review review) async {
    try {
      final json = review.toJson();
      json.remove('id');
      json.remove('helpful_count');
      final data =
          await SupabaseConfig.client.from(_table).insert(json).select().single();
      return Review.fromJson(data);
    } catch (e) {
      debugPrint('addReview error: $e');
      return null;
    }
  }

  Future<bool> updateReview(String reviewId, Map<String, dynamic> updates) async {
    try {
      await SupabaseConfig.client.from(_table).update(updates).eq('id', reviewId);
      return true;
    } catch (e) {
      debugPrint('updateReview error: $e');
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    try {
      await SupabaseConfig.client.from(_table).delete().eq('id', reviewId);
      return true;
    } catch (e) {
      debugPrint('deleteReview error: $e');
      return false;
    }
  }

  Future<bool> markHelpful(String reviewId) async {
    try {
      await SupabaseConfig.client.rpc('increment_helpful', params: {'review_id': reviewId});
      return true;
    } catch (e) {
      // Fallback: read then update
      try {
        final row = await SupabaseConfig.client
            .from(_table)
            .select('helpful_count')
            .eq('id', reviewId)
            .single();
        final current = row['helpful_count'] as int? ?? 0;
        await SupabaseConfig.client
            .from(_table)
            .update({'helpful_count': current + 1}).eq('id', reviewId);
        return true;
      } catch (e2) {
        debugPrint('markHelpful error: $e2');
        return false;
      }
    }
  }

  Future<List<Review>> getMyReviews(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => Review.fromJson(e)).toList();
    } catch (e) {
      debugPrint('getMyReviews error: $e');
      return [];
    }
  }

  Future<double> getAverageRating({String? tripId, String? placeId}) async {
    try {
      var query = SupabaseConfig.client.from(_table).select('rating');
      if (tripId != null) query = query.eq('trip_id', tripId);
      if (placeId != null) query = query.eq('place_id', placeId);
      final data = await query;
      if ((data as List).isEmpty) return 0;
      final sum = data.fold<double>(0, (s, e) => s + (e['rating'] as num).toDouble());
      return sum / data.length;
    } catch (e) {
      debugPrint('getAverageRating error: $e');
      return 0;
    }
  }
}

// ── Riverpod providers ──

final tripReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, tripId) {
  return ReviewService.instance.getReviewsForTrip(tripId);
});

final placeReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, placeId) {
  return ReviewService.instance.getReviewsForPlace(placeId);
});

final myReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, userId) {
  return ReviewService.instance.getMyReviews(userId);
});
