import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../services/trip_service.dart';
import '../services/saved_search_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart';
import '../config/supabase_config.dart';

// ── Providers ──

final _followedTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final sb = SupabaseConfig.client;
  final follows = await sb
      .from('trip_follows')
      .select('trip_id')
      .eq('user_id', user.id);
  final tripIds =
      (follows as List).map((f) => f['trip_id'] as String).toList();
  if (tripIds.isEmpty) return [];
  final tripsData = await sb
      .from('trips')
      .select()
      .inFilter('id', tripIds)
      .order('created_at', ascending: false);
  return (tripsData as List).map((e) => Trip.fromJson(e)).toList();
});

class SavedPlacesScreen extends ConsumerStatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Saved Places',
                          style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Saved Trips'),
                      Tab(text: 'Saved Searches'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SavedTripsTab(),
                _SavedSearchesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedTripsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(_followedTripsProvider);

    return tripsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue)),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline,
              size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Failed to load saved trips',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.invalidate(_followedTripsProvider),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ]),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bookmark_border,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No saved trips yet',
                  style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              const Text('Follow trips to see them here',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ]),
          );
        }

        return RefreshIndicator(
          color: AppColors.brandBlue,
          onRefresh: () async => ref.invalidate(_followedTripsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: trips.length,
            itemBuilder: (_, i) => _SavedTripCard(trip: trips[i]),
          ),
        );
      },
    );
  }
}

class _SavedTripCard extends ConsumerWidget {
  final Trip trip;
  const _SavedTripCard({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = [
      if (trip.startDate != null) trip.startDate!.substring(0, 10),
      if (trip.endDate != null) trip.endDate!.substring(0, 10),
    ].join(' - ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/itinerary', extra: trip),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trip.coverImage != null)
              CachedNetworkImage(
                imageUrl: trip.coverImage!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(height: 140, color: AppColors.background),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.title,
                      style: GoogleFonts.dmSans(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(trip.destination,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                  if (dates.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(dates,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await TripFollowService.instance.unfollow(trip.id);
                        ref.invalidate(_followedTripsProvider);
                      },
                      icon: const Icon(Icons.bookmark_remove_outlined, size: 16),
                      label: const Text('Unfollow'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedSearchesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchesAsync = ref.watch(savedFlightSearchesProvider);

    return searchesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brandBlue)),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline,
              size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Failed to load saved searches',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.invalidate(savedFlightSearchesProvider),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ]),
      ),
      data: (searches) {
        if (searches.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.flight_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No saved searches yet',
                  style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              const Text('Save flight searches to quickly find them',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ]),
          );
        }

        return RefreshIndicator(
          color: AppColors.brandBlue,
          onRefresh: () async => ref.invalidate(savedFlightSearchesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: searches.length,
            itemBuilder: (_, i) =>
                _SavedSearchCard(search: searches[i]),
          ),
        );
      },
    );
  }
}

class _SavedSearchCard extends ConsumerWidget {
  final SavedFlightSearch search;
  const _SavedSearchCard({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.flight_takeoff,
                size: 20, color: AppColors.brandBlue),
            const SizedBox(width: 8),
            Text(
              '${search.originCode} (${search.originName ?? search.originCode})',
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child:
                  Icon(Icons.arrow_forward, size: 16, color: AppColors.brandBlue),
            ),
            Expanded(
              child: Text(
                '${search.destinationCode} (${search.destinationName ?? search.destinationCode})',
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.airline_seat_recline_normal,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(search.travelClass,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            const Icon(Icons.person_outline,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${search.adults} adult${search.adults > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/flight-search'),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                await SavedSearchService.instance.deleteSearch(search.id);
                ref.invalidate(savedFlightSearchesProvider);
              },
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.textSecondary),
            ),
          ]),
        ],
      ),
    );
  }
}
