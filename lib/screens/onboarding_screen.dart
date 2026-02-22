import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  static const _titles = [
    'Plan Your\nAdventure',
    'Discover\nNew Places',
    'Travel\nSmarter',
  ];

  static const _descs = [
    'AI builds your perfect itinerary\nin seconds — just pick a destination.',
    'Curated gems off the beaten path,\npersonalized to your travel style.',
    'Budget tracking, offline maps,\nand smart collaboration tools.',
  ];

  // Page 0 = blue, Page 1 = cream, Page 2 = orange
  static const _bgColors = [AppColors.brandBlue, Color(0xFFF7F5F0), Color(0xFFFF8C42)];
  bool get _isLight => _page == 1;
  bool get _isOrange => _page == 2;
  Color get _navAccent => _isLight ? AppColors.brandBlue : Colors.white;
  Color get _navMuted => _isLight ? const Color(0xFFBBBBBB) : Colors.white.withValues(alpha: 0.2);
  Color get _skipColor => _isLight ? const Color(0xFF999999) : Colors.white.withValues(alpha: 0.5);
  Color get _btnBg => _isLight ? AppColors.brandBlue : Colors.white;
  Color get _btnIcon => _isLight ? Colors.white : (_isOrange ? const Color(0xFFFF8C42) : AppColors.brandBlue);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: _bgColors[_page],
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) {
                setState(() => _page = i);
                _animCtrl.forward(from: 0);
              },
              itemCount: 3,
              itemBuilder: (_, i) {
                final isLightPage = i == 1;
                return Stack(
                  children: [
                    // LARGE illustration — overflows edges
                    Positioned(
                      top: pad.top + 30,
                      left: -sw * 0.18,
                      right: -sw * 0.18,
                      height: sh * 0.58,
                      child: FadeTransition(
                        opacity: _animCtrl,
                        child: CustomPaint(
                          painter: _IsoPainter(page: i, lightBg: isLightPage),
                        ),
                      ),
                    ),
                    // Text
                    Positioned(
                      left: 32,
                      right: 32,
                      bottom: pad.bottom + 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _titles[i],
                            style: GoogleFonts.dmSans(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: isLightPage ? AppColors.brandBlue : Colors.white,
                              height: 1.06,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _descs[i],
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              color: isLightPage ? const Color(0xFF666666) : Colors.white.withValues(alpha: 0.6),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // Logo
            Positioned(
              top: pad.top + 14,
              left: 28,
              child: Opacity(
                opacity: 0.5,
                child: SvgPicture.asset(
                  _isLight ? 'assets/images/logo_blue.svg' : 'assets/images/logo_white.svg',
                  height: 28,
                ),
              ),
            ),
            // Bottom nav
            Positioned(
              left: 0,
              right: 0,
              bottom: pad.bottom + 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _skipColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _next,
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _btnBg,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Transform.rotate(
                            angle: -math.pi / 4,
                            child: Icon(
                              _page < 2 ? Icons.chevron_right : Icons.check_rounded,
                              color: _btnIcon,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Row(
                      children: List.generate(3, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: active ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: active ? _navAccent : _navMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// Large Isometric 3D Illustrations
// Overflow edges, multi-layer, 3D depth
// ═══════════════════════════════════════

class _IsoPainter extends CustomPainter {
  final int page;
  final bool lightBg;
  _IsoPainter({required this.page, this.lightBg = false});

  static const _blue = AppColors.brandBlue;
  static const _blueDark = Color(0xFF0044E6);
  static const _blueLight = Color(0xFF4D82FF);
  static const _bluePale = Color(0xFF80A6FF);
  static const _orange = Color(0xFFFFB347);
  static const _orangeDark = Color(0xFFD4882A);
  static const _white = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    switch (page) {
      case 0: _drawMap(canvas, size); break;
      case 1: _drawGlobe(canvas, size); break;
      case 2: _drawPhone(canvas, size); break;
    }
  }

  // ══════════════════════════════════
  // PAGE 1: Giant isometric map
  // ══════════════════════════════════
  void _drawMap(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // ── 3D Gear top-right (LARGE, cropped at edge ~30%) ──
    _draw3DGear(canvas, cx + 210, cy - 155, 52, _orange, _orangeDark);

    // ── Floating square top-left ──
    _drawFloatSquare(canvas, cx - 155, cy - 120, 22, _blueLight);

    // ── MAP PAPER (large, isometric, with thickness) ──
    canvas.save();
    canvas.translate(cx + 10, cy);
    canvas.rotate(-0.12);

    // Paper thickness (3D side — bottom edge)
    fill.color = const Color(0xFFDDDDDD);
    final sideBottom = Path()
      ..moveTo(-140, 110)
      ..lineTo(140, 130)
      ..lineTo(148, 138)
      ..lineTo(-132, 118)
      ..close();
    canvas.drawPath(sideBottom, fill);

    // Paper thickness (3D side — right edge)
    fill.color = const Color(0xFFCCCCCC);
    final sideRight = Path()
      ..moveTo(140, -110)
      ..lineTo(148, -102)
      ..lineTo(148, 138)
      ..lineTo(140, 130)
      ..close();
    canvas.drawPath(sideRight, fill);

    // Paper front
    fill.color = _white;
    final paper = Path()
      ..moveTo(-140, -100)
      ..lineTo(140, -110)
      ..lineTo(140, 130)
      ..lineTo(-140, 110)
      ..close();
    canvas.drawPath(paper, fill);

    // Paper outline (blue, visible on white)
    stroke.color = _blueLight.withValues(alpha: 0.5);
    stroke.strokeWidth = 2.5;
    canvas.drawPath(paper, stroke);

    // Grid
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = _blueLight.withValues(alpha: 0.12);
    for (var i = -4; i <= 4; i++) {
      final y = i * 26.0;
      canvas.drawLine(Offset(-130, y + 5), Offset(130, y - 5), grid);
    }
    for (var i = -4; i <= 4; i++) {
      final x = i * 32.0;
      canvas.drawLine(Offset(x, -100), Offset(x, 120), grid);
    }

    // ── Dashed route background ──
    stroke.color = _bluePale.withValues(alpha: 0.3);
    stroke.strokeWidth = 2;
    final routeBg = Path()
      ..moveTo(-75, 55)
      ..cubicTo(-40, -15, 20, 45, 70, -40);
    canvas.drawPath(routeBg, stroke);

    // ── Bold route line ──
    stroke.color = _blue;
    stroke.strokeWidth = 5;
    canvas.drawPath(routeBg, stroke);

    // Route dots
    fill.color = _blue.withValues(alpha: 0.4);
    for (var t = 0.25; t < 0.8; t += 0.18) {
      final x = -75 + 145 * t;
      final y = 55 + (-95) * t + math.sin(t * 4) * 25;
      canvas.drawCircle(Offset(x, y), 3, fill);
    }

    canvas.restore();

    // ── 3D PIN start (blue, large) ──
    _draw3DPin(canvas, cx - 65, cy + 40, _blue, _blueDark, 1.5);

    // ── 3D PIN end (orange, larger — focal) ──
    _draw3DPin(canvas, cx + 80, cy - 55, _orange, _orangeDark, 1.8);

    // ── 3D Gear bottom-left (medium) ──
    _draw3DGear(canvas, cx - 155, cy + 140, 34, _white.withValues(alpha: 0.35), _white.withValues(alpha: 0.15));

    // ── Orange dot accent ──
    fill.color = _orange;
    canvas.drawCircle(Offset(cx + 185, cy + 65), 12, fill);
    fill.color = _orangeDark;
    canvas.drawCircle(Offset(cx + 185, cy + 65), 6, fill);

    // ── Small floating square bottom-right ──
    _drawFloatSquare(canvas, cx + 155, cy + 145, 14, _blueLight.withValues(alpha: 0.5));

    // ── Decorative dotted arc (top-left area) ──
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _white.withValues(alpha: 0.2);
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi * 0.6 + i * 0.12;
      final dx2 = cx - 100 + 80 * math.cos(angle);
      final dy2 = cy - 60 + 80 * math.sin(angle);
      canvas.drawCircle(Offset(dx2, dy2), 2.5, dotPaint);
    }

    // ── Tiny circles ──
    fill.color = _white.withValues(alpha: 0.2);
    canvas.drawCircle(Offset(cx - 170, cy - 30), 7, fill);
    canvas.drawCircle(Offset(cx + 170, cy - 80), 5, fill);
    canvas.drawCircle(Offset(cx - 60, cy + 155), 4, fill);
  }

  // ══════════════════════════════════
  // PAGE 2: Giant 3D Globe (on LIGHT bg)
  // ══════════════════════════════════
  void _drawGlobe(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Adaptive colors for light bg
    final subtleColor = lightBg ? _blue.withValues(alpha: 0.08) : _white.withValues(alpha: 0.12);
    final subtleDark = lightBg ? _blue.withValues(alpha: 0.05) : _white.withValues(alpha: 0.08);
    final poleColor = lightBg ? _blue.withValues(alpha: 0.3) : _white.withValues(alpha: 0.5);
    final arcColor = lightBg ? _blue.withValues(alpha: 0.15) : _white.withValues(alpha: 0.35);
    final dotColor = lightBg ? _blue.withValues(alpha: 0.12) : _white.withValues(alpha: 0.18);
    final tinyColor = lightBg ? _blue.withValues(alpha: 0.1) : _white.withValues(alpha: 0.2);
    final gearSubtle = lightBg ? _bluePale.withValues(alpha: 0.35) : _white.withValues(alpha: 0.3);
    final gearSubtleDark = lightBg ? _blue.withValues(alpha: 0.15) : _white.withValues(alpha: 0.12);

    // ── Decorative dashed boundary lines (light bg only) ──
    if (lightBg) {
      final dashed = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _blue.withValues(alpha: 0.06);
      // Horizontal
      canvas.drawLine(Offset(cx - 180, cy - 130), Offset(cx + 180, cy - 130), dashed);
      canvas.drawLine(Offset(cx - 180, cy + 150), Offset(cx + 180, cy + 150), dashed);
      // Vertical
      canvas.drawLine(Offset(cx - 140, cy - 150), Offset(cx - 140, cy + 170), dashed);
      canvas.drawLine(Offset(cx + 140, cy - 150), Offset(cx + 140, cy + 170), dashed);
      // Corner dots
      fill.color = _orange;
      canvas.drawCircle(Offset(cx - 140, cy - 130), 4, fill);
      canvas.drawCircle(Offset(cx + 140, cy - 130), 4, fill);
      fill.color = _blue;
      canvas.drawCircle(Offset(cx - 140, cy + 150), 4, fill);
      canvas.drawCircle(Offset(cx + 140, cy + 150), 4, fill);
    }

    // ── 3D Gear top-right (cropped at edge) ──
    _draw3DGear(canvas, cx + 205, cy - 135, 48, _orange, _orangeDark);

    // ── Floating square left ──
    _drawFloatSquare(canvas, cx - 170, cy - 60, 20, lightBg ? _blue : _blueLight);

    // ── Stand base ──
    fill.color = subtleColor;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 130), width: 110, height: 28),
      fill,
    );
    fill.color = subtleDark;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 134), width: 110, height: 28),
      fill,
    );

    // Stand pole
    stroke.color = poleColor;
    stroke.strokeWidth = 5;
    canvas.drawLine(Offset(cx, cy + 118), Offset(cx, cy + 80), stroke);

    // Stand arc
    stroke.color = arcColor;
    stroke.strokeWidth = 3;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: 210, height: 210),
      0.15,
      math.pi * 0.7,
      false,
      stroke,
    );

    // ── Globe shadow ──
    fill.color = _blueDark.withValues(alpha: 0.2);
    canvas.drawCircle(Offset(cx + 5, cy + 5), 100, fill);

    // ── Globe body ──
    fill.color = _white;
    canvas.drawCircle(Offset(cx, cy - 5), 100, fill);

    // Globe outline (bold)
    stroke.color = _blue;
    stroke.strokeWidth = 3;
    canvas.drawCircle(Offset(cx, cy - 5), 100, stroke);

    // ── Continent shapes (blue) ──
    fill.color = _blue;

    // North America
    final na = Path()
      ..moveTo(cx - 50, cy - 60)
      ..quadraticBezierTo(cx - 65, cy - 40, cx - 55, cy - 20)
      ..quadraticBezierTo(cx - 45, cy - 5, cx - 35, cy - 10)
      ..quadraticBezierTo(cx - 30, cy - 25, cx - 35, cy - 45)
      ..quadraticBezierTo(cx - 40, cy - 60, cx - 50, cy - 60)
      ..close();
    canvas.drawPath(na, fill);

    // South America
    final sa = Path()
      ..moveTo(cx - 30, cy + 5)
      ..quadraticBezierTo(cx - 40, cy + 20, cx - 35, cy + 40)
      ..quadraticBezierTo(cx - 28, cy + 55, cx - 20, cy + 50)
      ..quadraticBezierTo(cx - 15, cy + 35, cx - 18, cy + 15)
      ..quadraticBezierTo(cx - 22, cy + 5, cx - 30, cy + 5)
      ..close();
    canvas.drawPath(sa, fill);

    // Europe + Africa
    final ea = Path()
      ..moveTo(cx + 10, cy - 65)
      ..quadraticBezierTo(cx + 25, cy - 55, cx + 35, cy - 35)
      ..quadraticBezierTo(cx + 40, cy - 15, cx + 30, cy + 10)
      ..quadraticBezierTo(cx + 35, cy + 35, cx + 25, cy + 50)
      ..quadraticBezierTo(cx + 15, cy + 40, cx + 12, cy + 15)
      ..quadraticBezierTo(cx + 8, cy - 10, cx + 12, cy - 40)
      ..quadraticBezierTo(cx + 8, cy - 55, cx + 10, cy - 65)
      ..close();
    canvas.drawPath(ea, fill);

    // Small island
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 55, cy + 5), width: 22, height: 12),
      fill,
    );

    // Latitude lines
    final lat = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _blueLight.withValues(alpha: 0.2);
    for (var i = -2; i <= 2; i++) {
      final y = cy - 5 + i * 28.0;
      final ratio = (i * 28.0).abs() / 100;
      if (ratio >= 1) continue;
      final halfW = 100 * math.cos(math.asin(ratio));
      canvas.drawLine(Offset(cx - halfW, y), Offset(cx + halfW, y), lat);
    }

    // Meridian
    lat.color = _blueLight.withValues(alpha: 0.15);
    canvas.save();
    canvas.translate(cx, cy - 5);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 55, height: 200), lat);
    canvas.restore();

    // ── 3D Pin on globe (orange, large, popping out) ──
    _draw3DPin(canvas, cx + 18, cy - 55, _orange, _orangeDark, 1.8);

    // ── Second pin (blue) ──
    _draw3DPin(canvas, cx - 32, cy + 15, _blueLight, _blueDark, 1.2);

    // ── Orbit arc ──
    stroke.color = lightBg ? _blue.withValues(alpha: 0.12) : _white.withValues(alpha: 0.2);
    stroke.strokeWidth = 2;
    canvas.save();
    canvas.translate(cx, cy - 5);
    canvas.rotate(-0.2);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: 260, height: 90),
      0.2, math.pi * 1.5, false, stroke,
    );
    canvas.restore();

    // Orbit satellite dot
    fill.color = _orange;
    canvas.drawCircle(Offset(cx + 128, cy - 15), 7, fill);
    fill.color = _white;
    canvas.drawCircle(Offset(cx + 128, cy - 15), 3.5, fill);

    // ── 3D Gear bottom-right ──
    _draw3DGear(canvas, cx + 160, cy + 115, 30, _orange, _orangeDark);

    // ── Small gear bottom-left ──
    _draw3DGear(canvas, cx - 155, cy + 110, 22, gearSubtle, gearSubtleDark);

    // ── Floating square bottom ──
    _drawFloatSquare(canvas, cx + 165, cy - 50, 14, lightBg ? _blue.withValues(alpha: 0.15) : _white.withValues(alpha: 0.25));

    // ── Decorative dotted arc ──
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = dotColor;
    for (var i = 0; i < 10; i++) {
      final angle = math.pi * 0.3 + i * 0.1;
      final dx2 = cx + 75 + 60 * math.cos(angle);
      final dy2 = cy + 70 + 60 * math.sin(angle);
      canvas.drawCircle(Offset(dx2, dy2), 2, dotPaint);
    }

    // Tiny dots
    fill.color = tinyColor;
    canvas.drawCircle(Offset(cx - 140, cy - 110), 6, fill);
    canvas.drawCircle(Offset(cx + 150, cy + 60), 5, fill);
    canvas.drawCircle(Offset(cx - 80, cy + 140), 4, fill);
  }

  // ══════════════════════════════════
  // PAGE 3: Giant isometric phone + dashboard
  // ══════════════════════════════════
  void _drawPhone(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // On orange bg: use blue gears instead of orange
    // ── 3D Gear top-right (LARGE, cropped) — BLUE on orange bg ──
    _draw3DGear(canvas, cx + 195, cy - 160, 50, _blue, _blueDark);

    // ── Floating square top-left — white ──
    _drawFloatSquare(canvas, cx - 150, cy - 130, 20, _white.withValues(alpha: 0.5));

    // ── PHONE (large, isometric, with 3D edges) ──
    canvas.save();
    canvas.translate(cx + 5, cy + 10);
    canvas.rotate(-0.1);

    final pW = 175.0; // phone width
    final pH = 260.0; // phone height
    final pR = 26.0;  // corner radius

    // 3D right edge
    fill.color = const Color(0xFF2B2B35);
    final rightEdge = Path()
      ..moveTo(pW / 2, -pH / 2 + pR)
      ..lineTo(pW / 2 + 8, -pH / 2 + pR - 4)
      ..lineTo(pW / 2 + 8, pH / 2 - pR + 4)
      ..lineTo(pW / 2, pH / 2 - pR)
      ..close();
    canvas.drawPath(rightEdge, fill);

    // 3D bottom edge
    fill.color = const Color(0xFF222230);
    final bottomEdge = Path()
      ..moveTo(-pW / 2 + pR, pH / 2)
      ..lineTo(-pW / 2 + pR - 4, pH / 2 + 8)
      ..lineTo(pW / 2 - pR + 4, pH / 2 + 8)
      ..lineTo(pW / 2 - pR, pH / 2)
      ..close();
    canvas.drawPath(bottomEdge, fill);

    // Phone body (dark)
    fill.color = const Color(0xFF1A1A2E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: pW, height: pH),
        Radius.circular(pR),
      ),
      fill,
    );

    // Phone outline
    stroke.color = _white.withValues(alpha: 0.3);
    stroke.strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: pW, height: pH),
        Radius.circular(pR),
      ),
      stroke,
    );

    // Screen
    fill.color = _white;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 2), width: pW - 16, height: pH - 28),
      const Radius.circular(18),
    );
    canvas.drawRRect(screenRect, fill);

    // ── Screen content: Dashboard ──

    // Header
    fill.color = _blue;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        -pW / 2 + 8, -pH / 2 + 14, pW / 2 - 8, -pH / 2 + 56,
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
      ),
      fill,
    );

    // Header text placeholders
    fill.color = _white.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-pW / 2 + 22, -pH / 2 + 24, 55, 7),
        const Radius.circular(3.5),
      ),
      fill,
    );
    fill.color = _white.withValues(alpha: 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-pW / 2 + 22, -pH / 2 + 37, 35, 5),
        const Radius.circular(2.5),
      ),
      fill,
    );

    // ── Bar chart ──
    final bars = [38.0, 58.0, 80.0, 52.0, 68.0, 42.0, 55.0];
    final baseY = 55.0;
    for (var i = 0; i < 7; i++) {
      final isAccent = i == 2;
      fill.color = isAccent ? _blue : _blueLight.withValues(alpha: 0.3 + i * 0.04);
      final x = -55.0 + i * 17;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - bars[i], 12, bars[i]),
          const Radius.circular(3),
        ),
        fill,
      );
      // 3D highlight on accent bar
      if (isAccent) {
        fill.color = _blueLight.withValues(alpha: 0.4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, baseY - bars[i], 12, 10),
            const Radius.circular(3),
          ),
          fill,
        );
      }
    }

    // ── Trend line (orange) ──
    stroke.color = _orange;
    stroke.strokeWidth = 3;
    final trend = Path()
      ..moveTo(-50, 28)
      ..cubicTo(-25, 12, 15, -10, 58, -22);
    canvas.drawPath(trend, stroke);

    // Trend dot
    fill.color = _orange;
    canvas.drawCircle(const Offset(58, -22), 5.5, fill);
    fill.color = _white;
    canvas.drawCircle(const Offset(58, -22), 3, fill);

    // ── Mini cards ──
    fill.color = const Color(0xFFF0F4FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-65, 65, 60, 34),
        const Radius.circular(8),
      ),
      fill,
    );
    fill.color = _blue.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-57, 72, 35, 5),
        const Radius.circular(2.5),
      ),
      fill,
    );
    fill.color = _orange;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-57, 82, 25, 10),
        const Radius.circular(5),
      ),
      fill,
    );

    fill.color = const Color(0xFFF0F4FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 65, 60, 34),
        const Radius.circular(8),
      ),
      fill,
    );
    fill.color = _blue.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 72, 35, 5),
        const Radius.circular(2.5),
      ),
      fill,
    );
    fill.color = _blue;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 82, 25, 10),
        const Radius.circular(5),
      ),
      fill,
    );

    canvas.restore();

    // ── Floating checkmark badge (OUTSIDE phone, 3D) ──
    // Shadow
    fill.color = Colors.black.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(cx + 100, cy - 48), 24, fill);
    // Badge
    fill.color = _white;
    canvas.drawCircle(Offset(cx + 98, cy - 52), 24, fill);
    stroke.color = const Color(0xFFE0E0E0);
    stroke.strokeWidth = 2;
    canvas.drawCircle(Offset(cx + 98, cy - 52), 24, stroke);
    // Check
    final check = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = const Color(0xFF22C55E)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(cx + 87, cy - 52)
        ..lineTo(cx + 95, cy - 44)
        ..lineTo(cx + 110, cy - 62),
      check,
    );

    // ── Floating wifi badge (left of phone) ──
    fill.color = _white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 105, cy + 10), width: 50, height: 50),
        const Radius.circular(14),
      ),
      fill,
    );
    // Wifi arcs
    stroke.color = _blue;
    stroke.strokeWidth = 2.5;
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - 105, cy + 15), width: i * 14.0, height: i * 14.0),
        -math.pi * 0.8, math.pi * 0.6, false, stroke,
      );
    }
    fill.color = _blue;
    canvas.drawCircle(Offset(cx - 105, cy + 15), 3, fill);

    // ── 3D Gear bottom-left — blue on orange bg ──
    _draw3DGear(canvas, cx - 130, cy + 140, 22, _blue.withValues(alpha: 0.4), _blueDark.withValues(alpha: 0.25));

    // ── Small floating square — white ──
    _drawFloatSquare(canvas, cx + 140, cy + 135, 12, _white.withValues(alpha: 0.4));

    // ── Floating plane (top-left) ──
    fill.color = _white.withValues(alpha: 0.25);
    canvas.save();
    canvas.translate(cx - 145, cy - 90);
    canvas.rotate(-0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -5, 30, 10),
        const Radius.circular(5),
      ),
      fill,
    );
    final wing = Path()
      ..moveTo(-4, -5)..lineTo(-12, -18)..lineTo(8, -5)..close();
    canvas.drawPath(wing, fill);
    final tail = Path()
      ..moveTo(-15, -5)..lineTo(-20, -14)..lineTo(-10, -5)..close();
    canvas.drawPath(tail, fill);
    canvas.restore();
  }

  // ══════════════════
  // 3D GEAR (with side face + highlight)
  // ══════════════════
  void _draw3DGear(Canvas canvas, double x, double y, double r, Color color, Color darkColor) {
    final fill = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _white.withValues(alpha: 0.9);

    // 3D offset (side face)
    const dx = 3.0;
    const dy = 4.0;

    // Side face (darker)
    fill.color = darkColor;
    _drawGearPath(canvas, x + dx, y + dy, r, fill);
    _drawGearPath(canvas, x + dx, y + dy, r, outline..color = darkColor.withValues(alpha: 0.5));

    // Front face
    fill.color = color;
    _drawGearPath(canvas, x, y, r, fill);

    // Outline
    outline.color = _white.withValues(alpha: 0.85);
    _drawGearPath(canvas, x, y, r, outline);

    // Highlight (top-left quadrant lighter)
    fill.color = _white.withValues(alpha: 0.2);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(x, y), width: r * 1.2, height: r * 1.2),
      -math.pi, math.pi * 0.5, true, fill,
    );

    // Center hole
    fill.color = darkColor;
    canvas.drawCircle(Offset(x, y), r * 0.28, fill);
    outline.color = _white.withValues(alpha: 0.7);
    outline.strokeWidth = 2;
    canvas.drawCircle(Offset(x, y), r * 0.28, outline);
  }

  void _drawGearPath(Canvas canvas, double x, double y, double r, Paint paint) {
    const teeth = 8;
    final path = Path();
    for (var i = 0; i < teeth; i++) {
      final a1 = i * 2 * math.pi / teeth;
      final a2 = (i + 0.15) * 2 * math.pi / teeth;
      final a3 = (i + 0.35) * 2 * math.pi / teeth;
      final a4 = (i + 0.65) * 2 * math.pi / teeth;
      final a5 = (i + 0.85) * 2 * math.pi / teeth;

      final oR = r;
      final iR = r * 0.7;

      if (i == 0) path.moveTo(x + iR * math.cos(a1), y + iR * math.sin(a1));
      // Transition to tooth (rounded via quadratic)
      path.lineTo(x + iR * math.cos(a2), y + iR * math.sin(a2));
      // Tooth outer edge (wider, flatter top)
      path.quadraticBezierTo(
        x + oR * 1.05 * math.cos((a2 + a3) / 2), y + oR * 1.05 * math.sin((a2 + a3) / 2),
        x + oR * math.cos(a3), y + oR * math.sin(a3),
      );
      // Flat tooth top
      path.lineTo(x + oR * math.cos(a4), y + oR * math.sin(a4));
      // Transition back down (rounded)
      path.quadraticBezierTo(
        x + oR * 1.05 * math.cos((a4 + a5) / 2), y + oR * 1.05 * math.sin((a4 + a5) / 2),
        x + iR * math.cos(a5), y + iR * math.sin(a5),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ══════════════════
  // 3D PIN (with highlight + shadow)
  // ══════════════════
  void _draw3DPin(Canvas canvas, double x, double y, Color color, Color darkColor, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);

    final fill = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _white;

    // Shadow
    fill.color = Colors.black.withValues(alpha: 0.12);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(2, 18), width: 22, height: 9),
      fill,
    );

    // Pin body
    fill.color = color;
    final pin = Path()
      ..moveTo(0, 16)
      ..quadraticBezierTo(-15, -4, -15, -13)
      ..arcToPoint(const Offset(15, -13), radius: const Radius.circular(15))
      ..quadraticBezierTo(15, -4, 0, 16)
      ..close();
    canvas.drawPath(pin, fill);
    canvas.drawPath(pin, outline);

    // 3D highlight (left half lighter)
    fill.color = _white.withValues(alpha: 0.25);
    final hl = Path()
      ..moveTo(0, 16)
      ..quadraticBezierTo(-15, -4, -15, -13)
      ..arcToPoint(const Offset(0, -20), radius: const Radius.circular(15))
      ..lineTo(0, 16)
      ..close();
    canvas.drawPath(hl, fill);

    // Inner circle
    fill.color = _white;
    canvas.drawCircle(const Offset(0, -11), 6.5, fill);
    canvas.drawCircle(const Offset(0, -11), 6.5, outline);

    // Inner dot
    fill.color = darkColor;
    canvas.drawCircle(const Offset(0, -11), 3.5, fill);

    canvas.restore();
  }

  // ══════════════════
  // Floating rotated square
  // ══════════════════
  void _drawFloatSquare(Canvas canvas, double x, double y, double sz, Color color) {
    final fill = Paint()..style = PaintingStyle.fill..color = color;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(math.pi / 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: sz * 2, height: sz * 2),
        Radius.circular(sz * 0.3),
      ),
      fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IsoPainter old) => old.page != page || old.lightBg != lightBg;
}
