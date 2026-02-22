import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  int _selectedFilter = 0;
  final _filters = ['All', 'Upcoming', 'Active', 'Done', 'Drafts'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Brand blue header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2B6FFF), Color(0xFF1A5EFF), Color(0xFF0044E6)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                    Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _TripsHeaderDecoPainter()))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'My Trips',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              Text(
                                'Go places and see the world',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Trip'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.brandBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter chips
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final active = i == _selectedFilter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: active ? AppColors.brandBlue : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: active ? null : Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Trip cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [

            // Card 1 — In Progress
            _TripCard(
              imageUrl: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&h=400&fit=crop',
              badge: _Badge('In Progress', const Color(0xFF10B981)),
              title: 'Kyoto, Japan',
              subtitle: 'Mar 15 – Mar 22, 2026',
              extra: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.65,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.brandBlue),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('5 activities', style: _metaStyle),
                      _dot,
                      Text('~฿15,000', style: _metaStyle),
                      _dot,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AI Generated',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Continue Planning →',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandBlueDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2 — Upcoming
            _TripCard(
              imageUrl: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&h=400&fit=crop',
              badge: _Badge('Upcoming', AppColors.brandBlue),
              title: 'Bali Beach & Culture',
              subtitle: 'Apr 5 – Apr 12, 2026',
            ),
            const SizedBox(height: 16),

            // Card 3 — Draft
            _TripCard(
              imageUrl: 'https://images.unsplash.com/photo-1504829857797-ddff29c27927?w=800&h=400&fit=crop',
              badge: _Badge('Draft', const Color(0xFF9CA3AF)),
              title: 'Iceland Northern Lights',
              subtitle: 'Not scheduled yet',
              extra: const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '✨ AI Draft — tap to continue',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.brandBlue),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card 4 — Completed
            _TripCard(
              imageUrl: 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&h=400&fit=crop',
              badge: _Badge('Completed', const Color(0xFF374151)),
              title: 'Tokyo Golden Route',
              subtitle: 'Jan 10 – Jan 17, 2026',
              extra: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text('4.8', style: _metaStyle.copyWith(fontWeight: FontWeight.w600)),
                  ],
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

final _metaStyle = const TextStyle(fontSize: 12, color: AppColors.textSecondary);
const _dot = Padding(
  padding: EdgeInsets.symmetric(horizontal: 6),
  child: Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
);

class _Badge {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
}

class _TripCard extends StatelessWidget {
  final String imageUrl;
  final _Badge badge;
  final String title;
  final String subtitle;
  final Widget? extra;

  const _TripCard({
    required this.imageUrl,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: AppColors.border,
                    child: const Center(child: Icon(Icons.image, color: AppColors.textSecondary)),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                      stops: [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badge.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                if (extra != null) extra!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsHeaderDecoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final fill = Paint()..style = PaintingStyle.fill;

    fill.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(sw * 0.88, sh * 0.2), 40, fill);
    canvas.drawCircle(Offset(sw * 0.1, sh * 0.8), 30, fill);

    fill.color = const Color(0xFFFFB347).withValues(alpha: 0.3);
    canvas.drawCircle(Offset(sw * 0.92, sh * 0.5), 3.5, fill);

    canvas.save();
    canvas.translate(sw * 0.07, sh * 0.4);
    canvas.rotate(math.pi / 5);
    fill.color = Colors.white.withValues(alpha: 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -5, 10, 10), const Radius.circular(2)),
      fill,
    );
    canvas.restore();

    fill.color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(sw * 0.75, sh * 0.25), 2, fill);
    canvas.drawCircle(Offset(sw * 0.25, sh * 0.75), 1.5, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
