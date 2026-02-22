import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';

/// Image fetching and caching service.
class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  /// Get photo URLs for a place from `place_details_cache`.
  Future<List<String>> getPlacePhotos(String placeId) async {
    try {
      final data = await SupabaseConfig.client
          .from('place_details_cache')
          .select('photo_urls')
          .eq('place_key', placeId)
          .maybeSingle();
      if (data == null) return [];
      final urls = data['photo_urls'] as List?;
      return urls?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('ImageService.getPlacePhotos failed: $e');
      return [];
    }
  }

  /// Get destination images from `destination_images` table.
  Future<List<DestinationImage>> getDestinationImages(
      String destination) async {
    try {
      final data = await SupabaseConfig.client
          .from('destination_images')
          .select()
          .eq('destination_name', destination);
      return (data as List).map((e) => DestinationImage.fromJson(e)).toList();
    } catch (e) {
      debugPrint('ImageService.getDestinationImages failed: $e');
      return [];
    }
  }

  /// Trigger server-side image caching via edge function.
  Future<void> cacheImage(String url) async {
    try {
      await SupabaseConfig.client.functions.invoke(
        'cache-image',
        body: {'url': url},
      );
    } catch (e) {
      debugPrint('ImageService.cacheImage failed: $e');
    }
  }
}

// ── Riverpod providers ──

final imageServiceProvider = Provider((_) => ImageService.instance);

final placePhotosProvider =
    FutureProvider.family<List<String>, String>((ref, placeId) async {
  return ImageService.instance.getPlacePhotos(placeId);
});

final destinationImagesProvider =
    FutureProvider.family<List<DestinationImage>, String>(
        (ref, destination) async {
  return ImageService.instance.getDestinationImages(destination);
});
