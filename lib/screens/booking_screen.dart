import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

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
                  Text('Bookings', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Confirmed', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _bookingCard(
                  icon: Icons.flight,
                  title: 'Flight — Tokyo',
                  subtitle: 'ANA NH203 • Economy',
                  details: [
                    'Departure: Mar 15, 8:30 AM (BKK)',
                    'Arrival: Mar 15, 4:45 PM (NRT)',
                    'Duration: 6h 15m',
                  ],
                  hasQR: true,
                ),
                const SizedBox(height: 16),
                _bookingCard(
                  icon: Icons.flight_land,
                  title: 'Return Flight',
                  subtitle: 'ANA NH204 • Economy',
                  details: [
                    'Departure: Mar 22, 10:00 AM (NRT)',
                    'Arrival: Mar 22, 3:30 PM (BKK)',
                  ],
                  hasQR: false,
                ),
                const SizedBox(height: 16),
                _bookingCard(
                  icon: Icons.hotel,
                  title: 'Hotel Gracery Shinjuku',
                  subtitle: 'Deluxe Twin • 7 nights',
                  details: [
                    'Check-in: Mar 15, 3:00 PM',
                    'Check-out: Mar 22, 11:00 AM',
                    'Confirmation: HG-28491',
                  ],
                  hasQR: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard({required IconData icon, required String title, required String subtitle, required List<String> details, required bool hasQR}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.brandBlue, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          ...details.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.circle, size: 6, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(d, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
          )),
          if (hasQR) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.qr_code_2, size: 80, color: AppColors.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
