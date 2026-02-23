import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../widgets/review_summary.dart';
import '../widgets/review_list.dart';
import '../widgets/activity_detail_sheet.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  final Trip? trip;
  const ItineraryScreen({super.key, this.trip});
  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen>
    with TickerProviderStateMixin {
  int _selectedDay = -1;
  bool _fabExpanded = false;
  bool _isBookmarked = false;
  bool _showMap = false;
  bool _regenerating = false;
  bool _replanning = false;
  String _activeSection = 'itinerary';
  bool _tipsExpanded = false;
  final Map<String, String> _placePhotos = {};
  static const _googleMapsKey = 'AIzaSyDvA2wmeqKw93M4v8b2Xm1uFWtIcCs46l0';
  final Set<int> _collapsedDays = {};
  final ScrollController _scrollController = ScrollController();
  late AnimationController _staggerController;
  int _heroDotIndex = 0;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _staggerController.forward();
    // Fetch place photos after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchPlacePhotos());
  }

  /// Fetch Google Places photos for activities missing images
  Future<void> _fetchPlacePhotos() async {
    for (final a in _allActivities) {
      final name = (a['name'] ?? a['title'] ?? '').toString();
      if (name.isEmpty) continue;
      final existingImg =
          (a['image'] ?? a['photo'] ?? a['image_url'] ?? a['imageUrl'] ?? '')
              .toString();
      if (existingImg.isNotEmpty || _placePhotos.containsKey(name)) continue;

      try {
        final q = Uri.encodeComponent('$name ${_tripDestination}');
        final searchUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$q&inputtype=textquery&fields=photos&key=$_googleMapsKey');
        final resp = await http.get(searchUrl);
        final data = jsonDecode(resp.body);
        final candidates = data['candidates'] as List? ?? [];
        if (candidates.isNotEmpty) {
          final photos = candidates[0]['photos'] as List? ?? [];
          if (photos.isNotEmpty) {
            final ref = photos[0]['photo_reference'];
            final photoUrl =
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$ref&key=$_googleMapsKey';
            _placePhotos[name] = photoUrl;
          }
        }
      } catch (_) {}
    }
    if (mounted && _placePhotos.isNotEmpty) setState(() {});
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
          .map((d) => d is Map<String, dynamic> ? d : <String, dynamic>{})
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
          .map((a) => a is Map<String, dynamic> ? a : <String, dynamic>{})
          .toList();
    return [];
  }

  List<Map<String, dynamic>> get _currentActivities =>
      _selectedDay < 0 ? _allActivities : _activitiesForDay(_selectedDay);

  List<Map<String, dynamic>> get _allActivities {
    final all = <Map<String, dynamic>>[];
    for (final day in _days) {
      final acts = day['activities'] ?? day['places'] ?? [];
      if (acts is List) {
        all.addAll(
            acts.map((a) => a is Map<String, dynamic> ? a : <String, dynamic>{}));
      }
    }
    return all;
  }

  int get _totalPlaces => _allActivities.length;

  List<MapActivity> get _mapActivities {
    final result = <MapActivity>[];
    for (var dayIdx = 0; dayIdx < _days.length; dayIdx++) {
      final day = _days[dayIdx];
      final acts = day['activities'] ?? day['places'] ?? [];
      if (acts is! List) continue;
      var numInDay = 0;
      for (final a in acts) {
        if (a is! Map<String, dynamic>) continue;
        final coords = a['coordinates'] as Map<String, dynamic>?;
        final lat = (a['lat'] as num?)?.toDouble() ??
            (coords?['lat'] as num?)?.toDouble();
        final lng = (a['lng'] as num?)?.toDouble() ??
            (coords?['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        numInDay++;
        result.add(MapActivity(
          name: a['name'] ?? a['title'] ?? '',
          time: a['time'] ?? '',
          lat: lat,
          lng: lng,
          dayIndex: dayIdx,
          numberInDay: numInDay,
        ));
      }
    }
    return result;
  }

  String get _tripTitle => _trip?.title ?? 'Trip Itinerary';
  String get _tripDestination => _trip?.destination ?? '';
  String get _tripDateRange {
    if (_trip?.startDate == null) return '';
    final start = DateTime.tryParse(_trip!.startDate!);
    final end =
        _trip!.endDate != null ? DateTime.tryParse(_trip!.endDate!) : null;
    if (start == null) return '';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final s = '${start.day} ${m[start.month - 1]}';
    if (end != null)
      return '$s - ${end.day} ${m[end.month - 1]} ${end.year}';
    return '$s, ${start.year}';
  }

  String get _tripDateRangeShort {
    if (_trip?.startDate == null) return '';
    final start = DateTime.tryParse(_trip!.startDate!);
    final end =
        _trip!.endDate != null ? DateTime.tryParse(_trip!.endDate!) : null;
    if (start == null) return '';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final s = '${start.day} ${m[start.month - 1]}';
    if (end != null) return '$s - ${end.day} ${m[end.month - 1]} ${end.year}';
    return '$s, ${start.year}';
  }

  int get _dayCount {
    if (_trip?.startDate == null || _trip?.endDate == null) return _days.length;
    final start = DateTime.tryParse(_trip!.startDate!);
    final end = DateTime.tryParse(_trip!.endDate!);
    if (start == null || end == null) return _days.length;
    return end.difference(start).inDays + 1;
  }

  int get _daysUntilTrip {
    if (_trip?.startDate == null) return -1;
    final start = DateTime.tryParse(_trip!.startDate!);
    if (start == null) return -1;
    final now = DateTime.now();
    final startDate = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    return startDate.difference(today).inDays;
  }

  bool get _isTripOngoing {
    if (_trip?.startDate == null || _trip?.endDate == null) return false;
    final start = DateTime.tryParse(_trip!.startDate!);
    final end = DateTime.tryParse(_trip!.endDate!);
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(DateTime(start.year, start.month, start.day)) &&
        !today.isAfter(DateTime(end.year, end.month, end.day));
  }

  int get _currentDayOfTrip {
    if (_trip?.startDate == null) return 0;
    final start = DateTime.tryParse(_trip!.startDate!);
    if (start == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
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

  List<String> get _heroImages {
    final images = <String>[];
    if (_trip?.coverImage != null && _trip!.coverImage!.isNotEmpty) {
      images.add(_trip!.coverImage!);
    }
    // Add first few activity images
    for (final a in _allActivities.take(4)) {
      final img = (a['image'] ?? a['photo'] ?? a['image_url'] ?? a['imageUrl'] ?? '').toString();
      if (img.isNotEmpty && !images.contains(img)) images.add(img);
    }
    if (images.isEmpty) images.add(_fallbackCoverImage);
    return images;
  }

  String get _fallbackCoverImage {
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
    'museum': ['museum', 'gallery', 'art', 'exhibition', 'uffizi', 'palazzo'],
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
    'attraction': Color(0xFF2563EB),
  };
  static const _numberColors = <Color>[
    Color(0xFF2563EB),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Color(0xFF6366F1),
  ];

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
        placeName: (activity['name'] ?? activity['title'] ?? '').toString(),
        category: (activity['category'] ?? activity['type'] ?? '').toString(),
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
    const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${wd[d.weekday - 1]} ${d.day} ${m[d.month - 1]}';
  }

  static String _friendlyDateShort(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[d.weekday - 1]}, ${m[d.month - 1]} ${d.day}';
  }

  String _formatCost(dynamic cost) {
    if (cost == null) return '';
    if (cost is Map) {
      final amount = cost['amount'];
      final currency = cost['currency'] ?? 'THB';
      if (amount == null || amount == 0) return 'Free';
      final symbol = currency == 'THB'
          ? '\u0E3F'
          : currency == 'EUR'
              ? '\u20AC'
              : currency == 'USD'
                  ? '\$'
                  : '$currency ';
      return '$symbol${amount is num ? amount.toStringAsFixed(0) : amount}';
    }
    if (cost is num) {
      if (cost == 0) return 'Free';
      return '\u0E3F${cost.toStringAsFixed(0)}';
    }
    final s = cost.toString().toLowerCase();
    if (s == 'free' || s == '0') return 'Free';
    return cost.toString();
  }

  // ─── Multi-destination ───
  List<Map<String, dynamic>> get _destinationSegments {
    final data = _trip?.itineraryData;
    final segments = data?['destinationSegments'] as List?;
    if (segments != null && segments.isNotEmpty) {
      return segments
          .map((s) => s is Map<String, dynamic> ? s : <String, dynamic>{})
          .toList();
    }
    return [];
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
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

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: null,
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
                                name: '', time: '', lat: 35.6762, lng: 139.6503)
                          ]))
          ])
        else
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── 1. HERO COVER PHOTO ──
              _buildHeroAppBar(perm, role),

              // ── CONTENT (no section tabs) ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (role == 'viewer') _viewerBanner(),

                    ..._buildItineraryContent(canEdit),

                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),

        // FAB backdrop
        if (_fabExpanded)
          GestureDetector(
            onTap: () => setState(() => _fabExpanded = false),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        // FAB speed dial
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: _buildFab(canEdit),
          ),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // ITINERARY CONTENT (top to bottom)
  // ═══════════════════════════════════════════
  List<Widget> _buildItineraryContent(bool canEdit) {
    return [
      // 2. Trip Info Pills
      _tripInfoPills(),
      const SizedBox(height: 16),

      // 3. Countdown Card
      _countdownCard(),
      const SizedBox(height: 12),

      // 4. Add Activity Card
      if (canEdit) _addActivityCard(),
      if (canEdit) const SizedBox(height: 12),

      // 5. Progress Card
      _progressCard(),
      const SizedBox(height: 12),

      // 6. Budget Tracker Card
      _budgetCard(),
      const SizedBox(height: 16),

      // 6.5 Checklist (inline, wrapped in card)
      if (_trip != null) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.checklist, size: 22, color: AppColors.brandBlue),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text('Checklist', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              ]),
              const SizedBox(height: 12),
              TripChecklistWidget(tripId: _trip!.id),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],

      // 7. Reservations Section
      _reservationsHeader(),
      const SizedBox(height: 16),

      // Multi-dest segment header
      if (_destinationSegments.isNotEmpty) ..._buildDestinationSegmentHeader(),

      // 8+9. Day groups with activities + travel connectors
      ..._buildDayGroupedActivities(canEdit),

      // 10. Action Chips
      const SizedBox(height: 16),
      _buildInlineActions(canEdit),
    ];
  }

  // ═══════════════════════════════════════════
  // 1. HERO COVER PHOTO
  // ═══════════════════════════════════════════
  SliverAppBar _buildHeroAppBar(PermissionService perm, String role) {
    final images = _heroImages;
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(children: [
          // Photo carousel — full height, card overlaps bottom
          SizedBox(
            height: 280,
            width: double.infinity,
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _heroDotIndex = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 280,
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.brandBlue),
              ),
            ),
          ),
          // Dot indicators on photo
          if (images.length > 1)
            Positioned(
              bottom: 65,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => Container(
                    width: i == _heroDotIndex ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i == _heroDotIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          // Top bar: back + follow/share
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(children: [
              _circleBtn(Icons.arrow_back_ios_new,
                  () => Navigator.maybePop(context)),
              const Spacer(),
              if (_trip != null) TripMemberAvatars(tripId: _trip!.id),
              const SizedBox(width: 8),
              _circleBtn(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                () => setState(() => _isBookmarked = !_isBookmarked),
              ),
              if (perm.canShareTrip(role)) ...[
                const SizedBox(width: 8),
                _circleBtn(Icons.ios_share, _showShareSheet),
              ],
            ]),
          ),
          // White content card overlapping photo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _tripTitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.person_add_alt, size: 14),
                    label: Text('Follow', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showShareSheet,
                    child: const Icon(Icons.share, size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 2. TRIP INFO PILLS
  // ═══════════════════════════════════════════
  Widget _tripInfoPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        // Location
        if (_tripDestination.isNotEmpty)
          _infoPill(
            icon: Icons.location_on,
            label: _tripDestination,
            textColor: AppColors.brandBlue,
            bgColor: const Color(0xFFEFF6FF),
            iconColor: AppColors.brandBlue,
          ),
        if (_tripDestination.isNotEmpty) const SizedBox(width: 8),
        // Date range
        if (_tripDateRangeShort.isNotEmpty)
          _infoPill(
            icon: Icons.calendar_today,
            label: _tripDateRangeShort,
            textColor: AppColors.textPrimary,
            bgColor: const Color(0xFFF3F4F6),
            iconColor: AppColors.textSecondary,
          ),
        const SizedBox(width: 8),
        // Days badge (outline style)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.brandBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.3)),
          ),
          child: Text(
            '$_dayCount ${_dayCount == 1 ? 'day' : 'days'}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Currency converter placeholder
        _infoPill(
          icon: Icons.swap_horiz,
          label: '\$1,000 = \u20AC849',
          textColor: AppColors.textSecondary,
          bgColor: const Color(0xFFF3F4F6),
          iconColor: AppColors.textSecondary,
        ),
      ]),
    );
  }

  Widget _infoPill({
    required IconData icon,
    required String label,
    required Color textColor,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // 3. COUNTDOWN CARD
  // ═══════════════════════════════════════════
  Widget _countdownCard() {
    final daysLeft = _daysUntilTrip;
    final ongoing = _isTripOngoing;
    final past = daysLeft < 0 && !ongoing;

    String title;
    String subtitle;
    Color circleColor;
    IconData? completedIcon;

    if (past) {
      title = 'Trip Completed';
      subtitle = 'Hope you had a great time!';
      circleColor = AppColors.success;
      completedIcon = Icons.check;
    } else if (ongoing) {
      final dayOf = _currentDayOfTrip;
      title = 'Day $dayOf of $_dayCount';
      subtitle = 'Enjoy your trip!';
      circleColor = AppColors.brandBlue;
    } else {
      title = 'Ready to Start';
      final startStr = _trip?.startDate ?? '';
      final start = DateTime.tryParse(startStr);
      if (start != null) {
        const m = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        subtitle = 'Your trip begins ${m[start.month - 1]} ${start.day}';
      } else {
        subtitle = 'Your trip is coming up!';
      }
      circleColor = AppColors.brandBlue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        // Circle with number or icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: circleColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (completedIcon != null)
                Icon(completedIcon, color: circleColor, size: 28)
              else if (ongoing)
                Icon(Icons.flight_takeoff, color: circleColor, size: 28)
              else ...[
                Text(
                  '${daysLeft.clamp(0, 9999)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: circleColor,
                    height: 1,
                  ),
                ),
                Text(
                  'DAYS',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: circleColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // 4. ADD ACTIVITY CARD
  // ═══════════════════════════════════════════
  Widget _addActivityCard() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add activity coming soon')));
      },
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.brandBlue.withValues(alpha: 0.35),
          borderRadius: 16,
          dashWidth: 6,
          dashSpace: 4,
          strokeWidth: 1.5,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  size: 24, color: AppColors.brandBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Add Activity',
                        style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.brandBlue,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('New',
                          style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text('Add a place to your itinerary',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 22),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 5. PROGRESS CARD
  // ═══════════════════════════════════════════
  Widget _progressCard() {
    final total = _totalPlaces;
    const visited = 0;
    final pct = total > 0 ? visited / total : 0.0;

    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: pct,
                strokeWidth: 4,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.brandBlue),
              ),
              Text('${(pct * 100).toInt()}%',
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
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
                Text('$visited/$total places',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary, size: 22),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 6. BUDGET TRACKER CARD
  // ═══════════════════════════════════════════
  Widget _budgetCard() {
    final budget = _trip?.budgetTotal ?? 0;
    const spent = 0.0;
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final barColor = pct < 0.5
        ? AppColors.success
        : pct < 0.8
            ? AppColors.warning
            : AppColors.error;

    return GestureDetector(
      onTap: () => context.push('/budget', extra: _trip),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, size: 22, color: AppColors.warning),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Budget Tracker',
                        style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    if (budget > 0)
                      Text(
                        'USD ${spent.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)}',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    'Track spending by day and category, add expenses, and get alerts when you\'re over budget.',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ]),
          if (budget > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Set Budget',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 7. RESERVATIONS SECTION HEADER
  // ═══════════════════════════════════════════
  Widget _reservationsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Reservations',
              style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _activeSection = 'reservations'),
            child: Text('Tickets',
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandBlue)),
          ),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final tab in [
              ('Flight', Icons.flight, true),
              ('Lodging', Icons.hotel, true),
              ('Tour', Icons.tour, true),
              ('Tickets', Icons.confirmation_num, false),
            ])
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(tab.$2, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(tab.$1,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  if (tab.$3) ...[
                    const SizedBox(width: 4),
                    Text('Soon',
                        style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary.withValues(alpha: 0.6))),
                  ],
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('+2 more',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  // 8+9. DAY GROUPED ACTIVITIES
  // ═══════════════════════════════════════════
  List<Widget> _buildDayGroupedActivities(bool canEdit) {
    final widgets = <Widget>[];
    final days = _days;
    int globalIndex = 0;

    for (var dayIdx = 0; dayIdx < days.length; dayIdx++) {
      final day = days[dayIdx];
      final activities = _activitiesForDay(dayIdx);
      final isCollapsed = _collapsedDays.contains(dayIdx);
      final date = (day['date'] ?? '').toString();

      // Day header
      widgets.add(_dayHeader(dayIdx, date, activities.length, isCollapsed));
      widgets.add(const SizedBox(height: 4));

      // "Show only these on map" link
      if (!isCollapsed) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: GestureDetector(
            onTap: () {
              _onDaySelected(dayIdx);
              setState(() => _showMap = true);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.map_outlined,
                  size: 14, color: AppColors.brandBlue),
              const SizedBox(width: 4),
              Text('Show only these on map',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue)),
            ]),
          ),
        ));
      }

      // Activities for this day
      if (!isCollapsed) {
        for (var i = 0; i < activities.length; i++) {
          final a = activities[i];
          final actNum = globalIndex + 1;

          // Activity card
          widgets.add(GestureDetector(
            onTap: () => showActivityDetailSheet(context,
                activity: a, tripId: _trip?.id ?? ''),
            child: _activityCard(a, actNum, dayIdx: dayIdx, canEdit: canEdit),
          ));

          // Travel connector between activities
          if (i < activities.length - 1) {
            widgets.add(_travelConnector(a, activities[i + 1]));
          }

          globalIndex++;
        }

        if (activities.isEmpty) {
          widgets.add(_emptyDayState());
        }
      } else {
        globalIndex += activities.length;
      }

      widgets.add(const SizedBox(height: 20));
    }

    return widgets;
  }

  // ─── Day Header ───
  Widget _dayHeader(int dayIdx, String date, int placeCount, bool isCollapsed) {
    final dayNum = dayIdx + 1;
    final color = _numberColors[dayIdx % _numberColors.length];

    return GestureDetector(
      onTap: () => setState(() {
        if (isCollapsed) {
          _collapsedDays.remove(dayIdx);
        } else {
          _collapsedDays.add(dayIdx);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          // DAY circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('DAY',
                    style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5,
                        height: 1)),
                Text('$dayNum',
                    style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      date.isNotEmpty ? _friendlyDate(date) : 'Day $dayNum',
                      style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  '$placeCount ${placeCount == 1 ? 'place' : 'places'}',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            isCollapsed ? Icons.expand_more : Icons.expand_less,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ]),
      ),
    );
  }

  // ─── Activity Card (website-matching) ───
  Widget _activityCard(Map<String, dynamic> a, int number,
      {required bool canEdit, int dayIdx = 0}) {
    final name = (a['name'] ?? a['title'] ?? 'Activity').toString();
    final startTime =
        (a['startTime'] ?? a['start_time'] ?? a['time'] ?? '').toString();
    final desc = (a['description'] ?? a['subtitle'] ?? '').toString();
    final duration =
        (a['duration'] ?? a['estimated_duration'] ?? '').toString();
    final address = (a['address'] ?? '').toString();
    final rating = (a['rating'] as num?)?.toDouble();
    final reviewCount = (a['reviewCount'] ?? a['review_count'] ?? a['user_ratings_total']) as num?;
    final cost = a['cost'] ?? a['estimated_cost'];
    final cat = _inferCat(a);
    final catColor = _catBadgeColors[cat] ?? AppColors.brandBlue;
    final numColor = _numberColors[dayIdx % _numberColors.length];
    final imageUrl =
        (a['image'] ?? a['photo'] ?? a['image_url'] ?? a['imageUrl'] ?? '')
            .toString();
    final effectiveImage = imageUrl.isNotEmpty
        ? imageUrl
        : (_placePhotos[name] ?? _activityFallbackImage(name, cat));
    final photoCount = (a['photos'] as List?)?.length ?? (imageUrl.isNotEmpty ? 1 : 0);
    final costStr = _formatCost(cost);
    final isFree = costStr.toLowerCase() == 'free';

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Photo section (200px) ──
        Stack(children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: effectiveImage,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                height: 200,
                color: catColor.withValues(alpha: 0.08),
                child: Icon(_icons[cat] ?? Icons.place,
                    size: 48, color: catColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
          // Number badge (top-left)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: numColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('$number',
                    style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          // Bookmark + Delete (top-right)
          Positioned(
            top: 10,
            right: 10,
            child: Column(children: [
              if (canEdit) ...[
                _photoOverlayBtn(Icons.delete_outline, () {},
                    bgColor: AppColors.error.withValues(alpha: 0.7)),
                const SizedBox(height: 6),
              ],
              _photoOverlayBtn(Icons.bookmark_border, () {}),
            ]),
          ),
          // Time badge (bottom-left)
          if (startTime.isNotEmpty)
            Positioned(
              bottom: 10,
              left: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.schedule,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(startTime,
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
          // Photo count (bottom-right)
          if (photoCount > 0)
            Positioned(
              bottom: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.camera_alt,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('$photoCount',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),

        // ── Content below photo ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Place name (blue, like a link)
              Text(name,
                  style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),

              // Address
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(address,
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],

              // Description
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(desc,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],

              // Bottom stats row: star + clock + cost + comment
              const SizedBox(height: 10),
              Row(children: [
                // Rating
                if (rating != null) ...[
                  const Icon(Icons.star, size: 14, color: AppColors.ratingGold),
                  const SizedBox(width: 3),
                  Text(
                    '${rating.toStringAsFixed(1)}${reviewCount != null ? ' (${_fmt(reviewCount.toInt())})' : ''}',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                ],
                // Duration
                if (duration.isNotEmpty) ...[
                  const Icon(Icons.schedule,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(duration,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                ],
                // Cost
                if (costStr.isNotEmpty) ...[
                  Icon(Icons.payments_outlined,
                      size: 13,
                      color: isFree ? AppColors.success : AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isFree
                          ? AppColors.success.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(costStr,
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isFree
                                ? AppColors.success
                                : AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                ],
                // Comment icon
                const Icon(Icons.chat_bubble_outline,
                    size: 13, color: AppColors.textSecondary),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  // ─── Travel Connector ───
  Widget _travelConnector(
      Map<String, dynamic> from, Map<String, dynamic> to) {
    // Estimate travel time/mode from data or default
    final travelTime =
        (from['travelTime'] ?? from['travel_time'] ?? '10 min').toString();
    final travelMode =
        (from['travelMode'] ?? from['travel_mode'] ?? 'Walk').toString();
    final isWalk = travelMode.toLowerCase().contains('walk');
    final icon = isWalk ? Icons.directions_walk : Icons.directions_car;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 24),
          // Dotted line + icon
          Column(children: [
            _dottedLine(18),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppColors.success),
            ),
            _dottedLine(18),
          ]),
          const SizedBox(width: 10),
          // Text
          Text(travelTime,
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 6),
          Text(travelMode,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _dottedLine(double height) {
    return SizedBox(
      width: 2,
      height: height,
      child: CustomPaint(
        painter: _VerticalDottedLinePainter(color: AppColors.success.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _photoOverlayBtn(IconData icon, VoidCallback onTap,
      {Color? bgColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _emptyDayState() => Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: [
          Icon(Icons.explore_outlined,
              size: 36, color: AppColors.brandBlue.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('No activities yet',
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Tap + to add your first activity',
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.textSecondary)),
        ]),
      );

  // ─── Action Chips ───
  Widget _buildInlineActions(bool canEdit) {
    final actions = <(String, IconData, bool, VoidCallback)>[
      if (canEdit)
        ('Regenerate', Icons.refresh, _regenerating, _handleRegenerate),
      if (canEdit)
        ('Optimize', Icons.auto_awesome, false, _handleRegenerate),
      if (canEdit)
        ('Smart Replan', Icons.route, _replanning, _handleSmartReplan),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: a.$3 ? null : a.$4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppColors.brandBlue.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                a.$3
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.brandBlue))
                    : Icon(a.$2, size: 16, color: AppColors.brandBlue),
                const SizedBox(width: 6),
                Text(a.$1,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue)),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ─── Multi-dest segment header ───
  List<Widget> _buildDestinationSegmentHeader() {
    final segments = _destinationSegments;
    if (segments.isEmpty) return [];
    return [
      for (final seg in segments) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.brandBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.brandBlue.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            const Icon(Icons.location_on,
                size: 18, color: AppColors.brandBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(seg['name'] ?? '',
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue)),
            ),
            Text('Days ${seg['startDay']}-${seg['endDay']}',
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ]),
        ),
      ],
    ];
  }

  // ─── Shared widgets ───
  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      );

  Widget _viewerBanner() => Container(
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
          Text('Viewing as a viewer',
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: Colors.orange.shade800)),
        ]),
      );

  Widget _toggleBtn(IconData icon, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon,
              size: 16,
              color: active ? AppColors.brandBlue : Colors.white70),
        ),
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
                  onTap: () => setState(() => _showMap = false),
                  child: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_tripTitle,
                      style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
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
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text('Day ${i + 1}',
                            style: TextStyle(
                                color: _selectedDay == i
                                    ? AppColors.brandBlue
                                    : Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _toggleBtn(Icons.view_list, !_showMap,
                        () => setState(() => _showMap = false)),
                    _toggleBtn(Icons.map_outlined, _showMap,
                        () => setState(() => _showMap = true)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ]),
        ),
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

  Widget _buildFab(bool canEdit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          for (final item in [
            ('Map', Icons.map_outlined),
            ('AI Chat', Icons.chat_bubble_outline),
            ('Share', Icons.share),
          ].reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6),
                    ],
                  ),
                  child: Text(item.$1,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: FloatingActionButton(
                    heroTag: item.$1,
                    mini: true,
                    backgroundColor: AppColors.brandBlue,
                    elevation: 2,
                    onPressed: () {
                      setState(() => _fabExpanded = false);
                      if (item.$1 == 'AI Chat') context.push('/ai-chat');
                      if (item.$1 == 'Map') setState(() => _showMap = true);
                      if (item.$1 == 'Travel Tips')
                        context.push('/travel-tips', extra: _tripDestination);
                      if (item.$1 == 'Summary')
                        context.push('/trip-summary', extra: _trip);
                      if (item.$1 == 'Packing List')
                        context.push('/packing-list', extra: _trip);
                      if (item.$1 == 'Share') _showShareSheet();
                    },
                    child: Icon(item.$2, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
        ],
        FloatingActionButton(
          heroTag: 'main',
          backgroundColor: AppColors.brandBlue,
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  String _activityFallbackImage(String name, String category) {
    // Use loremflickr which still works (unsplash source is deprecated)
    final q = Uri.encodeComponent(name.split('(').first.trim());
    return 'https://loremflickr.com/800/400/$q';
  }
}

// ═══════════════════════════════════════════
// Section Tab Persistent Header Delegate
// ═══════════════════════════════════════════
class _SectionTabDelegate extends SliverPersistentHeaderDelegate {
  final String activeSection;
  final ValueChanged<String> onChanged;

  _SectionTabDelegate({required this.activeSection, required this.onChanged});

  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          for (final e in [
            ('itinerary', 'Itinerary'),
            ('checklist', 'Checklist'),
            ('reservations', 'Reservations'),
            ('alerts', 'Alerts'),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.$1),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeSection == e.$1
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: activeSection == e.$1
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4)
                          ]
                        : null,
                  ),
                  child: Text(e.$2,
                      style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: activeSection == e.$1
                              ? AppColors.brandBlue
                              : AppColors.textSecondary)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionTabDelegate oldDelegate) =>
      activeSection != oldDelegate.activeSection;
}

// ═══════════════════════════════════════════
// Trip Reviews Section
// ═══════════════════════════════════════════
class _TripReviewsSection extends StatefulWidget {
  final String tripId;
  const _TripReviewsSection({required this.tripId});

  @override
  State<_TripReviewsSection> createState() => _TripReviewsSectionState();
}

class _TripReviewsSectionState extends State<_TripReviewsSection> {
  List<Review> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reviews =
        await ReviewService.instance.getReviewsForTrip(widget.tripId);
    if (mounted)
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReviewSummary(reviews: _reviews),
        const SizedBox(height: 12),
        ReviewList(reviews: _reviews, loading: _loading),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/reviews', extra: {
              'tripId': widget.tripId,
              'title': 'Trip Reviews',
            }),
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('View All Reviews'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              side: const BorderSide(color: AppColors.brandBlue),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// Dashed Border Painter
// ═══════════════════════════════════════════
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    this.borderRadius = 16,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || borderRadius != oldDelegate.borderRadius;
}

// ═══════════════════════════════════════════
// Vertical Dotted Line Painter (travel connector)
// ═══════════════════════════════════════════
class _VerticalDottedLinePainter extends CustomPainter {
  final Color color;
  _VerticalDottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + 3).clamp(0, size.height)),
        paint,
      );
      y += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDottedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
