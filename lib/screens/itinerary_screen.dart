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
  final ScrollController _scrollController = ScrollController();
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
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

  List<Map<String, dynamic>> get _days {
    final data = _trip?.itineraryData;
    if (data == null) return [{'title': 'Day 1', 'date': '', 'activities': []}];
    final daysList = data['days'] ?? data['itinerary']?['days'];
    if (daysList is List && daysList.isNotEmpty) {
      return daysList.map((d) => d is Map<String, dynamic> ? d : <String, dynamic>{}).toList();
    }
    return [{'title': 'Day 1', 'date': '', 'activities': []}];
  }

  List<Map<String, dynamic>> get _currentActivities {
    if (_selectedDay >= _days.length) return [];
    final day = _days[_selectedDay];
    final acts = day['activities'] ?? day['places'] ?? [];
    if (acts is List) return acts.map((a) => a is Map<String, dynamic> ? a : <String, dynamic>{}).toList();
    return [];
  }

  List<MapActivity> get _mapActivities {
    return _currentActivities.where((a) => a['lat'] != null && a['lng'] != null).map((a) {
      return MapActivity(name: a['name'] ?? a['title'] ?? '', time: a['time'] ?? '',
          lat: (a['lat'] as num).toDouble(), lng: (a['lng'] as num).toDouble());
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
    if (end != null) return '$s – ${m[end.month - 1]} ${end.day}, ${end.year}';
    return '$s, ${start.year}';
  }

  String get _heroImageUrl {
    final dest = _tripDestination.toLowerCase();
    if (dest.contains('japan') || dest.contains('tokyo')) return 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&q=80';
    if (dest.contains('italy') || dest.contains('tuscan') || dest.contains('florence') || dest.contains('rome')) return 'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=800&q=80';
    if (dest.contains('thai') || dest.contains('bangkok')) return 'https://images.unsplash.com/photo-1563492065599-3520f775eeed?w=800&q=80';
    if (dest.contains('paris') || dest.contains('france')) return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&q=80';
    if (dest.contains('london') || dest.contains('uk')) return 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&q=80';
    if (dest.contains('bali') || dest.contains('indonesia')) return 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&q=80';
    if (dest.contains('korea') || dest.contains('seoul')) return 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=800&q=80';
    return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800&q=80';
  }

  // ─── Category inference ───
  static const _kw = <String, List<String>>{
    'restaurant': ['restaurant', 'food', 'eat', 'dining', 'cafe', 'coffee', 'lunch', 'dinner', 'breakfast', 'brunch', 'bistro', 'ramen', 'sushi', 'noodle', 'trattoria', 'osteria', 'pizz', 'gelat', 'wine', 'vinaio', 'sandwich'],
    'temple': ['temple', 'shrine', 'wat', 'pagoda', 'mosque', 'church', 'cathedral', 'duomo', 'basilica', 'chapel'],
    'museum': ['museum', 'gallery', 'art', 'exhibition', 'uffizi', 'palazzo'],
    'park': ['park', 'garden', 'nature', 'forest', 'hiking', 'trail', 'mountain', 'waterfall', 'lake', 'piazza'],
    'shopping': ['shopping', 'mall', 'market', 'bazaar', 'outlet', 'souvenir', 'shop', 'store', 'mercato'],
    'beach': ['beach', 'coast', 'island', 'snorkel', 'diving', 'surf', 'seaside', 'bay', 'thermal', 'bath', 'spa'],
    'hotel': ['hotel', 'resort', 'hostel', 'check-in', 'check-out', 'accommodation', 'stay', 'airbnb'],
    'transport': ['airport', 'station', 'transfer', 'taxi', 'train', 'bus', 'ferry', 'flight', 'drive', 'transport'],
  };
  static const _icons = <String, IconData>{
    'restaurant': Icons.restaurant, 'temple': Icons.temple_buddhist, 'museum': Icons.museum,
    'park': Icons.park, 'shopping': Icons.shopping_bag, 'beach': Icons.beach_access,
    'hotel': Icons.hotel, 'transport': Icons.directions_car,
  };
  static const _colors = <String, Color>{
    'restaurant': Color(0xFFF59E0B), 'temple': Color(0xFFEF4444), 'museum': Color(0xFF8B5CF6),
    'park': Color(0xFF10B981), 'shopping': Color(0xFFEC4899), 'beach': Color(0xFF06B6D4),
    'hotel': Color(0xFF6366F1), 'transport': Color(0xFF6B7280),
  };

  String _inferCat(Map<String, dynamic> a) {
    final explicit = (a['type'] ?? a['category'] ?? '').toString().toLowerCase();
    for (final c in _kw.keys) { if (explicit.contains(c)) return c; }
    final text = '${a['name'] ?? ''} ${a['title'] ?? ''} ${a['description'] ?? ''}'.toLowerCase();
    for (final e in _kw.entries) { for (final k in e.value) { if (text.contains(k)) return e.key; } }
    return 'default';
  }

  // ─── AI quota ───
  Future<bool> _checkAiQuota() async {
    final r = await quota.RateLimitService.instance.canUseAi();
    if (r['can_use'] != true && mounted) {
      showUpgradeDialog(context, ref, currentUsage: r['current_usage'] as int? ?? 0,
          monthlyLimit: r['monthly_limit'] as int? ?? 10, planName: 'Free');
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
        params: GenerateItineraryParams(destination: _trip!.destination, startDate: _trip!.startDate ?? '', endDate: _trip!.endDate ?? ''));
      await quota.RateLimitService.instance.incrementAiUsage();
      ref.invalidate(quota.aiQuotaProvider);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary regenerated!'))); ref.invalidate(tripProvider(_trip!.id)); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
    finally { if (mounted) setState(() => _regenerating = false); }
  }

  Future<void> _handleSmartReplan() async {
    if (_trip == null || _replanning) return;
    if (!await _checkAiQuota()) return;
    setState(() => _replanning = true);
    try {
      final result = await ReplanService.instance.replanDay(tripId: _trip!.id, tripData: _trip!.itineraryData ?? {}, dayIndex: _selectedDay);
      await quota.RateLimitService.instance.incrementAiUsage();
      ref.invalidate(quota.aiQuotaProvider);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.summary))); if (result.success) ref.invalidate(tripProvider(_trip!.id)); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Replan failed: $e'))); }
    finally { if (mounted) setState(() => _replanning = false); }
  }

  Future<void> _handleSwapPlace(Map<String, dynamic> activity) async {
    if (_trip == null) return;
    final alternatives = await ReplanService.instance.suggestAlternatives(
      placeId: activity['id']?.toString() ?? '', placeName: (activity['name'] ?? activity['title'] ?? '').toString(),
      category: (activity['category'] ?? activity['type'] ?? '').toString(), destination: _trip!.destination,
      lat: (activity['lat'] as num?)?.toDouble(), lng: (activity['lng'] as num?)?.toDouble());
    if (!mounted || alternatives.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No alternatives found'))); return; }
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Alternative Places', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...alternatives.take(5).map((alt) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: AppColors.brandBlue.withValues(alpha: 0.1), child: const Icon(Icons.place, color: AppColors.brandBlue, size: 20)),
          title: Text(alt.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(alt.category, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          trailing: alt.cost != null ? Text('${alt.currency ?? '\u0E3F'}${alt.cost!.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.brandBlue)) : null,
          onTap: () => Navigator.pop(ctx),
        )),
      ])));
  }

  void _onDaySelected(int i) {
    if (i == _selectedDay) return;
    setState(() => _selectedDay = i);
    _staggerController.reset();
    _staggerController.forward();
    if (_scrollController.hasClients) _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  static String _fmt(int n) { final s = n.toString(); final b = StringBuffer(); for (var i = 0; i < s.length; i++) { if (i > 0 && (s.length - i) % 3 == 0) b.write(','); b.write(s[i]); } return b.toString(); }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final days = _days;
    final activities = _currentActivities;
    final roleAsync = _trip != null ? ref.watch(tripRoleProvider(_trip!.id)) : const AsyncData<String>('owner');
    final role = roleAsync.value ?? 'viewer';
    final perm = PermissionService.instance;
    final canEdit = perm.canEditActivities(role);
    final isOwner = perm.canManageMembers(role);
    final coverImage = _trip?.coverImage ?? _heroImageUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: canEdit ? _buildFab() : null,
      body: Stack(children: [
        if (_showMap)
          Column(children: [_buildMapBar(role, days), Expanded(child: TripMapView(activities: _mapActivities.isNotEmpty ? _mapActivities : const [MapActivity(name: '', time: '', lat: 35.6762, lng: 139.6503)]))])
        else
          CustomScrollView(controller: _scrollController, slivers: [
              // ── HERO HEADER ──
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.brandBlue,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Stack(children: [
                    Positioned.fill(child: Image.network(coverImage, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.brandBlue))),
                    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.65)])))),
                    // Title + info over hero
                    Positioned(left: 20, right: 20, bottom: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_tripTitle, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5))),
                        if (_tripDateRange.isNotEmpty) ...[const SizedBox(width: 10), const Icon(Icons.calendar_today, color: Colors.white70, size: 12), const SizedBox(width: 4),
                          Flexible(child: Text(_tripDateRange, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis))],
                        if (_tripDestination.isNotEmpty) ...[const SizedBox(width: 10), const Icon(Icons.location_on, color: Colors.white70, size: 12), const SizedBox(width: 3),
                          Text(_tripDestination, style: const TextStyle(color: Colors.white70, fontSize: 12))],
                      ]),
                    ])),
                    // Top bar: back + bookmark + share
                    Positioned(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12, child: Row(children: [
                      _circleBtn(Icons.arrow_back_ios_new, () => Navigator.maybePop(context)),
                      const Spacer(),
                      if (_trip != null) TripMemberAvatars(tripId: _trip!.id),
                      const SizedBox(width: 8),
                      _circleBtn(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, () => setState(() => _isBookmarked = !_isBookmarked)),
                      if (perm.canShareTrip(role)) ...[const SizedBox(width: 8), _circleBtn(Icons.ios_share, () {})],
                    ])),
                  ]),
                ),
                // Pinned: Day tabs
                bottom: PreferredSize(preferredSize: const Size.fromHeight(48), child: Container(
                  color: AppColors.brandBlue,
                  child: SizedBox(height: 48, child: Row(children: [
                    Expanded(child: ListView.builder(
                      scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 16),
                      itemCount: days.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _onDaySelected(i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedDay == i ? Colors.white : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(24)),
                          child: Text('Day ${i + 1}', style: TextStyle(
                            color: _selectedDay == i ? AppColors.brandBlue : Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    )),
                    // List/Map toggle
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _toggleBtn(Icons.view_list, !_showMap, () => setState(() => _showMap = false)),
                        _toggleBtn(Icons.map_outlined, _showMap, () => setState(() => _showMap = true)),
                      ]),
                    ),
                  ])),
                )),
              ),

              // ── CONTENT ──
              SliverPadding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), sliver: SliverList(delegate: SliverChildListDelegate([
                // Viewer banner
                if (role == 'viewer') _viewerBanner(),

                // Section tabs (compact)
                _sectionTabs(),
                const SizedBox(height: 14),

                if (_activeSection == 'itinerary') ...[
                  // Day title + budget (compact)
                  _dayHeader(),
                  const SizedBox(height: 4),

                  // AI tools — collapsed into one row
                  if (canEdit) _aiToolsRow(),
                  if (canEdit) const SizedBox(height: 14),

                  // Activity timeline
                  if (activities.isEmpty)
                    _emptyState()
                  else
                    ..._buildTimeline(activities, canEdit: canEdit),
                ],
                if (_activeSection == 'checklist' && _trip != null) TripChecklistWidget(tripId: _trip!.id),
                if (_activeSection == 'reservations' && _trip != null) TripReservationsWidget(tripId: _trip!.id),
                if (_activeSection == 'alerts' && _trip != null) TripAlertsWidget(tripId: _trip!.id),

                if (_trip != null) ...[
                  const SizedBox(height: 24),
                  if (isOwner) ShareTripWidget(tripId: _trip!.id),
                  if (isOwner) const SizedBox(height: 16),
                  TripMembersWidget(tripId: _trip!.id),
                ],
              ]))),
            ]),
        // FAB backdrop overlay
        if (_fabExpanded) GestureDetector(
          onTap: () => setState(() => _fabExpanded = false),
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
      ]),
    );
  }

  // ─── WIDGETS ───

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );

  Widget _toggleBtn(IconData icon, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
      child: Icon(icon, size: 16, color: active ? AppColors.brandBlue : Colors.white70),
    ),
  );

  Widget _viewerBanner() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
    child: Row(children: [
      const Icon(Icons.visibility, size: 16, color: Colors.orange),
      const SizedBox(width: 8),
      Text('Viewing as a viewer', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.orange.shade800)),
    ]),
  );

  Widget _sectionTabs() => SizedBox(
    height: 36,
    child: ListView(scrollDirection: Axis.horizontal, children: [
      for (final e in [('itinerary', 'Itinerary', Icons.map_outlined), ('checklist', 'Checklist', Icons.checklist),
        ('reservations', 'Reservations', Icons.receipt_long), ('alerts', 'Alerts', Icons.notifications_outlined)])
        Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
          onTap: () => setState(() => _activeSection = e.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _activeSection == e.$1 ? AppColors.brandBlue : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _activeSection == e.$1 ? AppColors.brandBlue : const Color(0xFFE0E0E0))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(e.$3, size: 14, color: _activeSection == e.$1 ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(e.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _activeSection == e.$1 ? Colors.white : AppColors.textSecondary)),
            ]),
          ),
        )),
    ]),
  );

  Widget _dayHeader() {
    final day = _selectedDay < _days.length ? _days[_selectedDay] : <String, dynamic>{};
    final title = day['title'] ?? day['name'] ?? 'Day ${_selectedDay + 1}';
    final date = day['date'] ?? '';
    final spent = (_trip?.budgetSpent ?? 0) / (_days.length > 0 ? _days.length : 1);
    final total = (_trip?.budgetTotal ?? 0) / (_days.length > 0 ? _days.length : 1);
    final pct = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(12)),
            child: Text('Day ${_selectedDay + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          if (date.toString().isNotEmpty) Text(date.toString(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        Text(title.toString(), style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (total > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('\u0E3F${_fmt(spent.toInt())} / \u0E3F${_fmt(total.toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(width: 10),
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation(pct < 0.8 ? AppColors.brandBlue : AppColors.error), minHeight: 5))),
          ]),
        ],
      ]),
    );
  }

  /// AI tools in one compact row: Regenerate | Optimize | Smart Replan
  Widget _aiToolsRow() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(children: [
      _aiActionChip('Regenerate', Icons.refresh, _regenerating, _handleRegenerate),
      const SizedBox(width: 8),
      _aiActionChip('Optimize', Icons.auto_awesome, false, () {}),
      const SizedBox(width: 8),
      Expanded(child: _aiActionChip(_replanning ? 'Replanning...' : 'Replan', Icons.auto_fix_high, _replanning, _handleSmartReplan)),
    ]),
  );

  Widget _aiActionChip(String label, IconData icon, bool loading, VoidCallback onTap) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 14, color: AppColors.brandBlue),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
      ]),
    ),
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Icon(Icons.explore_outlined, size: 48, color: AppColors.brandBlue.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      const Text('No activities yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      const Text('Tap + to add your first activity', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    ]),
  );

  // ─── TIMELINE ───

  List<Widget> _buildTimeline(List<Map<String, dynamic>> activities, {required bool canEdit}) {
    final widgets = <Widget>[];
    for (var i = 0; i < activities.length; i++) {
      final a = activities[i];
      final cat = _inferCat(a);
      final delay = (i * 0.12).clamp(0.0, 0.8);
      final anim = CurvedAnimation(parent: _staggerController, curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut));

      widgets.add(FadeTransition(opacity: anim, child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
        child: _activityCard(a, cat, canEdit: canEdit, isFirst: i == 0),
      )));

      if (i < activities.length - 1) widgets.add(_connector());
    }
    return widgets;
  }

  Widget _activityCard(Map<String, dynamic> a, String cat, {required bool canEdit, bool isFirst = false}) {
    final name = (a['name'] ?? a['title'] ?? 'Activity').toString();
    final time = (a['time'] ?? a['start_time'] ?? '').toString();
    final desc = (a['description'] ?? a['subtitle'] ?? '').toString();
    final duration = (a['duration'] ?? a['estimated_duration'] ?? '').toString();
    final icon = _icons[cat] ?? Icons.place;
    final color = _colors[cat] ?? AppColors.brandBlue;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
      child: IntrinsicHeight(child: Row(children: [
        // Left color bar
        Container(width: 4, decoration: BoxDecoration(
          color: color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)))),
        // Content
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: time + duration + swap/drag
          Row(children: [
            if (time.isNotEmpty) ...[
              Icon(Icons.schedule, size: 13, color: color),
              const SizedBox(width: 4),
              Text(time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
            if (duration.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                child: Text(duration.startsWith('~') ? duration : '~$duration', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
            ],
            const Spacer(),
            if (canEdit && isFirst) GestureDetector(onTap: () => _handleSwapPlace(a),
              child: Icon(Icons.swap_horiz, size: 16, color: AppColors.textSecondary.withValues(alpha: 0.5))),
            if (canEdit) ...[const SizedBox(width: 4), const Icon(Icons.drag_indicator, size: 16, color: AppColors.textSecondary)],
          ]),
          const SizedBox(height: 6),
          // Name + category icon
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32, height: 32, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: color)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ])),
          ]),
          const SizedBox(height: 8),
          BookingChip(placeName: name),
        ]))),
      ])),
    );
  }

  Widget _connector() => Padding(
    padding: const EdgeInsets.only(left: 24),
    child: SizedBox(height: 24, child: Column(children: [
      const SizedBox(height: 2),
      Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.25), shape: BoxShape.circle)),
      Expanded(child: Container(width: 1.5, color: AppColors.brandBlue.withValues(alpha: 0.12))),
      Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.25), shape: BoxShape.circle)),
      const SizedBox(height: 2),
    ])),
  );

  Widget _buildMapBar(String role, List<Map<String, dynamic>> days) => Container(
    color: AppColors.brandBlue,
    child: SafeArea(bottom: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Row(children: [
        GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
        const SizedBox(width: 8),
        Expanded(child: Text(_tripTitle, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ])),
      SizedBox(height: 36, child: Row(children: [
        Expanded(child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 16), itemCount: days.length,
          itemBuilder: (_, i) => GestureDetector(onTap: () => _onDaySelected(i), child: Container(
            margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: _selectedDay == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(24)),
            child: Text('Day ${i + 1}', style: TextStyle(color: _selectedDay == i ? AppColors.brandBlue : Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600, fontSize: 14)),
          )))),
        Container(margin: const EdgeInsets.only(right: 16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _toggleBtn(Icons.view_list, !_showMap, () => setState(() => _showMap = false)),
            _toggleBtn(Icons.map_outlined, _showMap, () => setState(() => _showMap = true)),
          ])),
      ])),
      const SizedBox(height: 12),
    ])),
  );

  Widget _buildFab() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
    if (_fabExpanded) ...[
      for (final item in [
        ('Edit', Icons.edit, AppColors.brandBlue), ('Map', Icons.map, AppColors.success),
        ('AI Chat', Icons.chat_bubble_outline, AppColors.warning), ('Optimize', Icons.auto_awesome, AppColors.brandBlue),
      ].reversed) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)]),
          child: Text(item.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        SizedBox(width: 44, height: 44, child: FloatingActionButton(heroTag: item.$1, backgroundColor: item.$3, elevation: 3,
          onPressed: () { setState(() => _fabExpanded = false);
            if (item.$1 == 'AI Chat') context.push('/ai-chat');
            if (item.$1 == 'Map') setState(() => _showMap = true);
            if (item.$1 == 'Optimize') _handleRegenerate();
          }, child: Icon(item.$2, color: Colors.white, size: 20))),
      ])),
    ],
    FloatingActionButton(heroTag: 'main', backgroundColor: AppColors.brandBlue,
      onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
      child: AnimatedRotation(turns: _fabExpanded ? 0.125 : 0, duration: const Duration(milliseconds: 200),
        child: const Icon(Icons.add, color: Colors.white, size: 28))),
  ]);
}
