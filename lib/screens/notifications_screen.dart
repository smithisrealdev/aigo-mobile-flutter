import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
                child: Row(children: [
                  GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Text('Notifications', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('Clear all', style: TextStyle(color: Colors.white70, fontSize: 13))),
                ]),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionTitle('Today'),
                _notifCard(Icons.flight, AppColors.brandBlue, 'Flight Reminder', 'Your flight to Tokyo departs in 2 hours', '2h ago'),
                _notifCard(Icons.local_offer, AppColors.error, 'Flash Deal 🔥', '40% off Bali hotels — ends tonight!', '4h ago'),
                const SizedBox(height: 20),
                _sectionTitle('Yesterday'),
                _notifCard(Icons.cloud, AppColors.warning, 'Weather Alert', 'Rain expected in Tokyo tomorrow. Pack an umbrella!', '1d ago'),
                _notifCard(Icons.luggage, AppColors.success, 'Trip Update', 'Your Tokyo itinerary has been optimized by AI', '1d ago'),
                _notifCard(Icons.star, AppColors.warning, 'Review Request', 'How was your visit to Senso-ji Temple?', '1d ago'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
  );

  Widget _notifCard(IconData icon, Color color, String title, String body, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ])),
        ],
      ),
    );
  }
}
