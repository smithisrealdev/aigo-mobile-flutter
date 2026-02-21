import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                CachedNetworkImage(imageUrl: 'https://picsum.photos/800/400?random=40', height: 280, width: double.infinity, fit: BoxFit.cover),
                Container(height: 280, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.6)]))),
                Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.maybePop(context)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
                  ]),
                ))),
                Positioned(bottom: 20, left: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                    child: const Text('COMPLETED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 8),
                  Text('Trip to Tokyo', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Text('Mar 15 - 22, 2025', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ])),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('7', 'Days'),
                      _stat('12', 'Places'),
                      _stat('\$1,280', 'Spent'),
                      _stat('48', 'Photos'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Highlights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (_, i) => Container(
                        width: 120, margin: const EdgeInsets.only(right: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(imageUrl: 'https://picsum.photos/200/200?random=${50 + i}', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Rate your trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(i < 4 ? Icons.star : Icons.star_border, color: AppColors.warning, size: 36),
                    )),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share),
                      label: const Text('Share Trip Summary'),
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

  Widget _stat(String value, String label) {
    return Column(children: [
      Text(value, style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}
