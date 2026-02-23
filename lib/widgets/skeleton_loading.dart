import 'package:flutter/material.dart';

/// Reusable shimmer loading widget for skeleton screens
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFF5F5F5),
              Color(0xFFE8E8E8),
            ],
            stops: [
              _ctrl.value - 0.3,
              _ctrl.value,
              _ctrl.value + 0.3,
            ],
            tileMode: TileMode.clamp,
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcATop,
        child: widget.child,
      ),
    );
  }
}

/// Skeleton placeholder box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton card for trip/destination lists
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 52, height: 52, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 120, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 180, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for horizontal card carousel (AI Picks, Explore)
class SkeletonCarousel extends StatelessWidget {
  final double cardWidth;
  final double cardHeight;
  final int count;

  const SkeletonCarousel({
    super.key,
    this.cardWidth = 170,
    this.cardHeight = 200,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ShimmerLoading(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => SkeletonBox(
            width: cardWidth,
            height: cardHeight,
            borderRadius: 16,
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a full list page (Trips, Explore)
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const SkeletonCard(),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for profile screen
class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const SkeletonBox(width: 80, height: 80, borderRadius: 40),
          const SizedBox(height: 12),
          const SkeletonBox(width: 140, height: 18),
          const SizedBox(height: 8),
          const SkeletonBox(width: 200, height: 14),
          const SizedBox(height: 24),
          ...List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const SkeletonBox(height: 52, borderRadius: 12),
          )),
        ],
      ),
    );
  }
}
