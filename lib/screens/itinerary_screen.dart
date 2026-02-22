import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/trip_map_view.dart';
import '../widgets/booking_options_widget.dart';
import '../widgets/upgrade_dialog.dart';
import '../models/models.dart';
import '../services/itinerary_service.dart';
import '../services/trip_service.dart';
import '../services/replan_service.dart';
import '../services/permission_service.dart';
import '../services/rate_limit_service.dart' as quota;
import '../widgets/trip_checklist_widget.dart';
import '../widgets/trip_reservations_widget.dart';
import '../widgets/trip_members_widget.dart';
import '../widgets/share_trip_widget.dart';
import '../widgets/trip_alerts_widget.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  final Trip? trip;
  const ItineraryScreen({super.key, this.trip});
  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen>
    with TickerProviderStateMixin {
  int _selectedDay = 0;
  bool _fabExpanded = false;
  bool _isBookmarked = false;
  bool _showMap = false;
  bool _regenerating = false;
  bool _replanning = false;
  String _activeSection = 'itinerary';
  bool _insightExpanded = false;
  final ScrollController _scrollController = ScrollController();

  // Staggered animation
  late AnimationController _staggerController;
  

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Trip? get _trip => widget.trip;

  List<Map<String, dynamic>> get _days {
    final data = _trip?.itineraryData;
    if (data == null) return _fallbackDays;
    final daysList = data['days'] ?? data['itinerary']?['days'];
    if (daysList is List && daysList.isNotEmpty) {
      return daysList.map((d) => d is Map<String, dynamic> ? d : <String, dynamic>{}).toList();
    }
    return _fallbackDays;
  }

  static final _fallbackDays = [
    {'title': 'Exploring Day 1', 'date': 'Day 1', 'activities': []},
  ];

  List<Map<String, dynamic>> get _currentActivities {
    if (_selectedDay >= _days.length) return [];
    final day = _days[_selectedDay];
    final acts = day['activities'] ?? day['places'] ?? [];
    if (acts is List) return acts.map((a) => a is Map<String, dynamic> ? a : <String, dynamic>{}).toList();
    return [];
  }

  List<MapActivity> get _mapActivities {
    return _currentActivities.where((a) => a['lat'] != null && a['lng'] != null).map((a) {
      return MapActivity(
        name: a['name'] ?? a['title'] ?? 'Activity',
        time: a['time'] ?? '',
        lat: (a['lat'] as num).toDouble(),
        lng: (a['lng'] as num).toDouble(),
      );
    }).toList();
  }

  String get _tripTitle => _trip?.title ?? 'Trip Itinerary';
  String get _tripDestination => _trip?.destination ?? '';
  String get _tripDateRange {
    if (_trip?.startDate == null) return '';
    final start = DateTime.tryParse(_trip!.startDate!);
    final end = _trip!.endDate != null ? DateTime.tryParse(_trip!.endDate!) : null;
    if (start == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final s = '${m[start.month - 1]} ${start.day}';
    if (end != null) return '$s - ${m[end.month - 1]} ${end.day}, ${end.year}';
    return '$s, ${start.year}';
  }

  // --- Category icon inference ---
  static const _categoryKeywords = <String, List<String>>{
    'restaurant': ['restaurant', 'food', 'eat', 'dining', 'cafe', 'coffee', 'lunch', 'dinner', 'breakfast', 'brunch', 'bistro', 'ramen', 'sushi', 'noodle', 'street food', 'hawker'],
    'temple': ['temple', 'shrine', 'wat', 'pagoda', 'mosque', 'church', 'cathedral', 'spiritual'],
    'museum': ['museum', 'gallery', 'art', 'exhibition', 'cultural center'],
    'park': ['park', 'garden', 'nature', 'forest', 'hiking', 'trail', 'mountain', 'waterfall', 'lake'],
    'shopping': ['shopping', 'mall', 'market', 'bazaar', 'outlet', 'souvenir', 'shop', 'store'],
    'beach': ['beach', 'coast', 'island', 'snorkel', 'diving', 'surf', 'seaside', 'bay'],
    'hotel': ['hotel', 'resort', 'hostel', 'check-in', 'check-out', 'accommodation', 'stay', 'airbnb'],
    'transport': ['airport', 'station', 'transfer', 'taxi', 'train', 'bus', 'ferry', 'flight', 'drive', 'transport'],
  };

  static const _categoryIcons = <String, IconData>{
    'restaurant': Icons.restaurant,
    'temple': Icons.temple_buddhist,
    'museum': Icons.museum,
    'park': Icons.park,
    'shopping': Icons.shopping_bag,
    'beach': Icons.beach_access,
    'hotel': Icons.hotel,
    'transport': Icons.directions_car,
  };

  static const _categoryColors = <String, Color>{
    'restaurant': Color(0xFFF59E0B),
    'temple': Color(0xFFEF4444),
    'museum': Color(0xFF8B5CF6),
    'park': Color(0xFF10B981),
    'shopping': Color(0xFFEC4899),
    'beach': Color(0xFF06B6D4),
    'hotel': Color(0xFF6366F1),
    'transport': Color(0xFF6B7280),
  };

  String _inferCategory(Map<String, dynamic> activity) {
    // Direct category/type field
    final explicit = (activity['type'] ?? activity['category'] ?? '').toString().toLowerCase();
    for (final cat in _categoryKeywords.keys) {
      if (explicit.contains(cat)) return cat;
    }
    // Keyword inference from name + description
    final text = '${activity['name'] ?? ''} ${activity['title'] ?? ''} ${activity['description'] ?? ''} ${activity['subtitle'] ?? ''}'.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (text.contains(kw)) return entry.key;
      }
    }
    return 'default';
  }

  IconData _iconForCategory(String cat) => _categoryIcons[cat] ?? Icons.place;
  Color _colorForCategory(String cat) => _categoryColors[cat] ?? AppColors.brandBlue;

  /// Permission-aware check before AI actions.
  Future<bool> _checkAiQuota() async {
    final result = await quota.RateLimitService.instance.canUseAi();
    if (result['can_use'] != true) {
      if (mounted) {
        showUpgradeDialog(
          context, ref,
          currentUsage: result['current_usage'] as int? ?? 0,
          monthlyLimit: result['monthly_limit'] as int? ?? 10,
          planName: 'Free',
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _handleRegenerate() async {
    if (_trip == null || _regenerating) return;
    if (!await _checkAiQuota()) return;

    setState(() => _regenerating = true);
    try {
      await ItineraryService.instance.generateItinerary(
        params: GenerateItineraryParams(
          destination: _trip!.destination,
          startDate: _trip!.startDate ?? '',
          endDate: _trip!.endDate ?? '',
        ),
      );
      await quota.RateLimitService.instance.incrementAiUsage();
      ref.invalidate(quota.aiQuotaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary regenerated!')));
        ref.invalidate(tripProvider(_trip!.id));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _handleSmartReplan() async {
    if (_trip == null || _replanning) return;
    if (!await _checkAiQuota()) return;

    setState(() => _replanning = true);
    try {
      final result = await ReplanService.instance.replanDay(
        tripId: _trip!.id,
        tripData: _trip!.itineraryData ?? {},
        dayIndex: _selectedDay,
      );
      await quota.RateLimitService.instance.incrementAiUsage();
      ref.invalidate(quota.aiQuotaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.success ? '${result.summary}' : result.summary)),
        );
        if (result.success) ref.invalidate(tripProvider(_trip!.id));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Replan failed: $e')));
    } finally {
      if (mounted) setState(() => _replanning = false);
    }
  }

  Future<void> _handleSwapPlace(Map<String, dynamic> activity) async {
    if (_trip == null) return;
    final alternatives = await ReplanService.instance.suggestAlternatives(
      placeId: activity['id']?.toString() ?? '',
      placeName: activity['name']?.toString() ?? activity['title']?.toString() ?? '',
      category: activity['category']?.toString() ?? activity['type']?.toString() ?? '',
      destination: _trip!.destination,
      lat: (activity['lat'] as num?)?.toDouble(),
      lng: (activity['lng'] as num?)?.toDouble(),
    );
    if (!mounted || alternatives.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No alternatives found')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alternative Places', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...alternatives.take(5).map((alt) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: AppColors.brandBlue.withValues(alpha: 0.1), child: const Icon(Icons.place, color: AppColors.brandBlue, size: 20)),
              title: Text(alt.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(alt.category, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: alt.cost != null ? Text('${alt.currency ?? '\u0E3F'}${alt.cost!.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.brandBlue)) : null,
              onTap: () => Navigator.pop(ctx),
            )),
          ],
        ),
      ),
    );
  }

  void _onDaySelected(int index) {
    if (index == _selectedDay) return;
    setState(() {
      
      _selectedDay = index;
      _staggerController.reset();
      _staggerController.forward();
    });
    // Scroll to top when switching days (#12)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final activities = _currentActivities;

    final roleAsync = _trip != null
        ? ref.watch(tripRoleProvider(_trip!.id))
        : const AsyncData<String>('owner');

    final role = roleAsync.value ?? 'viewer';
    final perm = PermissionService.instance;
    final canEdit = perm.canEditActivities(role);
    final isOwner = perm.canManageMembers(role);

    final coverImage = _trip?.coverImage ?? _heroImageUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canEdit ? _buildExpandableFab() : null,
      body: GestureDetector(
        onTap: () {
          if (_fabExpanded) setState(() => _fabExpanded = false);
        },
        child: _showMap
            ? Column(
                children: [
                  _buildSimpleAppBar(role),
                  Expanded(
                    child: TripMapView(activities: _mapActivities.isNotEmpty ? _mapActivities : const [
                      MapActivity(name: 'No locations', time: '', lat: 35.6762, lng: 139.6503),
                    ]),
                  ),
                ],
              )
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // #5: SliverAppBar with collapsing hero
                  SliverAppBar(
                    expandedHeight: 260,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: AppColors.brandBlue,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(coverImage),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.45), BlendMode.darken),
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: back + title
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(
                                      _tripTitle,
                                      style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                  ],
                                ),
                                // Second row: role badge + date + bookmark + share
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(28, 6, 0, 0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                                        child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                                      ),
                                      const SizedBox(width: 10),
                                      if (_tripDateRange.isNotEmpty) ...[
                                        const Icon(Icons.calendar_today, color: Colors.white70, size: 12),
                                        const SizedBox(width: 4),
                                        Flexible(child: Text(_tripDateRange, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      ],
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => setState(() => _isBookmarked = !_isBookmarked),
                                        child: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Colors.white, size: 22),
                                      ),
                                      if (perm.canShareTrip(role)) ...[
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () {},
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                              Icon(Icons.share, color: Colors.white, size: 14),
                                              SizedBox(width: 4),
                                              Text('Share', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                            ]),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Destination
                                if (_tripDestination.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(28, 4, 0, 0),
                                    child: Row(children: [
                                      const Icon(Icons.location_on, color: Colors.white70, size: 13),
                                      const SizedBox(width: 4),
                                      Text(_tripDestination, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      if (_trip != null) ...[
                                        const SizedBox(width: 8),
                                        TripMemberAvatars(tripId: _trip!.id),
                                      ],
                                    ]),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Pinned day tabs at bottom of app bar
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(56),
                      child: Container(
                        color: AppColors.brandBlue.withValues(alpha: 0.95),
                        padding: const EdgeInsets.only(bottom: 12, top: 8),
                        child: SizedBox(
                          height: 36,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.only(left: 20),
                                  itemCount: days.length,
                                  itemBuilder: (_, i) => GestureDetector(
                                    onTap: () => _onDaySelected(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedDay == i ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Text(
                                        'Day ${i + 1}',
                                        style: TextStyle(
                                          color: _selectedDay == i ? AppColors.brandBlue : Colors.white.withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w600, fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // List/Map toggle
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Container(
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    GestureDetector(
                                      onTap: () => setState(() => _showMap = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: !_showMap ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Icon(Icons.list, size: 18, color: !_showMap ? AppColors.brandBlue : Colors.white70),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() => _showMap = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _showMap ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Icon(Icons.map_outlined, size: 18, color: _showMap ? AppColors.brandBlue : Colors.white70),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), // #10: bottom safe area
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildAiChipsRow(),
                        const SizedBox(height: 16),

                        // Role badge for viewer
                        if (role == 'viewer')
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.visibility, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text('You are viewing this trip as a viewer',
                                style: GoogleFonts.dmSans(fontSize: 13, color: Colors.orange.shade800)),
                            ]),
                          ),

                        if (canEdit) ...[
                          _buildAiInsightCard(canEdit),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _replanning ? null : _handleSmartReplan,
                              icon: _replanning
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.auto_fix_high, size: 16),
                              label: Text(_replanning ? 'Replanning...' : 'Smart Replan Day ${_selectedDay + 1}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brandBlue,
                                side: BorderSide(color: AppColors.brandBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Section tabs
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final entry in [
                                ('itinerary', 'Itinerary', Icons.map_outlined),
                                ('checklist', 'Checklist', Icons.checklist),
                                ('reservations', 'Reservations', Icons.receipt_long),
                                ('alerts', 'Alerts', Icons.notifications_outlined),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _activeSection = entry.$1),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: _activeSection == entry.$1 ? AppColors.brandBlue : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _activeSection == entry.$1 ? AppColors.brandBlue : AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(entry.$3, size: 14, color: _activeSection == entry.$1 ? Colors.white : AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(entry.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _activeSection == entry.$1 ? Colors.white : AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section content
                        if (_activeSection == 'itinerary') ...[
                          _buildDayHeader(days),
                          const SizedBox(height: 12),
                          if (activities.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                              child: Center(child: Text('No activities for this day', style: TextStyle(color: AppColors.textSecondary))),
                            )
                          else
                            ..._buildActivityList(activities, canEdit: canEdit),
                        ],
                        if (_activeSection == 'checklist' && _trip != null)
                          TripChecklistWidget(tripId: _trip!.id),
                        if (_activeSection == 'reservations' && _trip != null)
                          TripReservationsWidget(tripId: _trip!.id),
                        if (_activeSection == 'alerts' && _trip != null)
                          TripAlertsWidget(tripId: _trip!.id),

                        // Share + Members sections
                        if (_trip != null) ...[
                          const SizedBox(height: 20),
                          if (isOwner) ShareTripWidget(tripId: _trip!.id),
                          if (isOwner) const SizedBox(height: 16),
                          TripMembersWidget(tripId: _trip!.id),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Simple app bar for map mode (keeps back button + day tabs)
  Widget _buildSimpleAppBar(String role) {
    final days = _days;
    return Container(
      color: AppColors.brandBlue,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_tripTitle, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 20),
                      itemCount: days.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _onDaySelected(i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedDay == i ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Day ${i + 1}',
                            style: TextStyle(
                              color: _selectedDay == i ? AppColors.brandBlue : Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600, fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: () => setState(() => _showMap = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: !_showMap ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.list, size: 18, color: !_showMap ? AppColors.brandBlue : Colors.white70),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showMap = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showMap ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.map_outlined, size: 18, color: _showMap ? AppColors.brandBlue : Colors.white70),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Fallback hero image based on destination
  String get _heroImageUrl {
    final dest = _tripDestination.toLowerCase();
    if (dest.contains('japan') || dest.contains('tokyo')) return 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&q=80';
    if (dest.contains('thai') || dest.contains('bangkok')) return 'https://images.unsplash.com/photo-1563492065599-3520f775eeed?w=800&q=80';
    if (dest.contains('paris') || dest.contains('france')) return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&q=80';
    if (dest.contains('london') || dest.contains('uk')) return 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80';
    if (dest.contains('bali') || dest.contains('indonesia')) return 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&q=80';
    if (dest.contains('korea') || dest.contains('seoul')) return 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=800&q=80';
    return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&q=80';
  }

  Widget _buildAiChipsRow() {
    return Row(children: [
      _aiChip('AI Generated', AppColors.brandBlue, Icons.auto_awesome),
      const SizedBox(width: 8),
      _aiChip('Tailored for you', AppColors.success, Icons.person),
      const SizedBox(width: 8),
      _aiChip('Offline ready', const Color(0xFF6B7280), Icons.cloud_done),
    ]);
  }

  Widget _aiChip(String label, Color color, IconData icon) {
    return Container(
      height: 28, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _buildAiInsightCard(bool canEdit) {
    final prefs = _trip?.itineraryData?['preferences'] as List? ?? ['Nature', 'Slow Travel', 'Local Food'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _insightExpanded = !_insightExpanded),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.brandBlue),
            const SizedBox(width: 6),
            Expanded(child: Text('Optimized for your travel style', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            AnimatedRotation(
              turns: _insightExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more, size: 20, color: AppColors.textSecondary),
            ),
          ]),
        ),
        // #1: Only show content when explicitly expanded
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8, runSpacing: 8,
                children: (prefs.map((t) => t.toString()).toList()).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(16)),
                    child: Text(tag, style: const TextStyle(fontSize: 12, color: AppColors.brandBlue, fontWeight: FontWeight.w500)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              const Text('Based on your preferences', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
              if (canEdit) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _regenerating ? null : _handleRegenerate,
                      icon: _regenerating
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 14),
                      label: Text(_regenerating ? 'Generating...' : 'Regenerate', style: const TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandBlue,
                        side: const BorderSide(color: AppColors.brandBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('Optimize', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandBlue, foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          crossFadeState: _insightExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ]),
    );
  }

  static String _formatNum(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildDayHeader(List<Map<String, dynamic>> days) {
    if (_selectedDay >= days.length) return const SizedBox.shrink();
    final day = days[_selectedDay];
    final title = day['title'] ?? day['name'] ?? 'Day ${_selectedDay + 1}';
    final date = day['date'] ?? '';

    final spent = (_trip?.budgetSpent ?? 0) / (days.length > 0 ? days.length : 1);
    final total = (_trip?.budgetTotal ?? 0) / (days.length > 0 ? days.length : 1);
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final barColor = pct < 0.8 ? AppColors.brandBlue : AppColors.error;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(12)),
          child: Text('Day ${_selectedDay + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (date.toString().isNotEmpty) Text(date.toString(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(title.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
      if (total > 0) ...[
        const SizedBox(height: 8),
        Row(children: [
          Text('\u0E3F${_formatNum(spent.toInt())} / \u0E3F${_formatNum(total.toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(width: 10),
          // #3: Thicker budget bar
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(barColor), minHeight: 5),
          )),
        ]),
      ],
    ]);
  }

  List<Widget> _buildActivityList(List<Map<String, dynamic>> activities, {required bool canEdit}) {
    final widgets = <Widget>[];
    for (var i = 0; i < activities.length; i++) {
      final a = activities[i];
      final name = (a['name'] ?? a['title'] ?? 'Activity').toString();
      final time = (a['time'] ?? a['start_time'] ?? '').toString();
      final desc = (a['description'] ?? a['subtitle'] ?? '').toString();
      final duration = (a['duration'] ?? a['estimated_duration'] ?? '').toString();
      final category = _inferCategory(a);

      // #7: Staggered fade-in animation
      final delay = (i * 0.1).clamp(0.0, 0.8);
      final animation = CurvedAnimation(
        parent: _staggerController,
        curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut),
      );

      widgets.add(
        FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
            child: _buildEnhancedActivityCard(
              time: time,
              title: name,
              subtitle: desc,
              duration: duration,
              icon: _iconForCategory(category),
              iconColor: _colorForCategory(category),
              showSwapBadge: canEdit && i == 0,
              showDragHandle: canEdit,
              placeName: name,
            ),
          ),
        ),
      );
      // #8: Better timeline connector
      if (i < activities.length - 1) widgets.add(_timelineDivider());
    }
    return widgets;
  }

  Widget _buildEnhancedActivityCard({
    required String time, required String title, required String subtitle,
    required String duration,
    required IconData icon, required Color iconColor,
    bool showSwapBadge = false, bool showDragHandle = true,
    required String placeName,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        // #11: Uniform shadow
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // #6: Place photo thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            child: SizedBox(
              width: 80,
              height: 100,
              child: Image.network(
                'https://source.unsplash.com/200x200/?${Uri.encodeComponent(placeName)},travel',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: iconColor.withValues(alpha: 0.1),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: iconColor.withValues(alpha: 0.06),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: iconColor))),
                  );
                },
              ),
            ),
          ),
          // Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // #4: Time display + duration badge
                  Row(children: [
                    if (time.isNotEmpty) ...[
                      Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                    // #9: Duration badge
                    if (duration.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(duration.startsWith('~') ? duration : '~$duration', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                      ),
                    ],
                    const Spacer(),
                    if (showSwapBadge) Icon(Icons.swap_horiz, size: 16, color: AppColors.brandBlue.withValues(alpha: 0.6)),
                    if (showDragHandle) const Icon(Icons.drag_indicator, color: AppColors.textSecondary, size: 16),
                  ]),
                  const SizedBox(height: 4),
                  // Category icon + title
                  Row(children: [
                    Icon(icon, size: 14, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  ]),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  BookingChip(placeName: title),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // #8: Enhanced timeline divider with dots
  Widget _timelineDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 38),
      child: SizedBox(
        height: 28,
        child: Column(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.3), shape: BoxShape.circle)),
            Expanded(
              child: CustomPaint(
                size: const Size(2, 16),
                painter: _DashedLinePainter(color: AppColors.border),
              ),
            ),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.3), shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableFab() {
    final fabItems = [
      {'icon': Icons.edit, 'label': 'Edit', 'color': AppColors.brandBlue},
      {'icon': Icons.map, 'label': 'Map', 'color': AppColors.success},
      {'icon': Icons.chat_bubble_outline, 'label': 'AI Chat', 'color': AppColors.warning},
      {'icon': Icons.auto_awesome, 'label': 'AI Optimize', 'color': AppColors.brandBlue},
    ];

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (_fabExpanded)
        ...fabItems.reversed.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)]),
                child: Text(item['label'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 48, height: 48, child: FloatingActionButton(
                heroTag: item['label'],
                mini: false,
                backgroundColor: item['color'] as Color,
                elevation: 4,
                onPressed: () {
                  setState(() => _fabExpanded = false);
                  if (item['label'] == 'AI Chat') context.push('/ai-chat');
                  if (item['label'] == 'Map') setState(() => _showMap = true);
                  if (item['label'] == 'AI Optimize') _handleRegenerate();
                },
                child: Icon(item['icon'] as IconData, color: Colors.white, size: 22),
              )),
            ]),
          );
        }),
      FloatingActionButton(
        heroTag: 'main_fab',
        backgroundColor: AppColors.brandBlue,
        onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
        child: AnimatedRotation(
          turns: _fabExpanded ? 0.125 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    ]);
  }
}

/// Custom painter for dashed vertical line
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashHeight = 3.0;
    const gap = 3.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, (y + dashHeight).clamp(0, size.height)), paint);
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
