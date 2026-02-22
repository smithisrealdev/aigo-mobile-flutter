import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/social_service.dart';
import '../theme/app_colors.dart';

/// Horizontal scroll of video thumbnails for a place.
class PlaceVideosWidget extends ConsumerWidget {
  final String placeId;

  const PlaceVideosWidget({super.key, required this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(placeVideosProvider(placeId));

    return videosAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (videos) {
        if (videos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Videos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: videos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _VideoCard(video: videos[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoThumbnail video;
  const _VideoCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (video.videoUrl.isNotEmpty) {
          launchUrl(Uri.parse(video.videoUrl),
              mode: LaunchMode.externalApplication);
        }
      },
      child: SizedBox(
        width: 180,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                width: 180,
                height: 130,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 180,
                  height: 130,
                  color: AppColors.border,
                  child: const Icon(Icons.videocam, color: AppColors.textSecondary),
                ),
              ),
            ),
            // Play overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.play_circle_fill,
                  size: 40, color: Colors.white),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                video.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
