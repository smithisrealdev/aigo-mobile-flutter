import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/expense_service.dart';
import '../services/recommendation_service.dart';
import '../services/ai_picks_service.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _tripController = TextEditingController();
  final PageController _carouselController = PageController(viewportFraction: 0.92);
  bool _isInputActive = false;
  bool _emailBannerDismissed = false;
  List<AiPick>? _aiPicks;
  bool _aiPicksLoading = true;
  int _carouselPage = 0;

  static const _prompts = [
    'Weekend getaway in Paris',
    '7 days in Japan',
    'Beach vacation in Thailand',
    'Road trip in Italy',
    'Culture tour in Kyoto',
  ];

  int _promptIndex = 0;
  int _charIndex = 0;
  bool _deleting = false;
  String _displayText = '';
  late final _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _loadAiPicks();
  }

  Future<void> _loadAiPicks() async {
    try {
      final picks = await AiPicksService.instance.getAiPicks();
      if (mounted) setState(() { _aiPicks = picks; _aiPicksLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _aiPicksLoading = false; });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tripController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final interval = _deleting ? 30 : 60;
    if ((elapsed - _lastTick).inMilliseconds < interval) return;
    _lastTick = elapsed;
    final prompt = _prompts[_promptIndex];
    if (!_deleting) {
      if (_charIndex <= prompt.length) {
        setState(() => _displayText = prompt.substring(0, _charIndex));
        _charIndex++;
      } else {
        _deleting = true;
        _lastTick = elapsed + const Duration(milliseconds: 1500);
      }
    } else {
      if (_charIndex > 0) {
        _charIndex--;
        setState(() => _displayText = prompt.substring(0, _charIndex));
      } else {
        _deleting = false;
        _promptIndex = (_promptIndex + 1) % _prompts.length;
        _lastTick = elapsed + const Duration(milliseconds: 400);
      }
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getUserName() {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return 'Traveler';
    final meta = user.userMetadata;
    if (meta != null && meta['full_name'] != null) {
      final fullName = meta['full_name'] as String;
      return fullName.split(' ').first;
    }
    if (user.email != null) return user.email!.split('@').first;
    return 'Traveler';
  }

  String _monthDay(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }

  void _submitTrip(BuildContext context) {
    final query = _tripController.text.trim();
    if (query.isNotEmpty) context.push('/ai-chat', extra: query);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BUILD — Dime!-style Home
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.brandBlue,
        onRefresh: () async {
          ref.invalidate(tripsProvider);
          AiPicksService.instance.clearCache();
          _loadAiPicks();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Greeting row (like Dime! "Hi, Apichet Nuamtun!") ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
                child: Row(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => context.go('/profile'),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3F4F6),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF9CA3AF), size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name
                    Expanded(
                      child: Text(
                        'Hi, ${_getUserName()}!',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    // Chat icon (like Dime! chatbot icon)
                    GestureDetector(
                      onTap: () => context.push('/ai-chat'),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brandBlue.withValues(alpha: 0.08),
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppColors.brandBlue, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Notification bell
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3F4F6),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: Color(0xFF6B7280), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Email verification banner ──
            SliverToBoxAdapter(child: _buildEmailVerificationBanner()),

            // ── Search bar ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildSearchBar(context),
              ),
            ),

            // ── Hero Carousel (like Dime! promo banners) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: tripsAsync.when(
                  data: (trips) => _buildHeroCarousel(context, trips),
                  loading: () => _buildCarouselSkeleton(),
                  error: (_, __) => _buildCarouselEmpty(context),
                ),
              ),
            ),

            // ── Page dots ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: tripsAsync.when(
                  data: (trips) => _buildPageDots(trips.isEmpty ? 1 : trips.length.clamp(1, 5)),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // ── Stat cards row (like Dime! stock tickers) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: tripsAsync.when(
                  data: (trips) => _buildStatCards(trips),
                  loading: () => _buildStatCardsSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // ── Quick Actions (horizontal pills) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildQuickActions(context),
              ),
            ),

            // ── AI Picks section (tinted bg like Dime!) ──
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(top: 28),
                padding: const EdgeInsets.only(top: 20, bottom: 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                    bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 20, color: AppColors.brandBlue),
                              const SizedBox(width: 8),
                              const Text('AI Picks for You', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.go('/explore'),
                            child: Row(
                              children: [
                                const Text('See All', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.brandBlue),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Based on your travel style', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 14),
                    _buildAiPicksDynamic(context),
                  ],
                ),
              ),
            ),

            // ── Tailored for You ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _buildTailoredForYou(),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SEARCH BAR — animated typing
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Expanded(
            child: _isInputActive
                ? TextField(
                    controller: _tripController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Describe your dream trip...',
                      hintStyle: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
                      border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (val) => _submitTrip(context),
                  )
                : GestureDetector(
                    onTap: () { setState(() => _isInputActive = true); _ticker.stop(); },
                    child: Row(
                      children: [
                        Text(
                          _displayText.isEmpty ? 'Plan my trip with AI' : _displayText,
                          style: TextStyle(fontSize: 15, color: _displayText.isEmpty ? const Color(0xFF9CA3AF) : AppColors.textPrimary),
                        ),
                        if (_displayText.isNotEmpty) _BlinkingCursor(),
                      ],
                    ),
                  ),
          ),
          if (_isInputActive && _tripController.text.trim().isNotEmpty)
            GestureDetector(
              onTap: () => _submitTrip(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ),
            )
          else
            Icon(Icons.tune, size: 20, color: const Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HERO CAROUSEL — like Dime! promo banners
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildHeroCarousel(BuildContext context, List<Trip> trips) {
    if (trips.isEmpty) return _buildCarouselEmpty(context);

    final displayTrips = trips.take(5).toList();
    return SizedBox(
      height: 170,
      child: PageView.builder(
        controller: _carouselController,
        itemCount: displayTrips.length,
        onPageChanged: (i) => setState(() => _carouselPage = i),
        itemBuilder: (_, i) {
          final trip = displayTrips[i];
          final startDate = trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;
          final endDate = trip.endDate != null ? DateTime.tryParse(trip.endDate!) : null;
          final days = (startDate != null && endDate != null) ? endDate.difference(startDate).inDays : null;
          final imageUrl = trip.coverImage ?? 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=600&h=300&fit=crop';

          // Overlay gradient colors (bottom gradient tint)
          final gradientColors = [
            const Color(0xFF059669),
            const Color(0xFFEA580C),
            const Color(0xFF2563EB),
            const Color(0xFF7C3AED),
            const Color(0xFFDB2777),
          ];
          final gradColor = gradientColors[i % gradientColors.length];

          return GestureDetector(
            onTap: () => context.push('/itinerary', extra: trip),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Full background image
                  CachedNetworkImage(
                    imageUrl: imageUrl, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: gradColor),
                  ),
                  // Gradient overlay (dark bottom for text readability)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [
                          gradColor.withValues(alpha: 0.15),
                          gradColor.withValues(alpha: 0.5),
                          gradColor.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _tripStatus(trip),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                          ),
                        ),
                        const Spacer(),
                        // Trip title
                        Text(
                          trip.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Date + days
                        Row(
                          children: [
                            if (startDate != null) ...[
                              const Icon(Icons.calendar_today, size: 13, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '${_monthDay(startDate)}${endDate != null ? ' – ${_monthDay(endDate)}' : ''}',
                                style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                              ),
                            ],
                            if (days != null) ...[
                              const SizedBox(width: 10),
                              Text('$days days', style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarouselEmpty(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/ai-chat'),
      child: Container(
        height: 170,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: 20, bottom: 20, child: Icon(Icons.flight_takeoff, size: 80, color: Colors.white.withValues(alpha: 0.15))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Plan Your First Trip', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Let AI help you create the perfect itinerary', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Get Started', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselSkeleton() {
    return Container(
      height: 170,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildPageDots(int count) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _carouselPage;
        return Container(
          width: active ? 20 : 6, height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? AppColors.brandBlue : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STAT CARDS — like Dime! stock tickers (4 cards in row)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildStatCards(List<Trip> trips) {
    final totalTrips = trips.length;
    double totalBudget = 0;
    double totalSpent = 0;
    int? daysUntilNext;

    final now = DateTime.now();
    for (final t in trips) {
      if (t.budgetTotal != null) totalBudget += t.budgetTotal!;
      if (t.budgetSpent != null) totalSpent += t.budgetSpent!;
      if (t.startDate != null) {
        final start = DateTime.tryParse(t.startDate!);
        if (start != null && start.isAfter(now)) {
          final d = start.difference(now).inDays;
          if (daysUntilNext == null || d < daysUntilNext) daysUntilNext = d;
        }
      }
    }

    final pctUsed = totalBudget > 0 ? ((totalSpent / totalBudget) * 100).round() : 0;

    return Row(
      children: [
        _StatCard(icon: Icons.flight, label: 'Trips', value: '$totalTrips', color: const Color(0xFF059669)),
        const SizedBox(width: 10),
        _StatCard(icon: Icons.account_balance_wallet, label: 'Budget', value: '${pctUsed}%', color: pctUsed < 50 ? const Color(0xFF059669) : pctUsed < 80 ? AppColors.brandBlue : const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        _StatCard(icon: Icons.calendar_today, label: 'Next Trip', value: daysUntilNext != null ? '${daysUntilNext}d' : '—', color: AppColors.brandBlue),
        const SizedBox(width: 10),
        _StatCard(icon: Icons.savings, label: 'Spent', value: '฿${totalSpent.toStringAsFixed(0)}', color: const Color(0xFFD97706)),
      ],
    );
  }

  Widget _buildStatCardsSkeleton() {
    return Row(
      children: List.generate(4, (i) => Expanded(
        child: Container(
          height: 72,
          margin: EdgeInsets.only(right: i < 3 ? 10 : 0),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
        ),
      )),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // QUICK ACTIONS — horizontal scrollable pills
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      ('Create Trip', Icons.add_circle_outline, AppColors.brandBlue, () => context.push('/ai-chat')),
      ('My Trips', Icons.map_outlined, const Color(0xFF059669), () => context.go('/trips')),
      ('Budget', Icons.account_balance_wallet_outlined, const Color(0xFFD97706), () => context.push('/budget')),
      ('Explore', Icons.explore_outlined, const Color(0xFF7C3AED), () => context.go('/explore')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: actions.asMap().entries.map((entry) {
          final i = entry.key;
          final a = entry.value;
          final isFirst = i == 0;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: a.$4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isFirst ? a.$3 : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isFirst ? a.$3 : const Color(0xFFE5E7EB), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(a.$2, size: 18, color: isFirst ? Colors.white : a.$3),
                    const SizedBox(width: 8),
                    Text(a.$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isFirst ? Colors.white : AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // AI PICKS CAROUSEL
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildAiPicksDynamic(BuildContext context) {
    if (_aiPicksLoading) {
      return SizedBox(
        height: 190,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(width: 160, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16))),
          )),
        ),
      );
    }
    final picks = _aiPicks ?? [];
    if (picks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: picks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = picks[i];
          return _AiPickCard(
            imageUrl: p.imageUrl, title: p.title, subtitle: p.subtitle, badge: p.matchReason,
            onTap: () => context.push('/ai-chat', extra: 'Tell me about ${p.destination}'),
          );
        },
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // TAILORED FOR YOU
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTailoredForYou() {
    final recAsync = ref.watch(aiRecommendationsProvider);
    return recAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        final items = result.structured?.items ?? [];
        if (items.isEmpty && result.recommendation == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, size: 18, color: AppColors.brandBlue),
                const SizedBox(width: 8),
                const Text('Tailored for You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
              if (result.recommendation != null) ...[
                const SizedBox(height: 10),
                Text(result.recommendation!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
              ],
              if (items.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: Icon(_emojiToIcon(item.emoji), size: 16, color: AppColors.brandBlue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${item.label}: ${item.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      if (item.detail != null) Text(item.detail!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                  ]),
                )),
              ],
              if (result.structured?.tip != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.brandBlue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(result.structured!.tip!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _tripStatus(Trip t) {
    final now = DateTime.now();
    final start = t.startDate != null ? DateTime.tryParse(t.startDate!) : null;
    final end = t.endDate != null ? DateTime.tryParse(t.endDate!) : null;
    if (start != null && now.isBefore(start)) return 'UPCOMING';
    if (start != null && end != null && now.isAfter(start) && now.isBefore(end)) return 'IN PROGRESS';
    if (end != null && now.isAfter(end)) return 'COMPLETED';
    return 'PLANNED';
  }

  Widget _buildEmailVerificationBanner() {
    if (_emailBannerDismissed) return const SizedBox.shrink();
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null || user.emailConfirmedAt != null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
        const SizedBox(width: 8),
        const Expanded(child: Text('Please verify your email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF92400E)))),
        TextButton(
          onPressed: () async {
            try {
              await SupabaseConfig.client.auth.resend(type: OtpType.email, email: user.email!);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
          child: const Text('Resend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
        ),
        GestureDetector(
          onTap: () => setState(() => _emailBannerDismissed = true),
          child: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
        ),
      ]),
    );
  }

  static IconData _emojiToIcon(String emoji) {
    if (emoji.contains('🍜') || emoji.contains('🍽') || emoji.contains('🍕')) return Icons.restaurant;
    if (emoji.contains('🌿') || emoji.contains('🌳') || emoji.contains('🏔')) return Icons.park;
    if (emoji.contains('🏛') || emoji.contains('🎭')) return Icons.account_balance;
    if (emoji.contains('🛍')) return Icons.shopping_bag;
    if (emoji.contains('🧗') || emoji.contains('🏄')) return Icons.hiking;
    if (emoji.contains('✈') || emoji.contains('🌍')) return Icons.flight;
    if (emoji.contains('💰') || emoji.contains('💵')) return Icons.savings;
    if (emoji.contains('☀') || emoji.contains('🌤')) return Icons.wb_sunny;
    return Icons.place;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// STAT CARD — compact metric tile (like Dime! stock ticker)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AI PICK CARD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _AiPickCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  const _AiPickCard({required this.imageUrl, required this.title, required this.subtitle, required this.badge, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54], stops: [0.35, 1.0]),
            )),
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
              ),
            ),
            Positioned(
              bottom: 12, left: 12, right: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BLINKING CURSOR
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(width: 2, height: 16, margin: const EdgeInsets.only(left: 1), color: AppColors.brandBlue),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PILL PROGRESS BAR (kept for other screens)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class PillProgressBar extends StatelessWidget {
  final double value;
  final int segments;
  final double height;

  const PillProgressBar({super.key, required this.value, this.segments = 10, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final filled = (value * segments).round().clamp(0, segments);
    return Row(
      children: List.generate(segments, (i) {
        final isFilled = i < filled;
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(right: i < segments - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: isFilled ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
      }),
    );
  }
}
