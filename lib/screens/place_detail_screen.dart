import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CachedNetworkImage(imageUrl: 'https://picsum.photos/800/600?random=90', height: 320, width: double.infinity, fit: BoxFit.cover),
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
              child: ListView(controller: controller, padding: const EdgeInsets.all(24), children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const Text('Senso-ji Temple', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Row(children: [
                  Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text('Asakusa, Tokyo, Japan', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  ...List.generate(5, (i) => Icon(i < 4 ? Icons.star : Icons.star_half, color: AppColors.warning, size: 18)),
                  const SizedBox(width: 8),
                  const Text('4.8 (2,340 reviews)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
                const SizedBox(height: 20),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _InfoChip(icon: Icons.access_time, label: '2-3 hrs'),
                  _InfoChip(icon: Icons.attach_money, label: 'Free'),
                  _InfoChip(icon: Icons.category, label: 'Temple'),
                ]),
                const SizedBox(height: 20),
                const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  "Senso-ji is Tokyo's oldest temple, dating back to 645 AD. Located in Asakusa, it's one of Japan's most widely visited spiritual sites. The temple is dedicated to Kannon, the bodhisattva of compassion. The iconic Kaminarimon (Thunder Gate) with its massive red lantern is one of Tokyo's most recognizable landmarks.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
                ),
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
