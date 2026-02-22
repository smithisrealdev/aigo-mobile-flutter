import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/plan_card.dart';
import '../widgets/payment_history_list.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/billing_service.dart';
import '../config/supabase_config.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _loggingOut = false;

  final Map<String, bool> _preferences = {
    'Adventure': true,
    'Cultural': false,
    'Beach': true,
    'Budget': false,
    'Luxury': false,
    'Nature': true,
    'Food': true,
    'Nightlife': false,
  };

  String _getUserName() {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return 'Guest';
    final meta = user.userMetadata;
    if (meta != null && meta['full_name'] != null) return meta['full_name'] as String;
    return user.email?.split('@').first ?? 'Guest';
  }

  String _getUserEmail() {
    return SupabaseConfig.client.auth.currentUser?.email ?? 'Not signed in';
  }

  Future<void> _handleLogout() async {
    setState(() => _loggingOut = true);
    try {
      await AuthService.instance.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final sw = MediaQuery.of(context).size.width;
    final tripsAsync = ref.watch(tripsProvider);

    final userName = _getUserName();
    final userEmail = _getUserEmail();

    // Derive stats from trips
    int tripCount = 0;
    int placesCount = 0;
    final countries = <String>{};
    tripsAsync.whenData((trips) {
      tripCount = trips.length;
      for (final t in trips) {
        // Count activities from itinerary data
        if (t.itineraryData != null && t.itineraryData!['days'] is List) {
          for (final day in t.itineraryData!['days'] as List) {
            if (day is Map && day['activities'] is List) {
              placesCount += (day['activities'] as List).length;
            }
          }
        }
        // Count unique countries from destination
        if (t.destination.isNotEmpty) {
          final parts = t.destination.split(',');
          if (parts.length > 1) countries.add(parts.last.trim());
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── Blue header with avatar overlap ──
          SizedBox(
            height: 200 + pad.top,
            width: sw,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2B6FFF), Color(0xFF1A5EFF), Color(0xFF0044E6)],
                        stops: [0.0, 0.4, 1.0],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                  ),
                ),
                CustomPaint(size: Size(sw, 200 + pad.top), painter: _ProfileDecoPainter()),
                Positioned(
                  left: 20, right: 20, top: pad.top + 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Profile', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('Edit', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70)),
                        ]),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0, right: 0, top: pad.top + 60,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const CircleAvatar(
                              radius: 38,
                              backgroundColor: Color(0xFF4D82FF),
                              child: Icon(Icons.person, size: 38, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                              ),
                              child: const Icon(Icons.camera_alt, size: 13, color: AppColors.brandBlue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(userName, style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(userEmail, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white60)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Stats row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      _statItem('$tripCount', 'Trips'),
                      _divider(),
                      _statItem('$placesCount', 'Places'),
                      _divider(),
                      _statItem('${countries.length}', 'Countries'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Plan card
                const PlanCard(),
                const SizedBox(height: 8),

                // Payment History
                _menuItem(Icons.receipt_long_outlined, 'Payment History', onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()));
                }),
                const SizedBox(height: 20),

                // Travel Preferences section
                _sectionCard(
                  title: 'Travel Preferences',
                  subtitle: 'Select your interests (pick 3-5)',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _preferences.entries.map((e) {
                      final selected = e.value;
                      return GestureDetector(
                        onTap: () => setState(() => _preferences[e.key] = !e.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.brandBlue : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? AppColors.brandBlue : Colors.grey.shade200, width: selected ? 1.5 : 1),
                            boxShadow: selected ? [BoxShadow(color: AppColors.brandBlue.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))] : null,
                          ),
                          child: Text(e.key, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppColors.textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Settings section
                _sectionCard(
                  title: 'Settings',
                  child: Column(
                    children: [
                      _settingRow(Icons.notifications_outlined, 'Notifications',
                        trailing: Switch.adaptive(value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v), activeTrackColor: AppColors.brandBlue)),
                      _thinDivider(),
                      _settingRow(Icons.attach_money, 'Currency', trailingText: 'THB'),
                      _thinDivider(),
                      _settingRow(Icons.language, 'Language', trailingText: 'English'),
                      _thinDivider(),
                      _settingRow(Icons.dark_mode_outlined, 'Dark Mode',
                        trailing: Switch.adaptive(value: _darkModeEnabled, onChanged: (v) => setState(() => _darkModeEnabled = v), activeTrackColor: AppColors.brandBlue)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Links section
                _sectionCard(
                  child: Column(
                    children: [
                      _linkRow(Icons.shield_outlined, 'Privacy Policy'),
                      _thinDivider(),
                      _linkRow(Icons.description_outlined, 'Terms of Service'),
                      _thinDivider(),
                      _linkRow(Icons.help_outline, 'Help & Support'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Log out
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loggingOut ? null : _handleLogout,
                    icon: _loggingOut
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.logout, size: 18),
                    label: Text(_loggingOut ? 'Logging out...' : 'Log out', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text('v1.0.0', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey.shade400))),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: Colors.grey.shade200);

  Widget _menuItem(IconData icon, String label, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.brandBlue),
        ),
        title: Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionCard({String? title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary))],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  Widget _settingRow(IconData icon, String label, {Widget? trailing, String? trailingText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          if (trailing != null) trailing,
          if (trailingText != null) ...[
            Text(trailingText, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _linkRow(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary))),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _thinDivider() => Divider(height: 1, thickness: 0.5, color: Colors.grey.shade100);
}

class _ProfileDecoPainter extends CustomPainter {
  static const _orange = Color(0xFFFFB347);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final fill = Paint()..style = PaintingStyle.fill;

    fill.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(sw * 0.85, sh * 0.2), 50, fill);
    canvas.drawCircle(Offset(sw * 0.1, sh * 0.7), 35, fill);

    fill.color = _orange.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(sw * 0.92, sh * 0.35), 4, fill);

    canvas.save();
    canvas.translate(sw * 0.08, sh * 0.3);
    canvas.rotate(math.pi / 5);
    fill.color = Colors.white.withValues(alpha: 0.07);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -7, 14, 14), const Radius.circular(3)), fill);
    canvas.restore();

    fill.color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(sw * 0.7, sh * 0.2), 2.5, fill);
    canvas.drawCircle(Offset(sw * 0.3, sh * 0.85), 2, fill);

    fill.color = Colors.white.withValues(alpha: 0.1);
    for (var i = 0; i < 4; i++) {
      final angle = -0.4 + i * 0.2;
      final x = sw * 0.78 + 30 * math.cos(angle);
      final y = sh * 0.15 + 30 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 1.5, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
