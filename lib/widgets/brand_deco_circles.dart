import 'package:flutter/material.dart';

/// Decorative circles for brand identity backgrounds (Looka geometric style).
class BrandDecoCircles extends StatelessWidget {
  final double width;
  final double height;

  const BrandDecoCircles({super.key, this.width = 400, this.height = 300});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned(right: -40, top: -30, child: _circle(140)),
            Positioned(left: -20, bottom: -50, child: _circle(100)),
            Positioned(right: 60, bottom: 20, child: _circle(60)),
            Positioned(left: 40, top: 20, child: _circle(40)),
            Positioned(right: 20, top: 60, child: _circle(24)),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}
