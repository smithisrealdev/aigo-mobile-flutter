
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
  static const _cardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 10,
    offset: Offset(0, 2),
  );

  final TextEditingController _tripController = TextEditingController();
  bool _isInputActive = false;
  bool _emailBannerDismissed = false;
  List<AiPick>? _aiPicks;
  bool _aiPicksLoading = true;

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
    if (user.email != null) {
      return user.email!.split('@').first;
    }
    return 'Traveler';
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Compact Header with embedded search ──
          _buildHeader(context),

          // ── Email verification banner ──
          _buildEmailVerificationBanner(),

          // ── Scrollable body ──
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brandBlue,
              onRefresh: () async {
                ref.invalidate(tripsProvider);
                AiPicksService.instance.clearCache();
                _loadAiPicks();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting + Style Tags ──
                    Text(
                      '${_greeting()}, ${_getUserName()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Where to next?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Quick Actions ──
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _QuickAction(
                          icon: Icons.add_circle_outline,
                          label: 'Create Trip',
                          bgColor: AppColors.brandBlue.withValues(alpha: 0.08),
                          onTap: () => context.push('/ai-chat'),
                        ),
                        _QuickAction(
                          icon: Icons.map_outlined,
                          label: 'My Trips',
                          bgColor: const Color(0xFFFFB347).withValues(alpha: 0.12),
                          onTap: () => context.go('/trips'),
                        ),
                        _QuickAction(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Budget',
                          bgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          onTap: () => context.push('/budget'),
                        ),
                        _QuickAction(
                          icon: Icons.public_outlined,
                          label: 'Marketplace',
                          bgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          onTap: () => context.go('/explore'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Upcoming Trip ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upcoming Trip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/trips'),
                          child: const Text(
                            'See All',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    tripsAsync.when(
                      data: (trips) => _buildUpcomingTripReal(context, trips),
                      loading: () => _buildUpcomingTripSkeleton(),
                      error: (e, _) => _buildErrorCard('Failed to load trips', () => ref.invalidate(tripsProvider)),
                    ),

                    const SizedBox(height: 20),

                    // ── Budget Overview (only if trips exist) ──
                    tripsAsync.when(
                      data: (trips) => trips.isEmpty
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Budget',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildBudgetReal(context, trips),
                                const SizedBox(height: 24),
                              ],
                            ),
                      loading: () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 10),
                          _buildBudgetSkeleton(),
                          const SizedBox(height: 24),
                        ],
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // ── AI Picks for You ──
                    _buildAiPicksHeader(context),
                    const SizedBox(height: 4),
                    const Text(
                      'Based on your travel style',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _buildAiPicksDynamic(context),

                    const SizedBox(height: 24),

                    // ── Tailored for You (AI Recommendations) ──
                    _buildTailoredForYou(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTripReal(BuildContext context, List<Trip> trips) {
    if (trips.isEmpty) {
      return GestureDetector(
        onTap: () => context.push('/ai-chat'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [_cardShadow],
            border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(Icons.flight_takeoff, size: 40, color: AppColors.brandBlue.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              const Text('No trips yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Tap to plan your first trip with AI!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    // Find upcoming trip (earliest future start date, or most recent)
    final now = DateTime.now();
    Trip? upcoming;
    for (final t in trips) {
      if (t.startDate != null) {
        final start = DateTime.tryParse(t.startDate!);
        if (start != null && start.isAfter(now)) {
          if (upcoming == null || start.isBefore(DateTime.parse(upcoming.startDate!))) {
            upcoming = t;
          }
        }
      }
    }
    upcoming ??= trips.first;

    final startDate = upcoming.startDate != null ? DateTime.tryParse(upcoming.startDate!) : null;
    final endDate = upcoming.endDate != null ? DateTime.tryParse(upcoming.endDate!) : null;
    final days = (startDate != null && endDate != null) ? endDate.difference(startDate).inDays : null;
    final dateStr = startDate != null ? '${_monthDay(startDate)}${endDate != null ? ' – ${_monthDay(endDate)}' : ''}${days != null ? ' · $days days' : ''}' : 'Not scheduled';
    final progress = (upcoming.budgetTotal != null && upcoming.budgetTotal! > 0 && upcoming.budgetSpent != null)
        ? (upcoming.budgetSpent! / upcoming.budgetTotal!).clamp(0.0, 1.0)
        : 0.0;
    final imageUrl = upcoming.coverImage ?? 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=200&h=200&fit=crop';

    return GestureDetector(
      onTap: () => context.push('/itinerary', extra: upcoming),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [_cardShadow],
          border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(width: 52, height: 52, color: AppColors.border, child: const Icon(Icons.image, size: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upcoming.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (progress > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandBlue),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${(progress * 100).toInt()}% budget used', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTripSkeleton() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [_cardShadow],
      ),
      child: Row(
        children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 120, height: 14, color: AppColors.border),
            const SizedBox(height: 6),
            Container(width: 160, height: 12, color: AppColors.border),
          ])),
        ],
      ),
    );
  }

  Widget _buildBudgetReal(BuildContext context, List<Trip> trips) {
    double totalBudget = 0;
    double totalSpent = 0;
    for (final t in trips) {
      if (t.budgetTotal != null) totalBudget += t.budgetTotal!;
      if (t.budgetSpent != null) totalSpent += t.budgetSpent!;
    }
    if (totalBudget == 0) {
      return _buildBudget(context); // fallback
    }
    final pct = (totalSpent / totalBudget).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => context.push('/budget'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [_cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.brandBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Budget', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('฿${totalSpent.toStringAsFixed(0)} / ฿${totalBudget.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            SizedBox(
              width: 40, height: 40,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: pct, strokeWidth: 3, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandBlue)),
                Text('${(pct * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
              ]),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSkeleton() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [_cardShadow]),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 100, height: 14, color: AppColors.border),
          const SizedBox(height: 4),
          Container(width: 140, height: 12, color: AppColors.border),
        ])),
      ]),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [_cardShadow]),
      child: Column(children: [
        Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
      ]),
    );
  }

  String _monthDay(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  Widget _buildEmailVerificationBanner() {
    if (_emailBannerDismissed) return const SizedBox.shrink();
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null || user.emailConfirmedAt != null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Please verify your email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
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
            child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Header: clean white with embedded search ──
  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.blueBorder, width: 1)),
          ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 16),
        child: Column(
          children: [
            // Logo row
            Row(
              children: [
                SvgPicture.asset('assets/images/logo_white.svg', height: 28,
                    colorFilter: const ColorFilter.mode(AppColors.brandBlue, BlendMode.srcIn)),
                const Spacer(),
                // Notification bell
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: AppColors.textSecondary, size: 22),
                      onPressed: () => context.push('/notifications'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.blueBorder, width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: AppColors.brandBlue, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Search bar embedded in header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.blueBorder, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18, color: AppColors.brandBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _isInputActive
                          ? TextField(
                              controller: _tripController,
                              autofocus: true,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Describe your dream trip...',
                                hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (val) => _submitTrip(context),
                            )
                          : GestureDetector(
                              onTap: () {
                                setState(() => _isInputActive = true);
                                _ticker.stop();
                              },
                              child: Row(
                                children: [
                                  Text(
                                    _displayText.isEmpty
                                        ? 'Plan my trip with AI'
                                        : _displayText,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _displayText.isEmpty
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (_displayText.isNotEmpty)
                                    _BlinkingCursor(),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (_isInputActive &&
                            _tripController.text.trim().isNotEmpty) {
                          _submitTrip(context);
                        } else if (!_isInputActive) {
                          setState(() => _isInputActive = true);
                          _ticker.stop();
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_forward,
                            color: Colors.white, size: 16),
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

  // ── Budget Card (fallback) ──
  Widget _buildBudget(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/budget'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [_cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.brandBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No budget data yet',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create a trip to start tracking',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── AI Picks Header ──
  Widget _buildAiPicksHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'AI Picks for You',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => context.go('/explore'),
          child: const Text(
            'See All',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ],
    );
  }

  // ── AI Picks Carousel (dynamic) ──
  Widget _buildAiPicksDynamic(BuildContext context) {
    if (_aiPicksLoading) {
      return SizedBox(
        height: 200,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 170, height: 200,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(16)),
            ),
          )),
        ),
      );
    }

    final picks = _aiPicks ?? [];
    if (picks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: picks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = picks[i];
          return _AiPickCard(
            imageUrl: p.imageUrl,
            title: p.title,
            subtitle: p.subtitle,
            badge: p.matchReason,
            onTap: () => context.push('/ai-chat', extra: 'Tell me about ${p.destination}'),
          );
        },
      ),
    );
  }

  void _submitTrip(BuildContext context) {
    final query = _tripController.text.trim();
    if (query.isNotEmpty) {
      context.push('/ai-chat', extra: query);
    }
  }

  Widget _buildTailoredForYou() {
    final recAsync = ref.watch(aiRecommendationsProvider);
    return recAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        final items = result.structured?.items ?? [];
        if (items.isEmpty && result.recommendation == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.brandBlue),
              SizedBox(width: 6),
              Text('Tailored for You',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            if (result.recommendation != null)
              Text(result.recommendation!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(_emojiToIcon(item.emoji), size: 18, color: AppColors.brandBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.label}: ${item.value}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                            if (item.detail != null)
                              Text(item.detail!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ]),
                  )),
            ],
            if (result.structured?.tip != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.brandBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(result.structured!.tip!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ]),
              ),
            ],
          ],
        );
      },
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

class _AiPickCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  const _AiPickCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
            // Match badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Title + subtitle
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
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

// ── Blinking Cursor ──

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 16,
        margin: const EdgeInsets.only(left: 1),
        color: AppColors.brandBlue,
      ),
    );
  }
}

// ── Quick Action Button ──

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? bgColor;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = bgColor ?? AppColors.brandBlue.withValues(alpha: 0.06);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.brandBlue, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Removed _HomeHeaderDecoPainter (pure white theme)
