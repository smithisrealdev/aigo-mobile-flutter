import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _gearCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _tagFade;
  late Animation<double> _decoFade;

  // Particles
  late List<_Particle> _particles;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();

    // Logo entrance
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoFade = CurvedAnimation(
      parent: _logoCtrl,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );

    // Tagline + deco fade
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tagFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _decoFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    // Spinning gears
    _gearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Generate particles
    _particles = List.generate(18, (_) => _Particle.random(_rand));

    // Sequence: logo first, then tagline after delay
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _fadeCtrl.forward();
    });

    // Navigate
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _gearCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // ── Radial gradient bg (center bright → edges dark) ──
          Positioned.fill(
            child: CustomPaint(
              painter: _RadialBgPainter(),
            ),
          ),

          // ── Decorations + particles (single painter, repaints with gear) ──
          FadeTransition(
            opacity: _decoFade,
            child: AnimatedBuilder(
              animation: _gearCtrl,
              builder: (_, child) => CustomPaint(
                size: Size(sw, sh),
                painter: _SplashDecoPainter(
                  gearValue: _gearCtrl.value,
                  particles: _particles,
                ),
              ),
            ),
          ),

          // ── Center content (logo = static anchor) ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo: scale+fade entrance, then STILL
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: SvgPicture.asset(
                      'assets/images/logo_white.svg',
                      height: 90,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tagline — typewriter fade-in per character
                FadeTransition(
                  opacity: _tagFade,
                  child: _TypewriterText(
                    text: 'Make a journey of discovery',
                    fadeCtrl: _fadeCtrl,
                  ),
                ),
                const SizedBox(height: 40),

                // Spinning gear loader
                FadeTransition(
                  opacity: _tagFade,
                  child: AnimatedBuilder(
                    animation: _gearCtrl,
                    builder: (_, child) => CustomPaint(
                      size: const Size(28, 28),
                      painter: _MiniGearPainter(
                        rotation: _gearCtrl.value * 2 * math.pi,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════
// Typewriter text — each letter fades in sequentially
// ══════════════════════════════════
class _TypewriterText extends StatelessWidget {
  final String text;
  final AnimationController fadeCtrl;

  const _TypewriterText({required this.text, required this.fadeCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fadeCtrl,
      builder: (_, child) {
        final progress = fadeCtrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(text.length, (i) {
            final charStart = i / text.length;
            final charOpacity = ((progress - charStart) * text.length * 0.5).clamp(0.0, 1.0);
            return Text(
              text[i],
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.7 * charOpacity),
                letterSpacing: 0.8,
              ),
            );
          }),
        );
      },
    );
  }
}

// ══════════════════════════════════
// Radial gradient background
// ══════════════════════════════════
class _RadialBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.45);
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (center.dx / size.width) * 2 - 1,
          (center.dy / size.height) * 2 - 1,
        ),
        radius: 0.9,
        colors: const [
          Color(0xFF2B6FFF), // brighter center
          Color(0xFF1A5EFF), // mid
          Color(0xFF0044E6), // darker edges
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════
// Particle data
// ══════════════════════════════════
class _Particle {
  final double x; // 0-1 normalized
  final double startY; // 0-1
  final double speed; // pixels per second (normalized)
  final double size;
  final double opacity;

  _Particle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.size,
    required this.opacity,
  });

  factory _Particle.random(math.Random r) {
    return _Particle(
      x: r.nextDouble(),
      startY: r.nextDouble(),
      speed: 0.02 + r.nextDouble() * 0.04, // slow drift up
      size: 1.5 + r.nextDouble() * 3,
      opacity: 0.08 + r.nextDouble() * 0.18,
    );
  }
}

// ══════════════════════════════════
// Deco + particle painter
// ══════════════════════════════════
class _SplashDecoPainter extends CustomPainter {
  final double gearValue;
  final List<_Particle> particles;

  _SplashDecoPainter({required this.gearValue, required this.particles});

  static const _orange = Color(0xFFFFB347);
  static const _orangeDark = Color(0xFFD4882A);
  static const _blueLight = Color(0xFF4D82FF);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final fill = Paint()..style = PaintingStyle.fill;

    // ── Particles (floating up slowly) ──
    for (final p in particles) {
      final y = ((p.startY - gearValue * p.speed * 8) % 1.2) * sh;
      fill.color = Colors.white.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(p.x * sw, y), p.size, fill);
    }

    // ── Large gear top-right (cropped ~35%, rotating) ──
    canvas.save();
    canvas.translate(sw + 15, -20);
    canvas.rotate(gearValue * 2 * math.pi * 0.3);
    _drawGear(canvas, 0, 0, 62, _orange, _orangeDark);
    canvas.restore();

    // ── Medium gear bottom-left (cropped, rotating opposite) ──
    canvas.save();
    canvas.translate(-20, sh + 15);
    canvas.rotate(-gearValue * 2 * math.pi * 0.3);
    _drawGear(canvas, 0, 0, 50, Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.08));
    canvas.restore();

    // ── Small gear top-left ──
    canvas.save();
    canvas.translate(42, sh * 0.22);
    canvas.rotate(gearValue * 2 * math.pi * 0.2);
    _drawGear(canvas, 0, 0, 18, Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.06));
    canvas.restore();

    // ── Medium orange gear right side ──
    canvas.save();
    canvas.translate(sw - 40, sh * 0.72);
    canvas.rotate(-gearValue * 2 * math.pi * 0.25);
    _drawGear(canvas, 0, 0, 26, _orange.withValues(alpha: 0.6), _orangeDark.withValues(alpha: 0.4));
    canvas.restore();

    // ── Extra small gear center-right ──
    canvas.save();
    canvas.translate(sw - 65, sh * 0.38);
    canvas.rotate(gearValue * 2 * math.pi * 0.15);
    _drawGear(canvas, 0, 0, 14, Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04));
    canvas.restore();

    // ── Floating squares ──
    _drawSquare(canvas, sw * 0.14, sh * 0.14, 18, _blueLight.withValues(alpha: 0.3));
    _drawSquare(canvas, sw * 0.86, sh * 0.33, 14, _orange.withValues(alpha: 0.4));
    _drawSquare(canvas, sw * 0.10, sh * 0.66, 11, Colors.white.withValues(alpha: 0.12));
    _drawSquare(canvas, sw * 0.90, sh * 0.84, 16, _blueLight.withValues(alpha: 0.2));
    _drawSquare(canvas, sw * 0.55, sh * 0.12, 8, _orange.withValues(alpha: 0.2));

    // ── Subtle large circles ──
    fill.color = Colors.white.withValues(alpha: 0.035);
    canvas.drawCircle(Offset(sw * 0.82, sh * 0.10), 90, fill);
    canvas.drawCircle(Offset(sw * 0.12, sh * 0.90), 80, fill);
    canvas.drawCircle(Offset(sw * 0.65, sh * 0.65), 50, fill);

    // ── Dotted arcs ──
    fill.color = Colors.white.withValues(alpha: 0.15);
    for (var i = 0; i < 7; i++) {
      final angle = -0.8 + i * 0.14;
      final x = sw * 0.72 + 55 * math.cos(angle);
      final y = sh * 0.17 + 55 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2.2, fill);
    }
    for (var i = 0; i < 6; i++) {
      final angle = math.pi * 0.3 + i * 0.14;
      final x = sw * 0.28 + 48 * math.cos(angle);
      final y = sh * 0.80 + 48 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2, fill);
    }

    // ── Orange accent dots (larger, more visible) ──
    fill.color = _orange.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(sw * 0.76, sh * 0.54), 7, fill);
    fill.color = _orangeDark.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(sw * 0.76, sh * 0.54), 3.5, fill);

    fill.color = _orange.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(sw * 0.22, sh * 0.40), 5, fill);

    fill.color = _orange.withValues(alpha: 0.3);
    canvas.drawCircle(Offset(sw * 0.60, sh * 0.88), 4, fill);

    // ── White tiny dots ──
    fill.color = Colors.white.withValues(alpha: 0.15);
    canvas.drawCircle(Offset(sw * 0.30, sh * 0.28), 3, fill);
    canvas.drawCircle(Offset(sw * 0.68, sh * 0.76), 2.5, fill);
    canvas.drawCircle(Offset(sw * 0.48, sh * 0.92), 2, fill);
  }

  void _drawGear(Canvas canvas, double x, double y, double r, Color color, Color darkColor) {
    final fill = Paint()..style = PaintingStyle.fill;
    fill.color = darkColor;
    _gearPath(canvas, x + 2, y + 3, r, fill);
    fill.color = color;
    _gearPath(canvas, x, y, r, fill);
    fill.color = darkColor;
    canvas.drawCircle(Offset(x, y), r * 0.28, fill);
    fill.color = Colors.white.withValues(alpha: 0.15);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(x, y), width: r * 1.2, height: r * 1.2),
      -math.pi, math.pi * 0.5, true, fill,
    );
  }

  void _gearPath(Canvas canvas, double x, double y, double r, Paint paint) {
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
      path.lineTo(x + iR * math.cos(a2), y + iR * math.sin(a2));
      path.quadraticBezierTo(
        x + oR * 1.05 * math.cos((a2 + a3) / 2), y + oR * 1.05 * math.sin((a2 + a3) / 2),
        x + oR * math.cos(a3), y + oR * math.sin(a3),
      );
      path.lineTo(x + oR * math.cos(a4), y + oR * math.sin(a4));
      path.quadraticBezierTo(
        x + oR * 1.05 * math.cos((a4 + a5) / 2), y + oR * 1.05 * math.sin((a4 + a5) / 2),
        x + iR * math.cos(a5), y + iR * math.sin(a5),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSquare(Canvas canvas, double x, double y, double sz, Color color) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(math.pi / 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: sz * 2, height: sz * 2),
        Radius.circular(sz * 0.3),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplashDecoPainter old) => true;
}

// ══════════════════════════════════
// Spinning gear loader
// ══════════════════════════════════
class _MiniGearPainter extends CustomPainter {
  final double rotation;
  _MiniGearPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.7);

    const teeth = 8;
    final path = Path();
    for (var i = 0; i < teeth; i++) {
      final a1 = i * 2 * math.pi / teeth;
      final a2 = (i + 0.15) * 2 * math.pi / teeth;
      final a3 = (i + 0.35) * 2 * math.pi / teeth;
      final a4 = (i + 0.65) * 2 * math.pi / teeth;
      final a5 = (i + 0.85) * 2 * math.pi / teeth;
      final oR = r;
      final iR = r * 0.65;
      if (i == 0) path.moveTo(iR * math.cos(a1), iR * math.sin(a1));
      path.lineTo(iR * math.cos(a2), iR * math.sin(a2));
      path.quadraticBezierTo(
        oR * 1.05 * math.cos((a2 + a3) / 2), oR * 1.05 * math.sin((a2 + a3) / 2),
        oR * math.cos(a3), oR * math.sin(a3),
      );
      path.lineTo(oR * math.cos(a4), oR * math.sin(a4));
      path.quadraticBezierTo(
        oR * 1.05 * math.cos((a4 + a5) / 2), oR * 1.05 * math.sin((a4 + a5) / 2),
        iR * math.cos(a5), iR * math.sin(a5),
      );
    }
    path.close();
    canvas.drawPath(path, fill);

    canvas.drawCircle(
      Offset.zero,
      r * 0.25,
      Paint()..color = const Color(0xFF1A5EFF),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniGearPainter old) => old.rotation != rotation;
}
