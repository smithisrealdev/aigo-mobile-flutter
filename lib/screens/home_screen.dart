import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../widgets/aigo_header.dart';
import '../widgets/quick_chip.dart';
import '../widgets/destination_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AigoHeader(
            actions: [
              IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () => context.push('/notifications')),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 20)),
              ),
            ],
            bottom: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Where do you want to go?',
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        QuickChip(label: '🏖️ Beach', selected: true),
                        SizedBox(width: 8),
                        QuickChip(label: '🏔️ Mountain'),
                        SizedBox(width: 8),
                        QuickChip(label: '🏙️ City'),
                        SizedBox(width: 8),
                        QuickChip(label: '🍜 Food'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Featured Destinations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        SizedBox(width: 200, child: DestinationCard(imageUrl: 'https://picsum.photos/400/300?random=1', name: 'Tokyo', location: 'Japan', rating: 4.8, onTap: () => context.push('/place-detail'))),
                        const SizedBox(width: 12),
                        SizedBox(width: 200, child: DestinationCard(imageUrl: 'https://picsum.photos/400/300?random=2', name: 'Bali', location: 'Indonesia', rating: 4.7)),
                        const SizedBox(width: 12),
                        SizedBox(width: 200, child: DestinationCard(imageUrl: 'https://picsum.photos/400/300?random=3', name: 'Paris', location: 'France', rating: 4.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Upcoming Trip', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.push('/trips'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.blueGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CachedNetworkImage(imageUrl: 'https://picsum.photos/100/100?random=10', width: 64, height: 64, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Trip to Tokyo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                                SizedBox(height: 4),
                                Text('Mar 15 - Mar 22 • 7 days', style: TextStyle(fontSize: 13, color: Colors.white70)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
