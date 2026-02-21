import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class MapViewScreen extends StatelessWidget {
  const MapViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map placeholder
          Container(
            color: const Color(0xFFE8EDF2),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('Map View', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Integrate Google Maps here', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.3), fontSize: 13)),
                ],
              ),
            ),
          ),
          // Colored pins
          ...List.generate(5, (i) => Positioned(
            left: 60.0 + i * 60, top: 200.0 + (i % 3) * 80,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: [AppColors.brandBlue, AppColors.error, AppColors.success, AppColors.warning, Colors.purple][i],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
              ),
              child: Icon([Icons.restaurant, Icons.temple_buddhist, Icons.park, Icons.hotel, Icons.shopping_bag][i], color: Colors.white, size: 16),
            ),
          )),
          // Top bar
          Positioned(top: 0, left: 0, right: 0, child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white, Colors.white.withValues(alpha: 0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Row(children: [
                  GestureDetector(onTap: () => Navigator.maybePop(context), child: Container(
                    width: 40, height: 40, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18),
                  )),
                  const SizedBox(width: 12),
                  Text('Map View', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          )),
          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.2, minChildSize: 0.1, maxChildSize: 0.5,
            builder: (_, controller) => Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: ListView(controller: controller, padding: const EdgeInsets.all(20), children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Senso-ji Temple', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Row(children: [
                  Icon(Icons.star, color: AppColors.warning, size: 16),
                  SizedBox(width: 4),
                  Text('4.8', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Text('• Temple • Asakusa', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                const Text("Tokyo's oldest temple, dating back to 645 AD. Beautiful architecture and traditional market street.", style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
