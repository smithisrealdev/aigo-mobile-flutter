import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';
import '../models/public_guide.dart';
import '../services/public_guide_service.dart';

// Provider to fetch template/public trips
final _templateTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final resp = await SupabaseConfig.client
      .from('trips')
      .select()
      .eq('is_public', true)
      .order('created_at', ascending: false)
      .limit(50);
  return (resp as List).map((j) => Trip.fromJson(j)).toList();
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  int _selectedFilter = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _filters = [
    'All Templates',
    'Adventure',
    'Romantic',
    'Cultural',
    'Beach',
    'Budget',
  ];

  // Fallback featured items when no data from backend
  final List<Map<String, String>> _featured = [
    {'title': 'Southeast Asia Explorer', 'subtitle': '5 countries in 30 days', 'badge': 'FEATURED', 'image': 'https://images.unsplash.com/photo-1528181304800-259b08848526?w=520&h=320&fit=crop'},
    {'title': 'European Classics', 'subtitle': 'Paris, Rome & Barcelona', 'badge': 'CURATED', 'image': 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=520&h=320&fit=crop'},
    {'title': 'Island Paradise', 'subtitle': 'Maldives & Bali retreat', 'badge': 'TRENDING', 'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=520&h=320&fit=crop'},
  ];

  // Fallback templates
  final List<Map<String, String>> _fallbackTemplates = [
    {'name': 'Kyoto Heritage', 'country': 'Japan', 'days': '5 Days', 'image': 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&h=240&fit=crop'},
    {'name': 'Santorini Escape', 'country': 'Greece', 'days': '4 Days', 'image': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=400&h=240&fit=crop'},
    {'name': 'Machu Picchu Trek', 'country': 'Peru', 'days': '7 Days', 'image': 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=400&h=240&fit=crop'},
    {'name': 'Dubai Luxury', 'country': 'UAE', 'days': '3 Days', 'image': 'https://images.unsplash.com/photo-1504150558240-0b4fd8946624?w=400&h=240&fit=crop'},
    {'name': 'Sydney Adventure', 'country': 'Australia', 'days': '6 Days', 'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&h=240&fit=crop'},
    {'name': 'Maldives Retreat', 'country': 'Maldives', 'days': '5 Days', 'image': 'https://images.unsplash.com/photo-1518548419970-58e3b4079ab2?w=400&h=240&fit=crop'},
  ];

  List<Trip> _filterAndSearch(List<Trip> trips) {
    var result = trips;
    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q) || t.destination.toLowerCase().contains(q)).toList();
    }
    // Category filter
    if (_selectedFilter > 0) {
      final cat = _filters[_selectedFilter].toLowerCase();
      result = result.where((t) => (t.category ?? '').toLowerCase().contains(cat) || t.title.toLowerCase().contains(cat)).toList();
    }
    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(_templateTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildFilterChips()),
          SliverToBoxAdapter(child: _buildSectionHeader('Featured Collections', 'View All')),
          SliverToBoxAdapter(child: _buildFeaturedCards()),
          // Public Guides from Supabase
          SliverToBoxAdapter(child: _buildSectionHeader('Travel Guides', 'See All')),
          SliverToBoxAdapter(child: _buildPublicGuidesSection()),
          SliverToBoxAdapter(child: _buildSectionHeader('Explore Templates', 'See All')),
          templatesAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.brandBlue)))),
            error: (_, __) => _buildFallbackTemplateGrid(),
            data: (trips) {
              final filtered = _filterAndSearch(trips);
              if (filtered.isEmpty && trips.isEmpty) return _buildFallbackTemplateGrid();
              if (filtered.isEmpty) {
                return SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('No templates match your search', style: TextStyle(color: AppColors.textSecondary))),
                ));
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildTripTemplateCard(filtered[i]),
                    childCount: filtered.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.78),
                ),
              );
            },
          ),
          SliverToBoxAdapter(child: _buildBottomCTA()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildTripTemplateCard(Trip trip) {
    final startDate = trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;
    final endDate = trip.endDate != null ? DateTime.tryParse(trip.endDate!) : null;
    final days = (startDate != null && endDate != null) ? '${endDate.difference(startDate).inDays} Days' : '';
    final imageUrl = trip.coverImage ?? 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400&h=240&fit=crop';

    return GestureDetector(
      onTap: () => context.push('/itinerary', extra: trip),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(imageUrl: imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(height: 120, color: AppColors.border)),
              ),
              if (days.isNotEmpty)
                Positioned(top: 8, right: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text(days, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                )),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(trip.destination, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  SliverPadding _buildFallbackTemplateGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _buildTemplateCard(_fallbackTemplates[i]),
          childCount: _fallbackTemplates.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.78),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Discover Your Next Journey', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)))),
                IconButton(icon: const Icon(Icons.search, color: Color(0xFF9CA3AF)), onPressed: () => context.push('/search-results'), tooltip: 'Search'),
                IconButton(icon: const Icon(Icons.bookmark_outline, color: Color(0xFF9CA3AF)), onPressed: () => context.push('/saved-places'), tooltip: 'Saved'),
              ]),
              const SizedBox(height: 4),
              const Text('Go places and see the world', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: const InputDecoration(
            hintText: 'Where do you want to go?',
            hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = _selectedFilter == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandBlue : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: selected ? null : Border.all(color: const Color(0xFFD1D5DB)),
                ),
                alignment: Alignment.center,
                child: Text(_filters[i], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(action, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
        ],
      ),
    );
  }

  Widget _buildFeaturedCards() {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final item = _featured[i];
          return GestureDetector(
            onTap: () {
              final title = item['title'] ?? '';
              // Extract destination from title (e.g. "Southeast Asia Explorer" → "Southeast Asia")
              final dest = title.replaceAll(RegExp(r'\s*(Explorer|Adventure|Journey|Trip|Tour)$', caseSensitive: false), '').trim();
              context.push('/destination-guide?destination=${Uri.encodeComponent(dest)}');
            },
            child: Container(
              width: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(image: NetworkImage(item['image']!), fit: BoxFit.cover),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]),
                ),
                child: Stack(children: [
                  Positioned(top: 10, left: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(12)),
                    child: Text(item['badge']!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  )),
                  Positioned(top: 10, right: 10, child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_border, color: Colors.white, size: 18),
                  )),
                  Positioned(bottom: 12, left: 12, right: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['title']!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(item['subtitle']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, String> t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(t['image']!, height: 120, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 120, color: AppColors.border)),
          ),
          Positioned(top: 8, right: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Text(t['days']!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          )),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(t['country']!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPublicGuidesSection() {
    final guidesAsync = ref.watch(featuredGuidesProvider);
    return guidesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: AppColors.brandBlue)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (guides) {
        if (guides.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 200,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: guides.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _buildGuideCard(guides[i]),
          ),
        );
      },
    );
  }

  Widget _buildGuideCard(PublicGuide guide) {
    return GestureDetector(
      onTap: () {
        PublicGuideService.instance.incrementViews(guide.id);
        context.push('/destination-guide?destination=${Uri.encodeComponent(guide.destination)}');
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (guide.coverImage != null)
              CachedNetworkImage(
                imageUrl: guide.coverImage!,
                height: 100,
                width: 160,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(height: 100, color: const Color(0xFFF3F4F6)),
                errorWidget: (_, __, ___) => Container(height: 100, color: const Color(0xFFF3F4F6), child: const Icon(Icons.image, color: AppColors.textSecondary)),
              )
            else
              Container(height: 100, color: const Color(0xFFF3F4F6), child: const Icon(Icons.map, color: AppColors.textSecondary, size: 32)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guide.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(guide.destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                    if (guide.totalDays > 0) Text('${guide.totalDays}d', style: const TextStyle(color: AppColors.brandBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCTA() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Text("Can't find what you're looking for?", style: TextStyle(color: Color(0xFF111827), fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () => context.push('/ai-chat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
          child: const Text('Create Custom Trip', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
