import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _cardShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 10,
    offset: Offset(0, 2),
  );

  final TextEditingController _tripController = TextEditingController();
  bool _isInputActive = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Compact Header with embedded search ──
          _buildHeader(context),

          // ── Scrollable body ──
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brandBlue,
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 1));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting + Style Tags ──
                    Text(
                      '${_greeting()}, Smith',
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
                    const SizedBox(height: 10),
                    _buildStyleTags(),

                    const SizedBox(height: 18),

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
                          onTap: () => context.push('/create-trip'),
                        ),
                        _QuickAction(
                          icon: Icons.map_outlined,
                          label: 'My Trips',
                          bgColor: const Color(0xFFFFB347).withValues(alpha: 0.12),
                          onTap: () => context.push('/trips'),
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
                          onTap: () => context.push('/explore'),
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
                          onTap: () => context.push('/trips'),
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
                    _buildUpcomingTrip(context),

                    const SizedBox(height: 20),

                    // ── Budget Overview ──
                    const Text(
                      'Your Budget',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildBudget(context),

                    const SizedBox(height: 24),

                    // ── AI Picks for You ──
                    _buildAiPicksHeader(context),
                    const SizedBox(height: 4),
                    const Text(
                      'Based on your travel style',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _buildAiPicks(context),

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

  // ── Header: compact blue with embedded search ──
  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2B6FFF), Color(0xFF1A5EFF), Color(0xFF0044E6)],
              stops: [0.0, 0.4, 1.0],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 16),
        child: Column(
          children: [
            // Logo row
            Row(
              children: [
                SvgPicture.asset('assets/images/logo_white.svg', height: 28),
                const Spacer(),
                // Notification bell
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 22),
                      onPressed: () => context.push('/notifications'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
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
    ),
        // Header decorations
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: CustomPaint(
                painter: _HomeHeaderDecoPainter(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Style Tags with label ──
  Widget _buildStyleTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your interests',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _styleTag(Icons.park_outlined, 'Nature'),
            _styleTag(Icons.account_balance_outlined, 'Culture'),
            _styleTag(Icons.restaurant_outlined, 'Local Food'),
          ],
        ),
      ],
    );
  }

  // ── Upcoming Trip Card ──
  Widget _buildUpcomingTrip(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/trips'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [_cardShadow],
          border: Border.all(
              color: AppColors.brandBlue.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl:
                    'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=200&h=200&fit=crop',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trip to Tokyo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mar 15 – Mar 22 · 7 days',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.65,
                      minHeight: 4,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.brandBlue),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '65% planned · 5 of 8 activities',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Budget Card ──
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
                    'Monthly Budget',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '฿15,000 / ฿20,000',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Progress ring
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 0.75,
                    strokeWidth: 3,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.brandBlue),
                  ),
                  const Text(
                    '75%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
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
          onTap: () => context.push('/explore'),
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

  // ── AI Picks Carousel ──
  Widget _buildAiPicks(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _AiPickCard(
            imageUrl:
                'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&h=300&fit=crop',
            title: 'Hidden Kyoto',
            subtitle: 'Nature & temples',
            match: '95% match',
            onTap: () => context.push('/place-detail'),
          ),
          const SizedBox(width: 12),
          _AiPickCard(
            imageUrl:
                'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&h=300&fit=crop',
            title: 'Ubud Culture',
            subtitle: 'Rice fields & art',
            match: '92% match',
          ),
          const SizedBox(width: 12),
          _AiPickCard(
            imageUrl:
                'https://images.unsplash.com/photo-1506665531195-3566af2b4dfa?w=400&h=300&fit=crop',
            title: 'Chiang Mai Slow',
            subtitle: 'Local food & nature',
            match: '89% match',
          ),
        ],
      ),
    );
  }

  // ── Offline Indicator ──
  void _submitTrip(BuildContext context) {
    final query = _tripController.text.trim();
    if (query.isNotEmpty) {
      context.push('/ai-chat', extra: query);
    }
  }

  static Widget _styleTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.brandBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandBlue),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Pick Card ──

class _AiPickCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String match;
  final VoidCallback? onTap;

  const _AiPickCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.match,
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
                      match,
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

// ══════════════════════════════════
// Home header decorations (subtle, non-animated)
// ══════════════════════════════════
class _HomeHeaderDecoPainter extends CustomPainter {
  static const _orange = Color(0xFFFFB347);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final fill = Paint()..style = PaintingStyle.fill;

    // Subtle circles
    fill.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(sw * 0.88, sh * 0.15), 40, fill);
    canvas.drawCircle(Offset(sw * 0.08, sh * 0.75), 30, fill);

    // Orange accent dot
    fill.color = _orange.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(sw * 0.93, sh * 0.4), 4, fill);

    // Floating square
    canvas.save();
    canvas.translate(sw * 0.06, sh * 0.35);
    canvas.rotate(math.pi / 5);
    fill.color = Colors.white.withValues(alpha: 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -6, 12, 12), const Radius.circular(3)),
      fill,
    );
    canvas.restore();

    // Dots
    fill.color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(sw * 0.75, sh * 0.2), 2, fill);
    canvas.drawCircle(Offset(sw * 0.2, sh * 0.85), 2, fill);
    canvas.drawCircle(Offset(sw * 0.85, sh * 0.7), 1.5, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
