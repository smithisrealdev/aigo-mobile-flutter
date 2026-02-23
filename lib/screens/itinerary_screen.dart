import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../widgets/trip_map_view.dart';
import '../widgets/upgrade_dialog.dart';
import '../models/models.dart';
import '../services/itinerary_service.dart';
import '../services/trip_service.dart';
import '../config/supabase_config.dart';
import '../services/replan_service.dart';
import '../services/permission_service.dart';
import '../services/rate_limit_service.dart' as quota;
import '../widgets/trip_checklist_widget.dart';
import '../widgets/trip_reservations_widget.dart';
import '../widgets/trip_members_widget.dart';
import '../widgets/share_trip_widget.dart';
import '../widgets/trip_alerts_widget.dart';
import '../widgets/activity_detail_sheet.dart';

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
  bool _tipsExpanded = false;
  final Set<int> _collapsedDays = {};
  final ScrollController _scrollController = ScrollController();
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  // ─── Data helpers ───
  Trip? get _trip => widget.trip;

  Map<String, dynamic>? get _travelIntel =>
      _trip?.itineraryData?['travelIntel'] as Map<String, dynamic>?;

  List<Map<String, dynamic>> get _days {
    final data = _trip?.itineraryData;
    if (data == null)
      return [
        {'title': 'Day 1', 'date': '', 'activities': []}
      ];
    final daysList = data['days'] ?? data['itinerary']?['days'];
    if (daysList is List && daysList.isNotEmpty) {
      return daysList
          .map((d) =>
              d is Map<String, dynamic> ? d : <String, dynamic>{})
          .toList();
    }
    return [
      {'title': 'Day 1', 'date': '', 'activities': []}
    ];
  }

  List<Map<String, dynamic>> _activitiesForDay(int dayIndex) {
    if (dayIndex >= _days.length) return [];
    final day = _days[dayIndex];
    final acts = day['activities'] ?? day['places'] ?? [];
    if (acts is List)
      return acts
          .map((a) =>
              a is Map<String, dynamic> ? a : <String, dynamic>{})
          .toList();
    return [];
  }

  List<Map<String, dynamic>> get _currentActivities =>
      _activitiesForDay(_selectedDay);

  List<Map<String, dynamic>> get _allActivities {
    final all = <Map<String, dynamic>>[];
    for (final day in _days) {
      final acts = day['activities'] ?? day['places'] ?? [];
      if (acts is List) {
        all.addAll(acts.map(
            (a) => a is Map<String, dynamic> ? a : <String, dynamic>{}));
      }
    }
    return all;
  }

  int get _totalPlaces => _allActivities.length;

  List<MapActivity> get _mapActivities {
    return _currentActivities.where((a) {
      final coords = a['coordinates'];
      return (a['lat'] != null && a['lng'] != null) ||
          (coords is Map && coords['lat'] != null && coords['lng'] != null);
    }).map((a) {
      final coords = a['coordinates'] as Map<String, dynamic>?;
      final lat = (a['lat'] as num?)?.toDouble() ??
          (coords?['lat'] as num?)?.toDouble() ??
          0.0;
      final lng = (a['lng'] as num?)?.toDouble() ??
          (coords?['lng'] as num?)?.toDouble() ??
          0.0;
      return MapActivity(
          name: a['name'] ?? a['title'] ?? '',
          time: a['time'] ?? '',
          lat: lat,
          lng: lng);
    }).toList();
  }

  String get _tripTitle => _trip?.title ?? 'Trip Itinerary';
  String get _tripDestination => _trip?.destination ?? '';
  String get _tripDateRange {
    if (_trip?.startDate == null) return '';
    final start = DateTime.tryParse(_trip!.startDate!);
    final end = _trip!.endDate != null
        ? DateTime.tryParse(_trip!.endDate!)
        : null;
    if (start == null) return '';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final s = '${m[start.month - 1]} ${start.day}';
    if (end != null) return '$s - ${m[end.month - 1]} ${end.day}, ${end.year}';
    return '$s, ${start.year}';
  }

  int get _dayCount {
    if (_trip?.startDate == null || _trip?.endDate == null) return _days.length;
    final start = DateTime.tryParse(_trip!.startDate!);
    final end = DateTime.tryParse(_trip!.endDate!);
    if (start == null || end == null) return _days.length;
    return end.difference(start).inDays + 1;
  }

  String get _seasonTag {
    if (_trip?.startDate == null) return '';
    final start = DateTime.tryParse(_trip!.startDate!);
    if (start == null) return '';
    final m = start.month;
    if (m >= 3 && m <= 5) return 'Spring';
    if (m >= 6 && m <= 8) return 'Summer';
    if (m >= 9 && m <= 11) return 'Autumn';
    return 'Winter';
  }

  String get _heroImageUrl {
    if (_trip?.coverImage != null && _trip!.coverImage!.isNotEmpty) {
      return _trip!.coverImage!;
    }
    final dest = _tripDestination.toLowerCase();
    if (dest.contains('japan') || dest.contains('tokyo'))
      return 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&q=80';
    if (dest.contains('italy') || dest.contains('tuscan') ||
        dest.contains('florence') || dest.contains('rome'))
      return 'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=800&q=80';
    if (dest.contains('thai') || dest.contains('bangkok'))
      return 'https://images.unsplash.com/photo-1563492065599-3520f775eeed?w=800&q=80';
    if (dest.contains('paris') || dest.contains('france'))
      return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&q=80';
    if (dest.contains('london') || dest.contains('uk'))
      return 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80';
    if (dest.contains('bali') || dest.contains('indonesia'))
      return 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&q=80';
    if (dest.contains('korea') || dest.contains('seoul'))
      return 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=800&q=80';
    if (dest.contains('swiss') || dest.contains('zurich'))
      return 'https://images.unsplash.com/photo-1530122037265-a5f1f91d3b99?w=800&q=80';
    return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&q=80';
  }

  // ─── Category inference ───
  static const _kw = <String, List<String>>{
    'restaurant': [
      'restaurant', 'food', 'eat', 'dining', 'cafe', 'coffee', 'lunch',
      'dinner', 'breakfast', 'brunch', 'bistro', 'ramen', 'sushi', 'noodle',
      'trattoria', 'osteria', 'pizz', 'gelat', 'wine', 'vinaio', 'sandwich'
    ],
    'temple': [
      'temple', 'shrine', 'wat', 'pagoda', 'mosque', 'church', 'cathedral',
      'duomo', 'basilica', 'chapel'
    ],
    'museum': [
      'museum', 'gallery', 'art', 'exhibition', 'uffizi', 'palazzo'
    ],
    'park': [
      'park', 'garden', 'nature', 'forest', 'hiking', 'trail', 'mountain',
      'waterfall', 'lake', 'piazza'
    ],
    'shopping': [
      'shopping', 'mall', 'market', 'bazaar', 'outlet', 'souvenir', 'shop',
      'store', 'mercato'
    ],
    'beach': [
      'beach', 'coast', 'island', 'snorkel', 'diving', 'surf', 'seaside',
      'bay', 'thermal', 'bath', 'spa'
    ],
    'hotel': [
      'hotel', 'resort', 'hostel', 'check-in', 'check-out', 'accommodation',
      'stay', 'airbnb'
    ],
    'transport': [
      'airport', 'station', 'transfer', 'taxi', 'train', 'bus', 'ferry',
      'flight', 'drive', 'transport'
    ],
  };
  static const _icons = <String, IconData>{
    'restaurant': Icons.restaurant,
    'temple': Icons.temple_buddhist,
    'museum': Icons.museum,
    'park': Icons.park,
    'shopping': Icons.shopping_bag,
    'beach': Icons.beach_access,
    'hotel': Icons.hotel,
    'transport': Icons.directions_car,
  };
  static const _catBadgeColors = <String, Color>{
    'restaurant': Color(0xFFEF4444),
    'temple': Color(0xFFF59E0B),
    'museum': Color(0xFF8B5CF6),
    'park': Color(0xFF10B981),
    'shopping': Color(0xFFEC4899),
    'beach': Color(0xFF06B6D4),
    'hotel': Color(0xFF6366F1),
    'transport': Color(0xFF64748B),
    'attraction': Color(0xFF1A5EFF),
  };

  String _inferCat(Map<String, dynamic> a) {
    final explicit =
        (a['type'] ?? a['category'] ?? '').toString().toLowerCase();
    for (final c in _kw.keys) {
      if (explicit.contains(c)) return c;
    }
    final text =
        '${a['name'] ?? ''} ${a['title'] ?? ''} ${a['description'] ?? ''}'
            .toLowerCase();
    for (final e in _kw.entries) {
      for (final k in e.value) {
        if (text.contains(k)) return e.key;
      }
    }
    return 'attraction';
  }

  // ─── AI quota ───
  Future<bool> _checkAiQuota() async {
    final r = await quota.RateLimitService.instance.canUseAi();
    if (r['can_use'] != true && mounted) {
      showUpgradeDialog(context, ref,
          currentUsage: r['current_usage'] as int? ?? 0,
          monthlyLimit: r['monthly_limit'] as int? ?? 10,
          planName: 'Free');
      return false;
    }
    return true;
  }

  Future<void> _handleRegenerate() async {
    if (_trip == null || _regenerating) return;
    if (!await _checkAiQuota()) return;
    setState(() => _regenerating = true);
    try {
      final itinerary = await ItineraryService.instance.generateItinerary(
          params: GenerateItineraryParams(
              destination: _trip!.destination,
              startDate: _trip!.startDate ?? '',
              endDate: _trip!.endDate ?? ''));
      await SupabaseConfig.client
          .from('trips')
          .update({'itinerary_data': itinerary, 'status': 'published'}).eq(
              'id', _trip!.id);
      await quota.RateLimitService.instance.incrementAiUsage();
      ref.invalidate(quota.aiQuotaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Itinerary regenerated!')));
        ref.invalidate(tripProvider(_trip!.id));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
          dayIndex: _selectedDay);
      await quota.RateLimitService.instance.incrementAiUsage();
      ref.invalidate(quota.aiQuotaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.summary)));
        if (result.success) ref.invalidate(tripProvider(_trip!.id));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Replan failed: $e')));
    } finally {
      if (mounted) setState(() => _replanning = false);
    }
  }

  Future<void> _handleSwapPlace(Map<String, dynamic> activity) async {
    if (_trip == null) return;
    final alternatives = await ReplanService.instance.suggestAlternatives(
        placeId: activity['id']?.toString() ?? '',
        placeName:
            (activity['name'] ?? activity['title'] ?? '').toString(),
        category:
            (activity['category'] ?? activity['type'] ?? '').toString(),
        destination: _trip!.destination,
        lat: (activity['lat'] as num?)?.toDouble(),
        lng: (activity['lng'] as num?)?.toDouble());
    if (!mounted || alternatives.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No alternatives found')));
      return;
    }
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alternative Places',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...alternatives.take(5).map((alt) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                            backgroundColor:
                                AppColors.brandBlue.withValues(alpha: 0.1),
                            child: const Icon(Icons.place,
                                color: AppColors.brandBlue, size: 20)),
                        title: Text(alt.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(alt.category,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        trailing: alt.cost != null
                            ? Text(
                                '${alt.currency ?? '\u0E3F'}${alt.cost!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandBlue))
                            : null,
                        onTap: () => Navigator.pop(ctx),
                      )),
                ])));
  }

  void _onDaySelected(int i) {
    if (i == _selectedDay) return;
    setState(() => _selectedDay = i);
    _staggerController.reset();
    _staggerController.forward();
    if (_scrollController.hasClients)
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String _friendlyDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[d.weekday - 1]}, ${m[d.month - 1]} ${d.day}';
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final days = _days;
    final roleAsync = _trip != null
        ? ref.watch(tripRoleProvider(_trip!.id))
        : const AsyncData<String>('owner');
    final role = roleAsync.value ?? 'viewer';
    final perm = PermissionService.instance;
    final canEdit = perm.canEditActivities(role);
    final isOwner = perm.canManageMembers(role);
    final coverImage = _trip?.coverImage ?? _heroImageUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: canEdit ? _buildFab() : null,
      body: Stack(children: [
        if (_showMap)
          Column(children: [
            _buildMapBar(role, days),
            Expanded(
                child: TripMapView(
                    activities: _mapActivities.isNotEmpty
                        ? _mapActivities
                        : const [
                            MapActivity(
                                name: '',
                                time: '',
                                lat: 35.6762,
                                lng: 139.6503)
                          ]))
          ])
        else
          CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── HERO HEADER ──
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppColors.brandBlue,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(children: [
                      // Cover image
                      Positioned.fill(
                          child: CachedNetworkImage(
                        imageUrl: coverImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.brandBlue),
                      )),
                      // Dark gradient overlay
                      Positioned.fill(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.7),
                            ]),
                      ))),
                      // Title + tags + date overlay
                      Positioned(
                          left: 20,
                          right: 20,
                          bottom: 80,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tags row
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  _heroTag('$_dayCount-day Itinerary'),
                                  if (_trip?.category != null &&
                                      _trip!.category!.isNotEmpty)
                                    _heroTag(_trip!.category!),
                                  if (_seasonTag.isNotEmpty)
                                    _heroTag(_seasonTag),
                                ]),
                                const SizedBox(height: 10),
                                Text(_tripTitle,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.2),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Row(children: [
                                  if (_tripDateRange.isNotEmpty) ...[
                                    const Icon(Icons.calendar_today,
                                        color: Colors.white70, size: 13),
                                    const SizedBox(width: 4),
                                    Text(_tripDateRange,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                  ],
                                  if (_tripDestination.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    const Icon(Icons.location_on,
                                        color: Colors.white70, size: 13),
                                    const SizedBox(width: 3),
                                    Text(_tripDestination,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                  ],
                                ]),
                              ])),
                      // Top bar: back + members + bookmark + share
                      Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          left: 12,
                          right: 12,
                          child: Row(children: [
                            _circleBtn(Icons.arrow_back_ios_new,
                                () => Navigator.maybePop(context)),
                            const Spacer(),
                            if (_trip != null)
                              TripMemberAvatars(tripId: _trip!.id),
                            const SizedBox(width: 8),
                            _circleBtn(
                                _isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                () => setState(
                                    () => _isBookmarked = !_isBookmarked)),
                            if (perm.canShareTrip(role)) ...[
                              const SizedBox(width: 8),
                              _circleBtn(Icons.ios_share, () {}),
                            ],
                          ])),
                    ]),
                  ),
                  // Pinned: Day tabs + section tabs
                  bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(88),
                      child: Column(children: [
                        // Day tabs
                        Container(
                          color: AppColors.brandBlue,
                          child: SizedBox(
                              height: 44,
                              child: Row(children: [
                                Expanded(
                                    child: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [Colors.white, Colors.white, Colors.transparent],
                                          stops: [0.0, 0.85, 1.0],
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.only(left: 16),
                                  itemCount: days.length,
                                  itemBuilder: (_, i) => GestureDetector(
                                    onTap: () => _onDaySelected(i),
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                          right: 6, top: 6, bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: _selectedDay == i
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(24)),
                                      child: Text('Day ${i + 1}',
                                          style: TextStyle(
                                              color: _selectedDay == i
                                                  ? AppColors.brandBlue
                                                  : Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ),
                                  ),
                                ))),
                                Container(
                                  margin: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _toggleBtn(Icons.view_list, !_showMap,
                                            () => setState(() => _showMap = false)),
                                        _toggleBtn(Icons.map_outlined, _showMap,
                                            () => setState(() => _showMap = true)),
                                      ]),
                                ),
                              ])),
                        ),
                        // Section segment control
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0F1F3),
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              for (final e in [
                                ('itinerary', 'Itinerary'),
                                ('checklist', 'Checklist'),
                                ('reservations', 'Reservations'),
                                ('alerts', 'Alerts')
                              ])
                                Expanded(
                                    child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _activeSection = e.$1),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _activeSection == e.$1
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _activeSection == e.$1
                                          ? [
                                              BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.06),
                                                  blurRadius: 4)
                                            ]
                                          : null,
                                    ),
                                    child: Text(e.$2,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _activeSection == e.$1
                                                ? AppColors.brandBlue
                                                : AppColors.textSecondary)),
                                  ),
                                )),
                            ]),
                          ),
                        ),
                      ])),
                ),

                // ── CONTENT ──
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    sliver: SliverList(
                        delegate: SliverChildListDelegate([
                      // Viewer banner
                      if (role == 'viewer') _viewerBanner(),

                      if (_activeSection == 'itinerary') ...[
                        // 1. Compact summary bar (merged Progress + Today's Plan)
                        _compactSummaryBar(),
                        const SizedBox(height: 12),

                        // 2. Destination segment header (multi-dest)
                        if (_destinationSegments.isNotEmpty)
                          ..._buildDestinationSegmentHeader(),

                        // 3. Day header + activities FIRST
                        _dayHeaderCard(),
                        const SizedBox(height: 8),

                        if (_currentActivities.isEmpty)
                          _emptyState()
                        else if (canEdit)
                          ..._buildReorderableActivities(_currentActivities)
                        else
                          ..._buildActivityCards(
                              _currentActivities, canEdit: false),
                      ],

                      if (_activeSection == 'checklist' && _trip != null) ...[
                        TripChecklistWidget(tripId: _trip!.id),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/packing-list', extra: _trip),
                              icon:
                                  const Icon(Icons.backpack_outlined, size: 18),
                              label: const Text('Generate Packing List'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.brandBlue,
                                  side: const BorderSide(
                                      color: AppColors.brandBlue),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12)),
                            )),
                      ],
                      if (_activeSection == 'reservations' && _trip != null)
                        TripReservationsWidget(tripId: _trip!.id),
                      if (_activeSection == 'alerts' && _trip != null)
                        TripAlertsWidget(tripId: _trip!.id),

                      // Trip-level info removed from Itinerary tab
                      // Budget → FAB Summary, Tips → FAB Travel Tips
                      // Reservations → Reservations tab, Share → FAB Share
                      const SizedBox(height: 80),
                    ]))),
              ]),
        // FAB backdrop overlay
        if (_fabExpanded)
          GestureDetector(
            onTap: () => setState(() => _fabExpanded = false),
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),
      ]),
    );
  }

  // ─── WIDGETS ───

  Widget _heroTag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _toggleBtn(IconData icon, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(20)),
          child: Icon(icon,
              size: 16,
              color: active ? AppColors.brandBlue : Colors.white70),
        ),
      );

  Widget _viewerBanner() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
        child: Row(children: [
          const Icon(Icons.visibility, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text('Viewing as a viewer',
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: Colors.orange.shade800)),
        ]),
      );

  // ─── Format Cost Helper ───
  String _formatCost(dynamic cost) {
    if (cost == null) return '';
    if (cost is Map) {
      final amount = cost['amount'];
      final currency = cost['currency'] ?? 'THB';
      if (amount == null || amount == 0) return 'Free';
      final symbol = currency == 'THB' ? '฿' : currency == 'EUR' ? '€' : currency == 'USD' ? '\$' : '$currency ';
      return '$symbol${amount is num ? amount.toStringAsFixed(0) : amount}';
    }
    if (cost is num) {
      if (cost == 0) return 'Free';
      return '฿${cost.toStringAsFixed(0)}';
    }
    return cost.toString();
  }

  // ─── Compact Summary Bar (merged Progress + Today's Plan) ───
  Widget _compactSummaryBar() {
    final total = _totalPlaces;
    const visited = 0;
    final pct = total > 0 ? visited / total : 0.0;
    final activities = _currentActivities;
    final nextUp = activities.isNotEmpty ? activities.first : null;
    final nextName = (nextUp?['name'] ?? nextUp?['title'] ?? '').toString();
    final nextTime = (nextUp?['startTime'] ?? nextUp?['time'] ?? nextUp?['start_time'] ?? '').toString();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Row(children: [
        // Mini circular progress
        SizedBox(
          width: 24,
          height: 24,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: pct,
              strokeWidth: 2.5,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
            Text('${(pct * 100).toInt()}',
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
        ),
        const SizedBox(width: 8),
        Text('$visited/$total places · $_dayCount days',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const Spacer(),
        if (nextUp != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.circular(6)),
            child: const Text('NEXT UP',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(nextName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (nextTime.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(nextTime,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
          ],
        ],
      ]),
    );
  }

  // ─── Progress Tracker ───
  Widget _progressTracker() {
    final total = _totalPlaces;
    // For now progress is 0 — would be tracked via visited state
    const visited = 0;
    final pct = total > 0 ? visited / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Row(children: [
        // Percentage circle
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: pct,
              strokeWidth: 4,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.brandBlue),
            ),
            Text('${(pct * 100).toInt()}%',
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Progress',
                  style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text('$visited / $total ${total == 1 ? 'place' : 'places'}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Text('$_dayCount days',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandBlue)),
        ),
      ]),
    );
  }

  // ─── Today's Plan Card ───
  Widget _todaysPlanCard() {
    final activities = _currentActivities;
    final placesCount = activities.length;
    // Calculate total sights (non-restaurant)
    final sightsCount = activities.where((a) {
      final cat = _inferCat(a);
      return cat != 'restaurant' && cat != 'hotel' && cat != 'transport';
    }).length;

    // Next up: first activity
    final nextUp = activities.isNotEmpty ? activities.first : null;
    final nextName =
        (nextUp?['name'] ?? nextUp?['title'] ?? '').toString();
    final nextTime =
        (nextUp?['startTime'] ?? nextUp?['time'] ?? nextUp?['start_time'] ?? '')
            .toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.brandBlue,
                  borderRadius: BorderRadius.circular(12)),
              child: Text('Day ${_selectedDay + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Text("Today's Plan",
              style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        // Stats row
        Row(children: [
          _statChip(Icons.place, '$placesCount ${placesCount == 1 ? 'place' : 'places'}'),
          const SizedBox(width: 12),
          _statChip(Icons.visibility, '$sightsCount ${sightsCount == 1 ? 'sight' : 'sights'}'),
        ]),
        // Next up
        if (nextUp != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.brandBlue.withValues(alpha: 0.1))),
            child: Row(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.brandBlue,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('NEXT UP',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5))),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(nextName,
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              if (nextTime.isNotEmpty)
                Text(nextTime,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _statChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  // ─── Add Activity Button ───
  Widget _addActivityButton() => GestureDetector(
        onTap: () {
          // TODO: open add place search dialog
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add activity coming soon')));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.brandBlue.withValues(alpha: 0.2),
                  style: BorderStyle.solid),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ]),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add,
                    color: AppColors.brandBlue, size: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text('Add Activity',
                        style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: AppColors.brandBlue,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('+ New',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
                  ]),
                  const SizedBox(height: 2),
                  const Text('Add a place to your itinerary',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ])),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ]),
        ),
      );

  // ─── Budget Tracker ───
  Widget _budgetTracker() {
    final spent = _trip?.budgetSpent ?? 0;
    final total = _trip?.budgetTotal ?? 0;
    final currency = _trip?.budgetCurrency ?? 'USD';
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 18, color: AppColors.brandBlue),
          const SizedBox(width: 8),
          Text('Budget',
              style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const Spacer(),
          if (total > 0)
            Text('$currency ${_fmt(spent.toInt())} / ${_fmt(total.toInt())}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 8),
        if (total > 0) ...[
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: AlwaysStoppedAnimation(
                      pct < 0.8 ? AppColors.brandBlue : AppColors.error),
                  minHeight: 6)),
          const SizedBox(height: 6),
        ],
        if (spent == 0)
          InkWell(
            onTap: () => context.push('/budget', extra: _trip),
            borderRadius: BorderRadius.circular(8),
            child: Text('Tap to add your first expense',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.brandBlue,
                    fontWeight: FontWeight.w600)),
          )
        else
          Text('Track spending by day and category',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.8))),
      ]),
    );
  }

  // ─── General Tips Section ───
  Widget _generalTipsSection() {
    final intel = _travelIntel!;
    final essentials = intel['essentials'] as List? ?? [];
    final countrySituation =
        (intel['countrySituation'] ?? '').toString();
    final allTips = <String>[
      if (countrySituation.isNotEmpty) countrySituation,
      ...essentials.map((e) => e.toString()),
    ];
    if (allTips.isEmpty) return const SizedBox.shrink();

    final showCount = _tipsExpanded ? allTips.length : 2.clamp(0, allTips.length);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_outline,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Text('General Tips',
              style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < showCount; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: const BoxDecoration(
                          color: AppColors.brandBlue,
                          shape: BoxShape.circle)),
                  Expanded(
                      child: Text(allTips[i],
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4))),
                ]),
          ),
        ],
        if (allTips.length > 2)
          GestureDetector(
            onTap: () => setState(() => _tipsExpanded = !_tipsExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  _tipsExpanded
                      ? 'Show less'
                      : 'Show more (+${allTips.length - 2})',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue)),
            ),
          ),
      ]),
    );
  }

  // ─── Reservations Preview ───
  Widget _reservationsPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reservations',
            style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final tab in [
              ('Flight', Icons.flight),
              ('Lodging', Icons.hotel),
              ('Tour', Icons.tour),
              ('Tickets', Icons.confirmation_num),
            ])
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(tab.$2, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(tab.$1,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(width: 4),
                  Text('(coming soon)',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  // ─── Day Header Card ───
  Widget _dayHeaderCard() {
    final day =
        _selectedDay < _days.length ? _days[_selectedDay] : <String, dynamic>{};
    final title = day['title'] ?? day['name'] ?? 'Day ${_selectedDay + 1}';
    final date = (day['date'] ?? '').toString();
    final activities = _currentActivities;
    final isCollapsed = _collapsedDays.contains(_selectedDay);

    // Sum costs for the day
    double dayCost = 0;
    for (final a in activities) {
      final c = a['cost'] ?? a['estimated_cost'];
      if (c is num) {
        dayCost += c.toDouble();
      } else if (c is Map) {
        final amount = c['amount'];
        if (amount is num) dayCost += amount.toDouble();
      } else if (c is String) {
        final parsed = double.tryParse(c.replaceAll(RegExp(r'[^\d.]'), ''));
        if (parsed != null) dayCost += parsed;
      }
    }

    return GestureDetector(
      onTap: () => setState(() {
        if (isCollapsed) {
          _collapsedDays.remove(_selectedDay);
        } else {
          _collapsedDays.add(_selectedDay);
        }
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(children: [
          // Day number badge (pink circle)
          Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Color(0xFFEC4899), shape: BoxShape.circle),
              child: Center(
                  child: Text('${_selectedDay + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(title.toString(),
                          style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  if (dayCost > 0)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('\$${dayCost.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success))),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  if (date.isNotEmpty)
                    Text(_friendlyDate(date),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  if (date.isNotEmpty) const SizedBox(width: 8),
                  Text('${activities.length} ${activities.length == 1 ? 'place' : 'places'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ])),
          Icon(isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: AppColors.textSecondary, size: 20),
        ]),
      ),
    );
  }

  // ─── AI Tools Row ───
  Widget _aiToolsRow() => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _aiActionChip(
                'Regenerate', Icons.refresh, _regenerating, _handleRegenerate),
            const SizedBox(width: 10),
            _aiActionChip('Optimize', Icons.auto_awesome, false, () {}),
            const SizedBox(width: 10),
            _aiActionChip(
                _replanning ? 'Replanning...' : 'Smart Replan',
                Icons.auto_fix_high,
                _replanning,
                _handleSmartReplan),
          ]),
        ),
      );

  Widget _aiActionChip(
          String label, IconData icon, bool loading, VoidCallback onTap) =>
      GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, size: 14, color: AppColors.brandBlue),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandBlue)),
          ]),
        ),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(Icons.explore_outlined,
              size: 48, color: AppColors.brandBlue.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('No activities yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Tap + to add your first activity',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );

  // ─── ACTIVITY CARDS (MAJOR UPGRADE) ───

  List<Widget> _buildReorderableActivities(List<Map<String, dynamic>> activities) {
    if (_collapsedDays.contains(_selectedDay)) return [];

    return [
      SizedBox(
        height: activities.length * 160.0, // approximate height per card
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
                child: child,
              ),
            );
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final day = _days[_selectedDay];
              final acts = List<Map<String, dynamic>>.from(
                  day['activities'] ?? day['places'] ?? []);
              final item = acts.removeAt(oldIndex);
              acts.insert(newIndex, item);
              if (day.containsKey('activities')) {
                day['activities'] = acts;
              } else {
                day['places'] = acts;
              }
            });
          },
          itemBuilder: (context, i) {
            final a = activities[i];
            return KeyedSubtree(
              key: ValueKey('act_${_selectedDay}_$i'),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => showActivityDetailSheet(context,
                        activity: a, tripId: _trip?.id ?? ''),
                    child: _activityCard(a, i, canEdit: true),
                  ),
                  if (i < activities.length - 1) _connector(),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildActivityCards(List<Map<String, dynamic>> activities,
      {required bool canEdit}) {
    if (_collapsedDays.contains(_selectedDay)) return [];

    final widgets = <Widget>[];
    for (var i = 0; i < activities.length; i++) {
      final a = activities[i];
      final delay = (i * 0.12).clamp(0.0, 0.8);
      final anim = CurvedAnimation(
          parent: _staggerController,
          curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
              curve: Curves.easeOut));

      widgets.add(FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(anim),
            child: GestureDetector(
              onTap: () => showActivityDetailSheet(context,
                  activity: a, tripId: _trip?.id ?? ''),
              child: _activityCard(a, i, canEdit: canEdit),
            ),
          )));

      if (i < activities.length - 1) widgets.add(_connector());
    }
    return widgets;
  }

  Widget _activityCard(Map<String, dynamic> a, int index,
      {required bool canEdit}) {
    final name = (a['name'] ?? a['title'] ?? 'Activity').toString();
    final startTime = (a['startTime'] ?? a['start_time'] ?? a['time'] ?? '').toString();
    final desc = (a['description'] ?? a['subtitle'] ?? '').toString();
    final duration = (a['duration'] ?? a['estimated_duration'] ?? '').toString();
    final address = (a['address'] ?? '').toString();
    final rating = (a['rating'] as num?)?.toDouble();
    final priceLevel = (a['priceLevel'] ?? a['price_level'] ?? '').toString();
    final cost = a['cost'] ?? a['estimated_cost'];
    final cat = _inferCat(a);
    final catLabel =
        (a['category'] ?? a['type'] ?? cat).toString();
    final catColor =
        _catBadgeColors[cat] ?? AppColors.brandBlue;
    final imageUrl = (a['image'] ?? a['photo'] ?? '').toString();
    final tips = a['tips'];
    final tipText = tips is List && tips.isNotEmpty
        ? tips.first.toString()
        : (tips is String && tips.isNotEmpty ? tips : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Photo section
        if (imageUrl.isNotEmpty)
          Stack(children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                    height: 160,
                    color: catColor.withValues(alpha: 0.1),
                    child: Icon(_icons[cat] ?? Icons.place,
                        size: 40, color: catColor.withValues(alpha: 0.4))),
              ),
            ),
            // Number badge top-left
            Positioned(
                top: 10,
                left: 10,
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: AppColors.brandBlue,
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700))))),
            // Bookmark + delete top-right
            Positioned(
                top: 10,
                right: 10,
                child: Row(children: [
                  _photoOverlayBtn(Icons.bookmark_border, () {}),
                  if (canEdit) ...[
                    const SizedBox(width: 6),
                    _photoOverlayBtn(Icons.delete_outline, () {}),
                  ],
                ])),
          ])
        else
          // No image — just show number badge inline
          const SizedBox.shrink(),

        // Content section
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Time range
            if (startTime.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(startTime,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue)),
              ),

            // Place name (no image case: show number)
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isEmpty)
                    Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            color: AppColors.brandBlue,
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                            child: Text('${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)))),
                  Expanded(
                      child: Text(name,
                          style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandBlue),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)),
                ]),

            // Address
            if (address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(address,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ]),
            ],

            // Category badge
            if (catLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      catLabel[0].toUpperCase() + catLabel.substring(1),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: catColor))),
            ],

            // Description
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],

            // Stats row: rating, duration, cost, price level
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 6, children: [
              if (rating != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              if (duration.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(duration,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              if (cost != null && _formatCost(cost).isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.payments,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(_formatCost(cost),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              if (priceLevel.isNotEmpty)
                Text(priceLevel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success)),
            ]),

            // AI Tip
            if (tipText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.success.withValues(alpha: 0.2))),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(tipText,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success.withValues(alpha: 0.9),
                                    height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)),
                      ])),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _photoOverlayBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white, size: 16)),
      );

  Widget _connector() => Padding(
        padding: const EdgeInsets.only(left: 24),
        child: SizedBox(
            height: 24,
            child: Column(children: [
              const SizedBox(height: 2),
              Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: 0.25),
                      shape: BoxShape.circle)),
              Expanded(
                  child: Container(
                      width: 1.5,
                      color: AppColors.brandBlue.withValues(alpha: 0.12))),
              Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: 0.25),
                      shape: BoxShape.circle)),
              const SizedBox(height: 2),
            ])),
      );

  Widget _buildMapBar(String role, List<Map<String, dynamic>> days) =>
      Container(
        color: AppColors.brandBlue,
        child: SafeArea(
            bottom: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_tripTitle,
                            style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ])),
              SizedBox(
                  height: 36,
                  child: Row(children: [
                    Expanded(
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 16),
                            itemCount: days.length,
                            itemBuilder: (_, i) => GestureDetector(
                                onTap: () => _onDaySelected(i),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: _selectedDay == i
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Text('Day ${i + 1}',
                                      style: TextStyle(
                                          color: _selectedDay == i
                                              ? AppColors.brandBlue
                                              : Colors.white
                                                  .withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                )))),
                    Container(
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _toggleBtn(Icons.view_list, !_showMap,
                                  () => setState(() => _showMap = false)),
                              _toggleBtn(Icons.map_outlined, _showMap,
                                  () => setState(() => _showMap = true)),
                            ])),
                  ])),
              const SizedBox(height: 12),
            ])),
      );

  void _showShareSheet() {
    if (_trip == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShareTripWidget(tripId: _trip!.id),
            const SizedBox(height: 16),
            TripMembersWidget(tripId: _trip!.id),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDestinationSegmentHeader() {
    final segments = _destinationSegments;
    final dayNum = _selectedDay + 1;
    final currentSeg = segments.cast<Map<String, dynamic>?>().firstWhere(
      (s) => dayNum >= (s!['startDay'] as int) && dayNum <= (s['endDay'] as int),
      orElse: () => null,
    );
    if (currentSeg == null) return [];
    final name = currentSeg['name'] ?? '';
    final startDay = currentSeg['startDay'] ?? 1;
    final endDay = currentSeg['endDay'] ?? 1;
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.brandBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          const Icon(Icons.location_on, size: 18, color: AppColors.brandBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.brandBlue))),
          Text('Days $startDay-$endDay', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
      ),
    ];
  }

  // ─── Multi-Destination Support ───
  List<Map<String, dynamic>> get _destinationSegments {
    final data = _trip?.itineraryData;
    final segments = data?['destinationSegments'] as List?;
    if (segments != null && segments.isNotEmpty) {
      return segments.map((s) => s is Map<String, dynamic> ? s : <String, dynamic>{}).toList();
    }
    return [];
  }

  void _showAddDestinationDialog() {
    final nameCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '2');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Destination', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(hintText: 'Destination name', prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: daysCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Number of days', prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final dayCount = int.tryParse(daysCtrl.text) ?? 2;
              final currentDays = _days.length;
              setState(() {
                final data = _trip?.itineraryData ?? {};
                final segments = List<Map<String, dynamic>>.from(data['destinationSegments'] ?? []);
                if (segments.isEmpty) {
                  segments.add({
                    'name': _tripDestination,
                    'startDay': 1,
                    'endDay': currentDays,
                  });
                }
                segments.add({
                  'name': nameCtrl.text.trim(),
                  'startDay': currentDays + 1,
                  'endDay': currentDays + dayCount,
                });
                data['destinationSegments'] = segments;
                final daysList = List<Map<String, dynamic>>.from(data['days'] ?? data['itinerary']?['days'] ?? []);
                for (var i = 0; i < dayCount; i++) {
                  daysList.add({
                    'title': '${nameCtrl.text.trim()} - Day ${i + 1}',
                    'date': '',
                    'activities': [],
                  });
                }
                if (data.containsKey('days')) {
                  data['days'] = daysList;
                } else if (data['itinerary'] != null) {
                  (data['itinerary'] as Map<String, dynamic>)['days'] = daysList;
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${nameCtrl.text.trim()} added with $dayCount days')));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_fabExpanded) ...[
              for (final item in [
                ('Edit', Icons.edit),
                ('Map', Icons.map_outlined),
                ('AI Chat', Icons.chat_bubble_outline),
                ('Regenerate', Icons.refresh),
                ('Optimize', Icons.auto_awesome),
                ('Smart Replan', Icons.route),
                ('Add Destination', Icons.add_location_alt),
                ('Travel Tips', Icons.lightbulb_outline),
                ('Summary', Icons.summarize_outlined),
                ('Share', Icons.share),
                ('Budget', Icons.account_balance_wallet_outlined),
                ('Packing List', Icons.backpack_outlined),
              ].reversed)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 8)
                                  ]),
                              child: Text(item.$1,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 44,
                              height: 44,
                              child: FloatingActionButton(
                                  heroTag: item.$1,
                                  backgroundColor: AppColors.brandBlue,
                                  elevation: 3,
                                  onPressed: () {
                                    setState(() => _fabExpanded = false);
                                    if (item.$1 == 'AI Chat')
                                      context.push('/ai-chat');
                                    if (item.$1 == 'Map')
                                      setState(() => _showMap = true);
                                    if (item.$1 == 'Regenerate')
                                      _handleRegenerate();
                                    if (item.$1 == 'Optimize')
                                      _handleRegenerate();
                                    if (item.$1 == 'Smart Replan')
                                      _handleSmartReplan();
                                    if (item.$1 == 'Travel Tips')
                                      context.push('/travel-tips',
                                          extra: _tripDestination);
                                    if (item.$1 == 'Summary')
                                      context.push('/trip-summary',
                                          extra: _trip);
                                    if (item.$1 == 'Packing List')
                                      context.push('/packing-list',
                                          extra: _trip);
                                    if (item.$1 == 'Budget')
                                      context.push('/budget', extra: _trip);
                                    if (item.$1 == 'Add Destination')
                                      _showAddDestinationDialog();
                                    if (item.$1 == 'Share')
                                      _showShareSheet();
                                  },
                                  child: Icon(item.$2,
                                      color: Colors.white, size: 20))),
                        ])),
            ],
            FloatingActionButton(
                heroTag: 'main',
                backgroundColor: AppColors.brandBlue,
                onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
                child: AnimatedRotation(
                    turns: _fabExpanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child:
                        const Icon(Icons.add, color: Colors.white, size: 28))),
          ]);
}
