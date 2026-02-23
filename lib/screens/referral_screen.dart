import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';

// ─── Providers ───
final _referralCodeProvider = StateProvider<String>((ref) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rng = math.Random();
  return 'AIGO-${List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join()}';
});

final _referralCountProvider = StateProvider<int>((ref) => 3);
final _referralRewardsProvider = StateProvider<int>((ref) => 15);

// ─── Screen ───
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = ref.watch(_referralCodeProvider);
    final count = ref.watch(_referralCountProvider);
    final rewards = ref.watch(_referralRewardsProvider);
    final link = 'https://aigo.travel/ref/$code';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: AppColors.brandBlue,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.blueBorder, width: 1))),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Refer & Earn',
                          style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.brandBlue)),
                      const SizedBox(height: 4),
                      const Text('Share AiGo with friends and earn rewards',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Stats row
            Row(children: [
              Expanded(child: _statCard('Referrals', count.toString(), Icons.people, AppColors.brandBlue, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Rewards', '\$$rewards', Icons.card_giftcard, AppColors.success, isDark)),
            ]),
            const SizedBox(height: 20),

            // Referral code card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkMode : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your Referral Code', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandBlue.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(code,
                        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.brandBlue, letterSpacing: 2))),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied'), duration: Duration(seconds: 1)));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.copy, color: Colors.white, size: 18),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                // Share link
                Text('Share Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDarkMode : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(link,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis)),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 1)));
                      },
                      child: const Icon(Icons.copy, size: 18, color: AppColors.brandBlue),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: 'Join me on AiGo! Use my referral code $code or sign up at $link'));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard. Share it with friends!'), duration: Duration(seconds: 2)));
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share with Friends', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // How it works
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDarkMode : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('How It Works', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                const SizedBox(height: 14),
                _stepRow(1, 'Share your code', 'Send your referral code to friends', Icons.send, isDark),
                _stepRow(2, 'Friends sign up', 'They create an account using your code', Icons.person_add, isDark),
                _stepRow(3, 'Earn rewards', 'Get \$5 credit for each successful referral', Icons.card_giftcard, isDark),
              ]),
            ),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, bool isDark) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
        ]),
      );

  Widget _stepRow(int step, String title, String desc, IconData icon, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.brandBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('$step', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.brandBlue))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
            Text(desc, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          ])),
          Icon(icon, size: 20, color: AppColors.brandBlue.withOpacity(0.5)),
        ]),
      );
}
