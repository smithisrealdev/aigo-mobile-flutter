import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../services/place_service.dart';
import '../services/comment_service.dart';
import '../services/social_service.dart';
import '../services/image_service.dart';

// ──────────────────────────────────────────────
// Activity Detail Bottom Sheet
// 4 tabs: About · Reviews · Photos · Mentions
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
  List<PlaceMention>? _mentions;
  bool _loadingMentions = false;

  Map<String, dynamic> get _a => widget.activity;
  String get _name =>
      (_a['name'] ?? _a['title'] ?? 'Activity').toString();
  String get _desc =>
      (_a['description'] ?? _a['subtitle'] ?? '').toString();
  String get _category =>
      (_a['type'] ?? _a['category'] ?? '').toString();
  String get _time =>
      (_a['time'] ?? _a['start_time'] ?? '').toString();
  String get _duration =>
      (_a['duration'] ?? _a['estimated_duration'] ?? '').toString();
  String get _address => (_a['address'] ?? '').toString();
  String get _tips => (_a['tips'] ?? _a['notes'] ?? '').toString();
  String get _cost => (_a['cost'] ?? _a['estimated_cost'] ?? '').toString();
  double? get _lat => (_a['lat'] as num?)?.toDouble();
  double? get _lng => (_a['lng'] as num?)?.toDouble();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Load about tab data immediately
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
      case 3:
        if (_mentions == null && !_loadingMentions) _loadMentions();
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

  Future<void> _loadMentions() async {
    setState(() => _loadingMentions = true);
    try {
      final mentions = await SocialService.instance.fetchMentions(
        _name,
        placeAddress: _address.isNotEmpty ? _address : null,
      );
      if (mounted) setState(() => _mentions = mentions);
    } catch (_) {}
    if (mounted) setState(() => _loadingMentions = false);
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
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
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
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _name,
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tab bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.brandBlue,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.brandBlue,
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13),
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Photos'),
                  Tab(text: 'Mentions'),
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
                  _buildPhotosTab(scrollController),
                  _buildMentionsTab(scrollController),
                ],
              ),
            ),
          ],
        ),
      ),
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
        // Category badge
        if (_category.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _category[0].toUpperCase() + _category.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _catColor,
                ),
              ),
            ),
          ),
        if (_category.isNotEmpty) const SizedBox(height: 14),

        // Description
        if (_desc.isNotEmpty) _card([
          Text(
            _desc,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ]),

        // Duration + time
        if (_time.isNotEmpty || _duration.isNotEmpty)
          _card([
            if (_time.isNotEmpty)
              _infoRow(Icons.schedule, 'Time', _time),
            if (_duration.isNotEmpty)
              _infoRow(Icons.timelapse, 'Duration', _duration),
          ]),

        // Opening hours
        if (details?.openingHours != null &&
            details!.openingHours!.weekdayText.isNotEmpty)
          _card([
            _sectionTitle('Opening Hours'),
            const SizedBox(height: 6),
            for (final h in details.openingHours!.weekdayText)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(h,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
          ]),

        // Address + Open in Maps
        if (_address.isNotEmpty || _lat != null)
          _card([
            _infoRow(Icons.location_on, 'Address',
                _address.isNotEmpty ? _address : '${_lat}, ${_lng}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.map, size: 16),
                label: const Text('Open in Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandBlue,
                  side: const BorderSide(color: AppColors.brandBlue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),

        // Phone + website
        if (details?.phone != null || details?.website != null)
          _card([
            if (details?.phone != null)
              _infoRow(Icons.phone, 'Phone', details!.phone!),
            if (details?.website != null)
              InkWell(
                onTap: () => _launchUrl(details!.website!),
                child: _infoRow(Icons.language, 'Website', details!.website!,
                    isLink: true),
              ),
          ]),

        // Tips
        if (_tips.isNotEmpty)
          _card([
            _sectionTitle('Tips & Notes'),
            const SizedBox(height: 6),
            Text(_tips,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ]),

        // Cost
        if (_cost.isNotEmpty)
          _card([
            _infoRow(Icons.payments, 'Estimated Cost', _cost),
          ]),

        // Loading indicator
        if (_loadingDetails)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

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
            Row(
              children: [
                Text(
                  details!.rating!.toStringAsFixed(1),
                  style: GoogleFonts.dmSans(
                      fontSize: 32, fontWeight: FontWeight.w800),
                ),
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
                                size: 18,
                              )),
                    ),
                    if (details.reviewCount != null)
                      Text(
                        '${details.reviewCount} reviews',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ]),

        // Reviews list
        if (reviews.isEmpty && _loadingDetails)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2),
          )),

        if (reviews.isEmpty && !_loadingDetails && details != null)
          _card([
            Center(
              child: Column(
                children: [
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
                ],
              ),
            ),
          ]),

        for (final r in reviews) ...[
          _card([
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
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
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Row(
                        children: [
                          ...List.generate(
                              5,
                              (i) => Icon(
                                    i < r.rating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 14,
                                  )),
                          if (r.time.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(r.time,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (r.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.text,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4)),
            ],
          ]),
        ],

        // User comments section
        if (comments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle('User Comments'),
          const SizedBox(height: 8),
          for (final c in comments)
            _card([
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: c.userAvatar != null
                        ? NetworkImage(c.userAvatar!)
                        : null,
                    child: c.userAvatar == null
                        ? Text(
                            (c.userName ?? '?')[0],
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(c.userName ?? 'User',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Text(c.content,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ]),
        ],

        if (_loadingComments)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // PHOTOS TAB
  // ════════════════════════════════════════════
  Widget _buildPhotosTab(ScrollController sc) {
    if (_loadingPhotos) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final photos = _photos ?? [];
    // Add place details image if available
    final allPhotos = <String>[
      if (_placeDetails?.image != null) _placeDetails!.image!,
      ...photos,
    ].toSet().toList();

    if (allPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      );
    }

    return GridView.builder(
      controller: sc,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: allPhotos.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => _showFullScreenPhoto(context, allPhotos, i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: allPhotos[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image,
                  color: AppColors.textSecondary),
            ),
          ),
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
                  imageUrl: photos[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // MENTIONS TAB
  // ════════════════════════════════════════════
  Widget _buildMentionsTab(ScrollController sc) {
    if (_loadingMentions) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final mentions = _mentions ?? [];

    return ListView(
      controller: sc,
      padding: const EdgeInsets.all(20),
      children: [
        if (mentions.isEmpty && _mentions != null)
          _card([
            const Center(
              child: Column(
                children: [
                  Icon(Icons.public, size: 36, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text('No social mentions found',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ]),

        for (final m in mentions)
          _card([
            Row(
              children: [
                // Platform icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _platformColor(m.platform).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _platformIcon(m.platform),
                    size: 18,
                    color: _platformColor(m.platform),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title ?? m.source,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        m.platform.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _platformColor(m.platform),
                        ),
                      ),
                    ],
                  ),
                ),
                if (m.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: m.thumbnailUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
            if (m.excerpt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(m.excerpt,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
            if (m.url != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _launchUrl(m.url!),
                child: Text('View on ${m.platform}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),

        // Search on web button
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _launchUrl(
                'https://www.google.com/search?q=${Uri.encodeComponent(_name)}+reviews+social+media'),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Search on Web'),
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

  // ─── Helpers ───

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _sectionTitle(String title) => Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Widget _infoRow(IconData icon, String label, String value,
      {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isLink ? AppColors.brandBlue : AppColors.textPrimary,
                      decoration:
                          isLink ? TextDecoration.underline : TextDecoration.none,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'tiktok':
        return Icons.music_note;
      case 'instagram':
        return Icons.camera_alt;
      case 'reddit':
        return Icons.forum;
      case 'twitter':
      case 'x':
        return Icons.tag;
      default:
        return Icons.article;
    }
  }

  Color _platformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'tiktok':
        return const Color(0xFF010101);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'reddit':
        return const Color(0xFFFF4500);
      case 'twitter':
      case 'x':
        return const Color(0xFF1DA1F2);
      default:
        return AppColors.brandBlue;
    }
  }

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
