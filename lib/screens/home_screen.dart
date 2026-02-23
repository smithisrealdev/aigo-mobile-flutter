import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/expense_service.dart';
import '../services/recommendation_service.dart';
import '../services/ai_picks_service.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedChipIndex = 0;

  static const _destinations = [
    {
      'title': 'Tokyo, Japan',
      'desc': 'Experience the perfect blend of tradition and modernity',
      'price': 1299,
      'rating': 4.8,
      'image':
          'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800'
    },
    {
      'title': 'Bali, Indonesia',
      'desc': 'Tropical paradise with stunning temples and beaches',
      'price': 899,
      'rating': 4.7,
      'image':
          'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800'
    },
    {
      'title': 'Paris, France',
      'desc': 'The city of light, love and unforgettable experiences',
      'price': 1599,
      'rating': 4.9,
      'image':
          'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800'
    },
    {
      'title': 'Chiang Mai, Thailand',
      'desc': 'Ancient temples, night markets, and mountain adventures',
      'price': 499,
      'rating': 4.6,
      'image':
          'https://images.unsplash.com/photo-1598935898639-81586f7d2129?w=800'
    },
  ];

  static const _chips = [
    {'label': 'Popular', 'icon': Icons.location_on_outlined},
    {'label': 'Budget', 'icon': Icons.attach_money},
    {'label': 'Adventure', 'icon': Icons.terrain},
    {'label': 'Beach', 'icon': Icons.beach_access_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 12),
            child: Row(
              children: [
                // Logo
                Text(
                  'aigo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.luggage_outlined,
                    color: AppColors.textPrimary, size: 22),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Color(0xFF9CA3AF), size: 24),
                  onPressed: () => context.push('/notifications'),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF3F4F6),
                    ),
                    child: const Icon(Icons.person,
                        color: Color(0xFF9CA3AF), size: 20),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: const Color(0xFFF3F4F6)),

          // ── Scrollable body ──
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Where to next?"
                  const Text(
                    'Where to next?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  GestureDetector(
                    onTap: () => context.push('/ai-chat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.searchBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Search destinations, cities...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter chips
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _chips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final selected = i == _selectedChipIndex;
                        final chip = _chips[i];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedChipIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.brandBlue
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: AppColors.border, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  chip['icon'] as IconData,
                                  size: 16,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  chip['label'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // "Featured Destinations"
                  const Text(
                    'Featured Destinations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Destination cards
                  ...List.generate(_destinations.length, (i) {
                    final d = _destinations[i];
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: i < _destinations.length - 1 ? 16 : 0),
                      child: _DestinationCard(
                        title: d['title'] as String,
                        desc: d['desc'] as String,
                        price: d['price'] as int,
                        rating: d['rating'] as double,
                        imageUrl: d['image'] as String,
                        onExplore: () => context.push('/ai-chat',
                            extra: 'Tell me about ${d['title']}'),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final String title;
  final String desc;
  final int price;
  final double rating;
  final String imageUrl;
  final VoidCallback? onExplore;

  const _DestinationCard({
    required this.title,
    required this.desc,
    required this.price,
    required this.rating,
    required this.imageUrl,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          AspectRatio(
            aspectRatio: 4 / 3,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.searchBackground),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.searchBackground,
                child: const Icon(Icons.image, size: 40, color: AppColors.border),
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.star, size: 16, color: AppColors.ratingGold),
                    const SizedBox(width: 3),
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'From \$${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandBlue,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onExplore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Explore',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
