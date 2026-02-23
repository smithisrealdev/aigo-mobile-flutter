import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/trip_map_view.dart';

// ─── Model ───────────────────────────────────────────────────
class GuidePlace {
  final String name;
  final String category;
  final String description;
  final double rating;
  final int reviewCount;
  final String duration;
  final String cost;
  final String address;
  final double lat;
  final double lng;
  final String? imageUrl;
  final String imageSearchTerm;

  const GuidePlace({
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.duration,
    required this.cost,
    required this.address,
    required this.lat,
    required this.lng,
    this.imageUrl,
    this.imageSearchTerm = '',
  });

  factory GuidePlace.fromJson(Map<String, dynamic> j) => GuidePlace(
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        description: j['description'] ?? '',
        rating: (j['rating'] ?? 4.0).toDouble(),
        reviewCount: (j['review_count'] ?? 0) is int
            ? j['review_count'] ?? 0
            : int.tryParse('${j['review_count']}') ?? 0,
        duration: j['estimated_duration'] ?? j['duration'] ?? '',
        cost: j['estimated_cost'] ?? j['cost'] ?? '',
        address: j['address'] ?? '',
        lat: (j['lat'] ?? 0).toDouble(),
        lng: (j['lng'] ?? 0).toDouble(),
        imageSearchTerm: j['image_search_term'] ?? j['name'] ?? '',
      );
}

// ─── Constants ───────────────────────────────────────────────
const _pinColor = Color(0xFFEA4335);
const _brandBlue = Color(0xFF2563EB);
const _textPrimary = Color(0xFF111827);
const _textSecondary = Color(0xFF6B7280);
const _chipBg = Color(0xFFF3F4F6);
const _mapsKey = 'AIzaSyDvA2wmeqKw93M4v8b2Xm1uFWtIcCs46l0';
const _orKey =
    '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';

// ─── Screen ──────────────────────────────────────────────────
class DestinationGuideScreen extends ConsumerStatefulWidget {
  final String destination;
  final String? tripId;
  const DestinationGuideScreen(
      {super.key, required this.destination, this.tripId});

  @override
  ConsumerState<DestinationGuideScreen> createState() =>
      _DestinationGuideScreenState();
}

class _DestinationGuideScreenState
    extends ConsumerState<DestinationGuideScreen> {
  List<GuidePlace> _places = [];
  bool _loading = true;
  String? _error;
  bool _showMap = true;
  final _saved = <int>{};
  final _photoCache = <String, String>{};

  @override
  void initState() {
    super.initState();
    _fetchGuide();
  }

  // ── AI fetch ───────────────────────────────────────────────
  Future<void> _fetchGuide() async {
    try {
      final dio = Dio();
      final resp = await dio.post(
        'https://openrouter.ai/api/v1/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $_orKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'google/gemini-2.5-flash',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a travel guide data engine. Return ONLY a valid JSON array, no markdown fences, no extra text.'
            },
            {
              'role': 'user',
              'content':
                  'List the top 20 things to do and attractions in ${widget.destination}. '
                      'For each, provide: name, category (one word like Museum, Temple, Park, Market, etc.), '
                      'description (2 sentences), rating (1-5 float), review_count (integer), '
                      'estimated_duration (e.g. "2-3 hours"), estimated_cost (e.g. "Free" or "\$15"), '
                      'address, lat (float), lng (float), image_search_term (for Google search). '
                      'Return as a JSON array of objects.',
            }
          ],
        },
      );

      final content = resp.data['choices'][0]['message']['content'] as String;
      // Strip markdown fences if present
      var cleaned = content.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
      }
      final list = jsonDecode(cleaned) as List;
      final places = list.map((e) => GuidePlace.fromJson(e as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _places = places;
          _loading = false;
        });
        // Fetch photos in background
        _fetchPhotos();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchPhotos() async {
    final dio = Dio();
    for (int i = 0; i < _places.length; i++) {
      final p = _places[i];
      final query = '${p.name} ${widget.destination}';
      try {
        final resp = await dio.get(
          'https://maps.googleapis.com/maps/api/place/findplacefromtext/json',
          queryParameters: {
            'input': query,
            'inputtype': 'textquery',
            'fields': 'photos',
            'key': _mapsKey,
          },
        );
        final candidates = resp.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final photos = candidates[0]['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            final ref = photos[0]['photo_reference'];
            final url =
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$ref&key=$_mapsKey';
            if (mounted) {
              setState(() => _photoCache[p.name] = url);
            }
          }
        }
      } catch (_) {}
    }
  }

  String? _getPhotoUrl(GuidePlace p) => _photoCache[p.name];

  List<MapActivity> get _mapActivities => _places
      .asMap()
      .entries
      .map((e) => MapActivity(
            name: e.value.name,
            time: '',
            lat: e.value.lat,
            lng: e.value.lng,
            dayIndex: 0,
            numberInDay: e.key + 1,
            imageUrl: _getPhotoUrl(e.value),
            category: e.value.category,
            rating: e.value.rating,
            cost: e.value.cost,
            duration: e.value.duration,
          ))
      .toList();

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    final n = _places.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── App bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: _textPrimary,
            elevation: 0.5,
            title: Text(
              _loading ? 'Guide to $dest' : 'Top $n things to do in $dest',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary),
            ),
            actions: [
              IconButton(
                icon: Icon(_showMap ? Icons.map : Icons.map_outlined,
                    color: _showMap ? _brandBlue : _textSecondary),
                onPressed: () => setState(() => _showMap = !_showMap),
                tooltip: _showMap ? 'Hide map' : 'Show map',
              ),
            ],
          ),

          // ── Map ──
          if (_showMap && _places.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: TripMapView(
                  selectedDayIndex: 0,
                  activities: _mapActivities,
                ),
              ),
            ),

          // ── Hero / branding ──
          if (!_loading && _places.isNotEmpty)
            SliverToBoxAdapter(child: _heroSection(dest, n)),

          // ── Loading state ──
          if (_loading)
            SliverToBoxAdapter(child: _buildLoading())
          else if (_error != null)
            SliverToBoxAdapter(child: _buildError())
          else ...[
            // ── Branding text ──
            SliverToBoxAdapter(child: _brandingSection(dest)),
            // ── Activity list ──
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _activityCard(i, _places[i]),
                childCount: _places.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }

  // ── Hero section ───────────────────────────────────────────
  Widget _heroSection(String dest, int n) {
    final heroUrl = _getPhotoUrl(_places.first);
    return Stack(
      children: [
        // Hero image
        if (heroUrl != null)
          CachedNetworkImage(
            imageUrl: heroUrl,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(height: 220, color: Colors.grey.shade200),
            errorWidget: (_, __, ___) =>
                Container(height: 220, color: Colors.grey.shade200),
          )
        else
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_brandBlue, _brandBlue.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.travel_explore, size: 64, color: Colors.white.withValues(alpha: 0.6)),
          ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
              ),
            ),
          ),
        ),
        // Title
        Positioned(
          bottom: 16,
          left: 20,
          right: 20,
          child: Text(
            'Top $n things to do\nin $dest',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ── Branding section ───────────────────────────────────────
  Widget _brandingSection(String dest) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AiGo's AI has analyzed thousands of reviews, travel blogs, and local "
            "recommendations to curate the best places to visit in $dest. "
            "From iconic landmarks to hidden gems, here's your ultimate guide.",
            style: const TextStyle(
                fontSize: 14, color: _textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          const Text('Why trust AiGo',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Our AI travel companion analyzes data from Google Reviews, TripAdvisor, '
            'travel blogs, and local guides to rank the best attractions. Each '
            'recommendation is scored based on popularity, visitor satisfaction, and uniqueness.',
            style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Activity card ──────────────────────────────────────────
  Widget _activityCard(int index, GuidePlace p) {
    final isSaved = _saved.contains(index);
    final photoUrl = _getPhotoUrl(p);
    final categories = p.category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (categories.isEmpty) categories.add(p.category);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Numbered badge
              Container(
                width: 32,
                height: 32,
                decoration:
                    const BoxDecoration(color: _pinColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Save
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() {
                            isSaved
                                ? _saved.remove(index)
                                : _saved.add(index);
                          }),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  size: 16,
                                  color: isSaved ? _brandBlue : _textSecondary),
                              const SizedBox(width: 4),
                              Text(isSaved ? 'Saved' : 'Save',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isSaved ? _brandBlue : _textSecondary,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Category chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final c in categories)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _chipBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(c,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(p.description,
                        style: const TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                            height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    // Stats row
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text('${p.rating}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary)),
                        const SizedBox(width: 2),
                        Text(
                            '(${_formatCount(p.reviewCount)})',
                            style: const TextStyle(
                                fontSize: 11, color: _textSecondary)),
                        if (p.duration.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Text('·',
                              style: TextStyle(color: _textSecondary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.schedule,
                              size: 13, color: _textSecondary),
                          const SizedBox(width: 3),
                          Text(p.duration,
                              style: const TextStyle(
                                  fontSize: 11, color: _textSecondary)),
                        ],
                        if (p.cost.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Text('·',
                              style: TextStyle(color: _textSecondary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.payments_outlined,
                              size: 13, color: _textSecondary),
                          const SizedBox(width: 3),
                          Text(p.cost,
                              style: const TextStyle(
                                  fontSize: 11, color: _textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Photo thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200),
                        errorWidget: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image,
                                size: 20, color: Colors.grey)),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image,
                            size: 20, color: Colors.grey)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.grey.shade100),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
    return '$count';
  }

  // ── Loading skeleton ───────────────────────────────────────
  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: _brandBlue, strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            'Generating your guide to ${widget.destination}...',
            style: const TextStyle(fontSize: 15, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Our AI is finding the best places for you',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 40),
          // Skeleton cards
          for (int i = 0; i < 5; i++) ...[
            _skeletonCard(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _skeletonCard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: Colors.grey.shade200, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 16,
                  width: 180,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8))),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: _pinColor),
          const SizedBox(height: 16),
          const Text('Failed to load guide',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 8),
          Text(_error ?? '', style: const TextStyle(fontSize: 13, color: _textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _fetchGuide();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
