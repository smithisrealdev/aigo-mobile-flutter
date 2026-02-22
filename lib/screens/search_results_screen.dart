import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/trip_service.dart';
import '../services/public_guide_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart';
import '../models/public_guide.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});
  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  List<Trip> _trips = [];
  List<PublicGuide> _guides = [];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (value.trim().length >= 2) {
        _search(value.trim());
      } else {
        setState(() {
          _query = '';
          _trips = [];
          _guides = [];
        });
      }
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _query = query;
      _loading = true;
    });

    try {
      final user = ref.read(currentUserProvider);
      final results = await Future.wait([
        // Search user's trips
        () async {
          if (user == null) return <Trip>[];
          final all = await TripService.instance.listTrips();
          final q = query.toLowerCase();
          return all
              .where((t) =>
                  t.title.toLowerCase().contains(q) ||
                  t.destination.toLowerCase().contains(q))
              .toList();
        }(),
        // Search public guides
        PublicGuideService.instance.searchGuides(query, limit: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _trips = results[0] as List<Trip>;
        _guides = results[1] as List<PublicGuide>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _trips.isNotEmpty || _guides.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(gradient: AppColors.blueGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: GoogleFonts.dmSans(
                            fontSize: 15, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search trips, guides, places...',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 15),
                          border: InputBorder.none,
                          icon: Icon(Icons.search,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: _onQueryChanged,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          // Body
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandBlue))
                : _query.isEmpty
                    ? _buildEmpty()
                    : hasResults
                        ? _buildResults()
                        : _buildNoResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('Search for trips, guides, and places',
            style: GoogleFonts.dmSans(
                fontSize: 15, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('No results for "$_query"',
            style: GoogleFonts.dmSans(
                fontSize: 15, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_trips.isNotEmpty) ...[
          _sectionTitle('Your Trips', Icons.map_outlined),
          const SizedBox(height: 8),
          ..._trips.map(_tripCard),
          const SizedBox(height: 20),
        ],
        if (_guides.isNotEmpty) ...[
          _sectionTitle('Public Guides', Icons.menu_book_outlined),
          const SizedBox(height: 8),
          ..._guides.map(_guideCard),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.brandBlue),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
    ]);
  }

  Widget _tripCard(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: () => context.push('/itinerary', extra: trip),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brandBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.flight_takeoff,
              color: AppColors.brandBlue, size: 22),
        ),
        title: Text(trip.title,
            style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(trip.destination,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right,
            size: 20, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _guideCard(PublicGuide guide) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: () => context.push('/place-detail', extra: {
          'placeId': guide.id,
          'placeName': guide.destination,
        }),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book,
              color: AppColors.success, size: 22),
        ),
        title: Text(guide.title,
            style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${guide.destination} - ${guide.totalDays} days',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right,
            size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}
