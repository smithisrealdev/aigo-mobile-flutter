import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Brand decorative icon — person walking with luggage (AiGo traveler motif).
class BrandTravelerIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const BrandTravelerIcon({super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brandBlue;
    final iconSize = size * 0.55;
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_walk, size: iconSize, color: c),
          SizedBox(width: size * 0.02),
          Icon(Icons.luggage, size: iconSize * 0.75, color: c),
        ],
      ),
    );
  }
}
