import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/place_service.dart';
import '../services/weather_service.dart';
import '../widgets/social_mentions_widget.dart';
import '../widgets/place_videos_widget.dart';
import '../widgets/place_comments_widget.dart';

class PlaceDetailScreen extends StatefulWidget {
  final String? placeId;
  final String? placeName;
  const PlaceDetailScreen({super.key, this.placeId, this.placeName});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  PlaceDetails? _details;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.placeId != null && widget.placeName != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final details = await PlaceService.instance.getPlaceDetails(
        widget.placeId!,
        widget.placeName!,
      );
      setState(() => _details = details);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.placeName ?? 'Senso-ji Temple';
    final imageUrl = _details?.image ?? 'https://images.unsplash.com/photo-1528181304800-259b08848526?w=800&h=600&fit=crop';
    final rating = _details?.rating ?? 4.8;
    final reviewCount = _details?.reviewCount ?? 0;
    final description = _details?.description ?? "Senso-ji is Tokyo's oldest temple, dating back to 645 AD. Located in Asakusa, it's one of Japan's most widely visited spiritual sites.";

    return Scaffold(
      body: Stack(
        children: [
          CachedNetworkImage(imageUrl: imageUrl, height: 320, width: double.infinity, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(height: 320, color: AppColors.border)),
          Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _circleBtn(Icons.arrow_back_ios_new, () => Navigator.maybePop(context)),
              const Spacer(),
              _circleBtn(Icons.favorite_border, () {}),
              const SizedBox(width: 8),
              _circleBtn(Icons.share, () {}),
            ]),
          ))),
          DraggableScrollableSheet(
            initialChildSize: 0.6, minChildSize: 0.6, maxChildSize: 0.9,
            builder: (_, controller) => Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
                  : ListView(controller: controller, padding: const EdgeInsets.all(24), children: [
                      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(children: [
                        ...List.generate(5, (i) => Icon(i < rating.floor() ? Icons.star : (i < rating.ceil() ? Icons.star_half : Icons.star_border), color: AppColors.warning, size: 18)),
                        const SizedBox(width: 8),
                        Text('$rating ${reviewCount > 0 ? '($reviewCount reviews)' : ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                      const SizedBox(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _InfoChip(icon: Icons.access_time, label: '2-3 hrs'),
                        _InfoChip(icon: Icons.attach_money, label: _details?.priceLevel != null ? '\$' * _details!.priceLevel! : 'Free'),
                        const _InfoChip(icon: Icons.category, label: 'Temple'),
                      ]),
                      // Opening hours
                      if (_details?.openingHours != null && _details!.openingHours!.weekdayText.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('Opening Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...(_details!.openingHours!.weekdayText.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(p, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ))),
                      ],
                      const SizedBox(height: 20),
                      const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6)),
                      // Tips
                      if (_details != null && _details!.tips.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ..._details!.tips.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('💡 ', style: TextStyle(fontSize: 14)),
                            Expanded(child: Text(t, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4))),
                          ]),
                        )),
                      ],
                      // Reviews
                      if (_details != null && _details!.reviews.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ..._details!.reviews.take(5).map((r) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(r.author, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const Spacer(),
                              ...List.generate(r.rating.toInt(), (_) => const Icon(Icons.star, size: 12, color: AppColors.warning)),
                            ]),
                            if (r.text.isNotEmpty) ...[const SizedBox(height: 4), Text(r.text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis)],
                          ]),
                        )),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Center(child: TextButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry loading details'))),
                      ],
                      // Social mentions
                      const SizedBox(height: 20),
                      SocialMentionsWidget(
                        placeName: name,
                        placeAddress: null,
                      ),
                      // Videos
                      if (widget.placeId != null) ...[
                        const SizedBox(height: 20),
                        PlaceVideosWidget(placeId: widget.placeId!),
                      ],
                      // Comments (only if we have a tripId context — show placeholder otherwise)
                      if (widget.placeId != null) ...[
                        const SizedBox(height: 20),
                        // Comments require tripId; show section header as placeholder
                        const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text('Open from a trip to add comments.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add),
                          label: const Text('Add to Trip'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/travel-tips', extra: widget.placeName),
                          icon: const Icon(Icons.lightbulb_outline, size: 18),
                          label: const Text('Travel Tips'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandBlue,
                            side: const BorderSide(color: AppColors.brandBlue),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.brandBlue),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
