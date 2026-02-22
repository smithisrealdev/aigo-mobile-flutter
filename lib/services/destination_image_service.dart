import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';

// ──────────────────────────────────────────────
// Destination Image Service
// Table: destination_images
// ──────────────────────────────────────────────

class DestinationImageService {
  DestinationImageService._();
  static final instance = DestinationImageService._();

  final _client = SupabaseConfig.client;

  /// Get hero image URL for a destination.
  /// Returns the first matching image URL or null.
  Future<String?> getHeroImage(String destination) async {
    try {
      final data = await _client
          .from('destination_images')
          .select('image_url')
          .eq('destination_name', destination)
          .limit(1)
          .maybeSingle();
      return data?['image_url'] as String?;
    } catch (e) {
      debugPrint('[DestinationImageService] getHeroImage error: $e');
      return null;
    }
  }

  /// Get all images for a destination.
  Future<List<DestinationImage>> getImages(String destination) async {
    try {
      final data = await _client
          .from('destination_images')
          .select()
          .eq('destination_name', destination);
      return (data as List)
          .map((e) => DestinationImage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DestinationImageService] getImages error: $e');
      return [];
    }
  }

  /// Get images by region.
  Future<List<DestinationImage>> getImagesByRegion(String region) async {
    try {
      final data = await _client
          .from('destination_images')
          .select()
          .eq('region', region);
      return (data as List)
          .map((e) => DestinationImage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DestinationImageService] getImagesByRegion error: $e');
      return [];
    }
  }
}

// ── Riverpod Providers ──

final destinationImageServiceProvider =
    Provider((_) => DestinationImageService.instance);

final heroImageProvider =
    FutureProvider.family<String?, String>((ref, destination) async {
  return DestinationImageService.instance.getHeroImage(destination);
});
