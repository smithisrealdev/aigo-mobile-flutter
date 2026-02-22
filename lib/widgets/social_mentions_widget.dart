import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/social_service.dart';
import '../theme/app_colors.dart';

/// Shows social media mentions for a place (Instagram, Twitter, TikTok, etc.).
class SocialMentionsWidget extends ConsumerWidget {
  final String placeName;
  final String? placeAddress;

  const SocialMentionsWidget({
    super.key,
    required this.placeName,
    this.placeAddress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentionsAsync = ref.watch(
      placeMentionsProvider((name: placeName, address: placeAddress)),
    );

    return mentionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (mentions) {
        if (mentions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Social Mentions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mentions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _MentionCard(mention: mentions[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MentionCard extends StatelessWidget {
  final PlaceMention mention;
  const _MentionCard({required this.mention});

  IconData _platformIcon() {
    switch (mention.platform) {
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      case 'youtube':
        return Icons.play_circle_fill;
      case 'twitter':
      case 'x':
        return Icons.alternate_email;
      case 'reddit':
        return Icons.forum;
      default:
        return Icons.article;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final url = mention.url;
        if (url != null && url.isNotEmpty) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: mention.trending
              ? Border.all(color: AppColors.brandBlue, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_platformIcon(), size: 16, color: AppColors.brandBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mention.source,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (mention.trending)
                const Icon(Icons.trending_up, size: 14, color: AppColors.success),
            ]),
            const SizedBox(height: 8),
            if (mention.title != null) ...[
              Text(mention.title!,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: Text(mention.excerpt,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),
            if (mention.engagement != null)
              Text(mention.engagement!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.brandBlue)),
          ],
        ),
      ),
    );
  }
}
