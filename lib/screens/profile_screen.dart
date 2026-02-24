import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/plan_card.dart';
import '../widgets/payment_history_list.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/billing_service.dart';
import '../services/rate_limit_service.dart';
import '../services/saved_search_service.dart';
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Fixed header ──
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: pad.top + 12, left: 20, right: 20, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(24)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_outlined, size: 14, color: AppColors.brandBlue),
                    const SizedBox(width: 4),
                    Text('Edit', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.brandBlue)),
                  ]),
                ),
              ],
            ),
          ),

          // ── Scrollable content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // Avatar + name
                Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFFF3F4F6),
                            child: const Icon(Icons.person, size: 38, color: Color(0xFF9CA3AF)),
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
                    Text(userName, style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(userEmail, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats row
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Row(children: [
                          const Icon(Icons.bar_chart, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('STATS', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Plan card
                const PlanCard(),
                const SizedBox(height: 8),

                // AI Quota display
                _buildAiQuotaCard(),
                const SizedBox(height: 8),

                // Subscription
                _menuItem(Icons.workspace_premium_outlined, 'Subscription', onTap: () => context.push('/pricing')),
                const SizedBox(height: 8),

                // Account Settings
                _menuItem(Icons.settings_outlined, 'Account Settings', onTap: () => context.push('/account-settings')),
                const SizedBox(height: 8),

                // Saved Places
                _menuItem(Icons.bookmark_outline, 'Saved Places', onTap: () => context.push('/saved-places')),
                const SizedBox(height: 8),

                // My Bookings
                _menuItem(Icons.luggage_outlined, 'My Bookings', onTap: () => context.push('/booking')),
                const SizedBox(height: 8),

                // My Reviews
                _menuItem(Icons.rate_review_outlined, 'My Reviews', onTap: () => context.push('/reviews', extra: <String, String?>{'title': 'My Reviews'})),
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
                        trailing: Switch.adaptive(value: Theme.of(context).brightness == Brightness.dark, onChanged: (v) => ref.read(themeModeProvider.notifier).setMode(v ? ThemeMode.dark : ThemeMode.light), activeTrackColor: AppColors.brandBlue)),
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

                // Saved Flight Searches
                _buildSavedFlightSearches(),

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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

  Widget _buildAiQuotaCard() {
    final quotaAsync = ref.watch(aiQuotaProvider);
    return quotaAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (quota) {
        final currentUsage = quota['current_usage'] as int? ?? 0;
        final monthlyLimit = quota['monthly_limit'] as int? ?? 10;
        final remaining = quota['remaining'] as int? ?? 0;
        final tier = quota['tier'] as String? ?? 'free';
        final pct = monthlyLimit > 0 ? (currentUsage / monthlyLimit).clamp(0.0, 1.0) : 0.0;
        final barColor = pct < 0.6 ? AppColors.success : (pct < 0.85 ? AppColors.warning : AppColors.error);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('AI USAGE', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: AppColors.brandBlue),
                  const SizedBox(width: 8),
                  Text('AI Usage', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(tier.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Used $currentUsage of $monthlyLimit requests', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(6, (i) {
                  final filledSegments = (pct * 6).round().clamp(0, 6);
                  return Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(right: i < 5 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: i < filledSegments ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text('$remaining remaining this month', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          ),
          ],
          ),
        );
      },
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _sectionCard({String? title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(children: [
                const Icon(Icons.tune, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(title.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
              ]),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
            ),
            child: child,
          ),
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

  Widget _buildSavedFlightSearches() {
    final searchesAsync = ref.watch(savedFlightSearchesProvider);
    return searchesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (searches) {
        if (searches.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved Flight Searches',
                style: GoogleFonts.dmSans(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...searches.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(children: [
                    const Icon(Icons.flight, size: 18, color: AppColors.brandBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '${s.originName ?? s.originCode} → ${s.destinationName ?? s.destinationCode}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: () async {
                        await SavedSearchService.instance.deleteSearch(s.id);
                        ref.invalidate(savedFlightSearchesProvider);
                      },
                    ),
                  ]),
                )),
          ],
        );
      },
    );
  }
}
