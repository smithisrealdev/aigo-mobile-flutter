import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class TravelTipsScreen extends StatelessWidget {
  const TravelTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.blueGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                      const SizedBox(width: 12),
                      Text('Travel Tips', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].asMap().entries.map((e) => Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: e.key == 0 ? Colors.white : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(e.value, style: TextStyle(fontSize: 11, color: e.key == 0 ? AppColors.textSecondary : Colors.white70)),
                              Icon([Icons.wb_sunny, Icons.cloud, Icons.grain, Icons.wb_sunny, Icons.cloud][e.key],
                                size: 22, color: e.key == 0 ? AppColors.warning : Colors.white),
                              Text(['28°', '24°', '22°', '26°', '25°'][e.key],
                                style: TextStyle(fontWeight: FontWeight.w600, color: e.key == 0 ? AppColors.textPrimary : Colors.white)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _tipSection('🗣️ Language', ['Learn basic Japanese greetings: Konnichiwa, Arigatou', 'Download Google Translate offline pack', 'Most tourist areas have English signs']),
                _tipSection('🚃 Transportation', ['Get a 7-day Japan Rail Pass (~\$200)', 'IC cards (Suica/Pasmo) work everywhere', 'Trains are extremely punctual']),
                _tipSection('🍜 Food & Dining', ['Try conveyor belt sushi for budget meals', 'Tipping is not customary in Japan', 'Convenience store food is surprisingly good']),
                _tipSection('🏛️ Culture', ['Remove shoes when entering temples', 'Bow slightly when greeting people', 'Avoid eating while walking']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipSection(String title, List<String> tips) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        children: tips.map((t) => ListTile(
          dense: true,
          leading: const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          title: Text(t, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        )).toList(),
      ),
    );
  }
}
