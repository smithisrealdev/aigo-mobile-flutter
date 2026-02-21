import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_chip.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  children: [
                    Row(children: [
                      Text('Profile', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: () {}),
                    ]),
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: ClipOval(child: CachedNetworkImage(imageUrl: 'https://picsum.photos/200/200?random=60', width: 80, height: 80, fit: BoxFit.cover)),
                    ),
                    const SizedBox(height: 12),
                    Text('Apichet Smith', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Text('Explorer since 2024', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Travel Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: const [
                  QuickChip(label: '🏖️ Beach', selected: true),
                  QuickChip(label: '🍜 Food', selected: true),
                  QuickChip(label: '🏛️ Culture'),
                  QuickChip(label: '🏔️ Adventure', selected: true),
                  QuickChip(label: '🛍️ Shopping'),
                ]),
                const SizedBox(height: 24),
                const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _toggle('Trip Reminders', true),
                _toggle('Deal Alerts', true),
                _toggle('Weather Updates', false),
                _toggle('AI Suggestions', true),
                const SizedBox(height: 24),
                _settingsItem(Icons.bookmark_outline, 'Saved Places'),
                _settingsItem(Icons.credit_card, 'Payment Methods'),
                _settingsItem(Icons.help_outline, 'Help & Support'),
                _settingsItem(Icons.info_outline, 'About'),
                const SizedBox(height: 16),
                _settingsItem(Icons.logout, 'Sign Out', isDestructive: true),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Switch(value: value, onChanged: (_) {}, activeColor: AppColors.brandBlue),
      ]),
    );
  }

  Widget _settingsItem(IconData icon, String label, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.textSecondary),
        title: Text(label, style: TextStyle(color: isDestructive ? AppColors.error : AppColors.textPrimary, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
