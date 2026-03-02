import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../services/place_service.dart';
import '../services/comment_service.dart';
import '../services/image_service.dart';

// ──────────────────────────────────────────────
// Activity Detail Bottom Sheet
// 4 tabs: About · Reviews · Gallery · Booking
// ──────────────────────────────────────────────

void showActivityDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> activity,
  required String tripId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ActivityDetailSheet(activity: activity, tripId: tripId),
  );
}

class ActivityDetailSheet extends StatefulWidget {
  final Map<String, dynamic> activity;
  final String tripId;

  const ActivityDetailSheet({
    super.key,
    required this.activity,
    required this.tripId,
  });

  @override
  State<ActivityDetailSheet> createState() => _ActivityDetailSheetState();
}

class _ActivityDetailSheetState extends State<ActivityDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Lazy-loaded data
  PlaceDetails? _placeDetails;
  bool _loadingDetails = false;
  List<PlaceComment>? _comments;
  bool _loadingComments = false;
  List<String>? _photos;
  bool _loadingPhotos = false;

  Map<String, dynamic> get _a => widget.activity;
  String get _name => (_a['name'] ?? _a['title'] ?? 'Activity').toString();
  String get _desc => (_a['description'] ?? _a['subtitle'] ?? '').toString();
  String get _category => (_a['type'] ?? _a['category'] ?? '').toString();
  String get _duration =>
      (_a['duration'] ?? _a['estimated_duration'] ?? '').toString();
  String get _address => (_a['address'] ?? '').toString();
  String get _cost =>
      (_a['cost'] ?? _a['estimated_cost'] ?? '').toString();
  String get _priceLevel =>
      (_a['priceLevel'] ?? _a['price_level'] ?? '').toString();
  double? get _rating => (_a['rating'] as num?)?.toDouble();
  double? get _lat {
    final coords = _a['coordinates'] as Map<String, dynamic>?;
    return (_a['lat'] as num?)?.toDouble() ??
        (coords?['lat'] as num?)?.toDouble();
  }

  double? get _lng {
    final coords = _a['coordinates'] as Map<String, dynamic>?;
    return (_a['lng'] as num?)?.toDouble() ??
        (coords?['lng'] as num?)?.toDouble();
  }

  List<String> get _tips {
    final t = _a['tips'] ?? _a['notes'];
    if (t is List) return t.map((e) => e.toString()).toList();
    if (t is String && t.isNotEmpty) return [t];
    return [];
  }

  String get _imageUrl => (_a['image'] ?? _a['photo'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPlaceDetails();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 1:
        if (_comments == null && !_loadingComments) _loadComments();
        if (_placeDetails == null && !_loadingDetails) _loadPlaceDetails();
        break;
      case 2:
        if (_photos == null && !_loadingPhotos) _loadPhotos();
        break;
    }
  }

  Future<void> _loadPlaceDetails() async {
    setState(() => _loadingDetails = true);
    try {
      final details = await PlaceService.instance.getPlaceDetails(
        _name.toLowerCase().trim(),
        _name,
        placeAddress: _address.isNotEmpty ? _address : null,
      );
      if (mounted) setState(() => _placeDetails = details);
    } catch (_) {}
    if (mounted) setState(() => _loadingDetails = false);
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await CommentService.instance
          .fetchComments(widget.tripId, _name.toLowerCase().trim());
      if (mounted) setState(() => _comments = comments);
    } catch (_) {}
    if (mounted) setState(() => _loadingComments = false);
  }

  Future<void> _loadPhotos() async {
    setState(() => _loadingPhotos = true);
    try {
      final photos = await ImageService.instance
          .getPlacePhotos(_name.toLowerCase().trim());
      if (mounted) setState(() => _photos = photos);
    } catch (_) {}
    if (mounted) setState(() => _loadingPhotos = false);
  }

  // ─── Category helpers ───
  static const _catColors = <String, Color>{
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

  Color get _catColor {
    final cat = _category.toLowerCase();
    for (final e in _catColors.entries) {
      if (cat.contains(e.key)) return e.value;
    }
    return AppColors.brandBlue;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Hero image
          if (_imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: _imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name,
                          style: GoogleFonts.dmSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (_category.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: _catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(
                              _category[0].toUpperCase() +
                                  _category.substring(1),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _catColor)),
                        ),
                      ],
                    ]),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Quick stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(children: [
              if (_rating != null) ...[
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 3),
                Text(_rating!.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (_placeDetails?.reviewCount != null) ...[
                  const SizedBox(width: 2),
                  Text('(${_placeDetails!.reviewCount})',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(width: 12),
              ],
              if (_duration.isNotEmpty) ...[
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.brandBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.schedule,
                          size: 12, color: AppColors.brandBlue),
                      const SizedBox(width: 4),
                      Text(_duration,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandBlue)),
                    ])),
                const SizedBox(width: 8),
              ],
              if (_cost.isNotEmpty)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.payments,
                          size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(_cost,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success)),
                    ])),
            ]),
          ),
          // Tab bar
          Container(
            color: isDark ? AppColors.backgroundDark : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.brandBlue,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.brandBlue,
              indicatorWeight: 2.5,
              labelStyle:
                  GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13),
              tabs: const [
                Tab(text: 'About'),
                Tab(text: 'Reviews'),
                Tab(text: 'Gallery'),
                Tab(text: 'Booking'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(scrollController),
                _buildReviewsTab(scrollController),
                _buildGalleryTab(scrollController),
                _buildBookingTab(scrollController),
              ],
            ),
          ),
        ]),
      );
      },
    );
  }

  // ════════════════════════════════════════════
  // ABOUT TAB
  // ════════════════════════════════════════════
  Widget _buildAboutTab(ScrollController sc) {
    final details = _placeDetails;
    return ListView(
      controller: sc,
      padding: const EdgeInsets.all(20),
      children: [
        // Description
        if (_desc.isNotEmpty)
          _card([
            Text(_desc,
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5)),
          ]),

        // Why you should go (tips)
        if (_tips.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16,
                        color: AppColors.success.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Text('Why you should go',
                        style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                  ]),
                  const SizedBox(height: 8),
                  for (final tip in _tips) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 5,
                                height: 5,
                                margin:
                                    const EdgeInsets.only(top: 6, right: 8),
                                decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle)),
                            Expanded(
                                child: Text(tip,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.success
                                            .withValues(alpha: 0.9),
                                        height: 1.4))),
                          ]),
                    ),
                  ],
                ]),
          ),

        // Details section
        _card([
          _sectionTitle('Details'),
          const SizedBox(height: 8),
          // Address
          if (_address.isNotEmpty) _detailRow(Icons.location_on, _address),
          // Opening hours with "Open now" badge
          if (details?.openingHours != null &&
              details!.openingHours!.weekdayText.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            if (details.openingHours!.isOpen == true)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Open now',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success))),
                          ]),
                          for (final h in details.openingHours!.weekdayText)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(h,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ),
                        ])),
                  ]),
            ),
          ],
          // Phone
          if (details?.phone != null) _detailRow(Icons.phone, details!.phone!),
          // Website
          if (details?.website != null)
            GestureDetector(
              onTap: () => _launchUrl(details!.website!),
              child: _detailRow(Icons.language, details!.website!,
                  isLink: true),
            ),
          // Price level
          if (_priceLevel.isNotEmpty)
            _detailRow(Icons.payments, 'Price: $_priceLevel'),
        ]),

        // Rating summary
        if (_rating != null || details?.rating != null)
          _card([
            Row(children: [
              Text(
                  (_rating ?? details?.rating ?? 0).toStringAsFixed(1),
                  style: GoogleFonts.dmSans(
                      fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                i <
                                        (_rating ?? details?.rating ?? 0)
                                            .round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16))),
                    if (details?.reviewCount != null)
                      Text('${details!.reviewCount} reviews',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ]),
            ]),
          ]),

        // Action buttons: Maps + Search
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.map, size: 16),
                label: const Text('Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandBlue,
                  side: const BorderSide(color: AppColors.brandBlue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _launchUrl(
                    'https://www.google.com/search?q=${Uri.encodeComponent(_name)}'),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ),

        // Loading indicator
        if (_loadingDetails)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String value, {bool isLink = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        isLink ? AppColors.brandBlue : AppColors.textPrimary,
                    decoration: isLink
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );

  // ════════════════════════════════════════════
  // REVIEWS TAB
  // ════════════════════════════════════════════
  Widget _buildReviewsTab(ScrollController sc) {
    final details = _placeDetails;
    final reviews = details?.reviews ?? [];
    final comments = _comments ?? [];

    return ListView(
      controller: sc,
      padding: const EdgeInsets.all(20),
      children: [
        // Rating summary
        if (details?.rating != null)
          _card([
            Row(children: [
              Text(details!.rating!.toStringAsFixed(1),
                  style: GoogleFonts.dmSans(
                      fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        children: List.generate(
                            5,
                            (i) => Icon(
                                i < details.rating!.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 18))),
                    if (details.reviewCount != null)
                      Text('${details.reviewCount} reviews',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ]),
            ]),
          ]),

        if (reviews.isEmpty && _loadingDetails)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2))),

        if (reviews.isEmpty && !_loadingDetails && details != null)
          _card([
            Center(
                child: Column(children: [
              const Icon(Icons.rate_review_outlined,
                  size: 36, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              const Text('No reviews yet',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadPlaceDetails,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Load Reviews'),
              ),
            ])),
          ]),

        // Google reviews
        for (final r in reviews) ...[
          _card([
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: r.profilePhoto != null
                    ? NetworkImage(r.profilePhoto!)
                    : null,
                child: r.profilePhoto == null
                    ? Text(r.author.isNotEmpty ? r.author[0] : '?',
                        style: const TextStyle(fontSize: 14))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(r.author,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Row(children: [
                      ...List.generate(
                          5,
                          (i) => Icon(
                              i < r.rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 14)),
                      if (r.time.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(r.time,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ],
                    ]),
                  ])),
            ]),
            if (r.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(r.text,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5)),
            ],
          ]),
        ],

        // User comments
        if (comments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle('User Comments'),
          const SizedBox(height: 8),
          for (final c in comments)
            _card([
              Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: c.userAvatar != null
                      ? NetworkImage(c.userAvatar!)
                      : null,
                  child: c.userAvatar == null
                      ? Text((c.userName ?? '?')[0],
                          style: const TextStyle(fontSize: 12))
                      : null,
                ),
                const SizedBox(width: 8),
                Text(c.userName ?? 'User',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              Text(c.content,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ]),
        ],

        if (_loadingComments)
          const Padding(
              padding: EdgeInsets.all(20),
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ],
    );
  }

  // ════════════════════════════════════════════
  // GALLERY TAB (Masonry layout)
  // ════════════════════════════════════════════
  Widget _buildGalleryTab(ScrollController sc) {
    if (_loadingPhotos) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final photos = _photos ?? [];
    final allPhotos = <String>[
      if (_placeDetails?.image != null) _placeDetails!.image!,
      if (_imageUrl.isNotEmpty) _imageUrl,
      ...photos,
    ].toSet().toList();

    if (allPhotos.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.photo_library_outlined,
            size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        const Text('No photos available',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _loadPhotos,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ]));
    }

    return ListView(
      controller: sc,
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            const Icon(Icons.camera_alt,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('Photos (${allPhotos.length})',
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
        ),

        // Masonry: 1 large left + 2 stacked right (first 3 photos)
        if (allPhotos.length >= 3) ...[
          SizedBox(
            height: 220,
            child: Row(children: [
              // Large photo (left, ~2/3)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _photoTile(allPhotos[0], allPhotos, 0,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16))),
                ),
              ),
              // 2 stacked (right, ~1/3)
              Expanded(
                flex: 1,
                child: Column(children: [
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _photoTile(allPhotos[1], allPhotos, 1,
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16))),
                  )),
                  Expanded(
                      child: _photoTile(allPhotos[2], allPhotos, 2,
                          borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(16)))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],

        // Remaining photos: 2-column grid
        if (allPhotos.length > 3)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: allPhotos.length - 3,
            itemBuilder: (context, i) => _photoTile(
                allPhotos[i + 3], allPhotos, i + 3,
                borderRadius: BorderRadius.circular(12)),
          )
        else if (allPhotos.length < 3)
          // Less than 3 photos — simple grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: allPhotos.length,
            itemBuilder: (context, i) => _photoTile(
                allPhotos[i], allPhotos, i,
                borderRadius: BorderRadius.circular(12)),
          ),
      ],
    );
  }

  Widget _photoTile(String url, List<String> allPhotos, int index,
      {BorderRadius? borderRadius}) {
    return GestureDetector(
      onTap: () => _showFullScreenPhoto(context, allPhotos, index),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, _) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))),
          errorWidget: (_, _, _) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image,
                  color: AppColors.textSecondary)),
        ),
      ),
    );
  }

  void _showFullScreenPhoto(
      BuildContext context, List<String> photos, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${index + 1} / ${photos.length}'),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: photos.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                    imageUrl: photos[i], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // BOOKING TAB
  // ════════════════════════════════════════════
  Widget _buildBookingTab(ScrollController sc) {
    final encodedName = Uri.encodeComponent(_name);

    return ListView(
      controller: sc,
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Row(children: [
          const Icon(Icons.confirmation_num_outlined,
              size: 18, color: AppColors.brandBlue),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Available Tours & Tickets',
                  style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))),
          GestureDetector(
            onTap: () {
              // Could refresh booking data
            },
            child: const Icon(Icons.refresh,
                size: 18, color: AppColors.textSecondary),
          ),
        ]),
        const SizedBox(height: 14),

        // GetYourGuide
        _bookingProviderCard(
          logoColor: const Color(0xFFFF5533),
          logoIcon: Icons.check_circle,
          logoBgColor: AppColors.brandBlue,
          providerName: 'GetYourGuide',
          badge: 'Free Cancellation',
          badgeColor: AppColors.success,
          url: 'https://www.getyourguide.com/s/?q=$encodedName',
        ),
        const SizedBox(height: 10),

        // Klook
        _bookingProviderCard(
          logoColor: const Color(0xFFFF5722),
          logoIcon: Icons.local_activity,
          logoBgColor: const Color(0xFF10B981),
          providerName: 'Klook',
          badge: 'Best for Asia',
          badgeColor: const Color(0xFF10B981),
          url: 'https://www.klook.com/search/result/?keyword=$encodedName',
        ),
        const SizedBox(height: 10),

        // Viator
        _bookingProviderCard(
          logoColor: const Color(0xFF7C3AED),
          logoIcon: Icons.explore,
          logoBgColor: const Color(0xFF7C3AED),
          providerName: 'Viator',
          badge: 'Trusted Reviews',
          badgeColor: const Color(0xFF7C3AED),
          url:
              'https://www.viator.com/searchResults/all?text=$encodedName',
        ),

        // Last updated
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 16),
          child: Text('Last updated: just now',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.6))),
        ),

        // Booking Tips
        _card([
          Row(children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.brandBlue),
            const SizedBox(width: 6),
            Text('Booking Tips',
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 10),
          _bulletPoint('Compare prices across different platforms'),
          _bulletPoint('Book in advance for popular attractions'),
          _bulletPoint('Check cancellation policies before booking'),
          _bulletPoint(
              'Look for combo deals that bundle multiple activities'),
        ]),
      ],
    );
  }

  Widget _bookingProviderCard({
    required Color logoColor,
    required IconData logoIcon,
    required Color logoBgColor,
    required String providerName,
    required String badge,
    required Color badgeColor,
    required String url,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.cardDarkMode : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: Theme.of(context).brightness == Brightness.dark ? null : [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Logo
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: logoBgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(logoIcon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(providerName,
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: badgeColor))),
          ]),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _launchUrl(url),
            child: Text('Search "$_name"',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.brandBlue,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: () => _launchUrl(url),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.brandBlue,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('CHECK WEBSITE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5))),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _launchUrl(url),
              child: const Text('VIEW DETAILS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandBlue)),
            ),
          ]),
        ])),
        // External link icon
        GestureDetector(
          onTap: () => _launchUrl(url),
          child: const Padding(
            padding: EdgeInsets.only(top: 4),
            child:
                Icon(Icons.open_in_new, size: 16, color: AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }

  Widget _bulletPoint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 6, right: 8),
              decoration: const BoxDecoration(
                  color: AppColors.textSecondary, shape: BoxShape.circle)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4))),
        ]),
      );

  // ─── Helpers ───

  Widget _card(List<Widget> children) => Builder(builder: (context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? null : [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );
  });

  Widget _sectionTitle(String title) => Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Future<void> _openInMaps() async {
    final lat = _lat;
    final lng = _lng;
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_address.isNotEmpty ? _address : _name)}');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
