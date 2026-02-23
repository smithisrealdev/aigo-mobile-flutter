import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/trip_service.dart';

class DashboardStatsScreen extends ConsumerWidget {
  const DashboardStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text('Travel Stats',
                        style: GoogleFonts.dmSans(
                            fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
                  ]),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: tripsAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e'))),
              data: (trips) {
                final totalTrips = trips.length;
                final destinations = trips
                    .map((t) => t.destination)
                    .where((d) => d.isNotEmpty)
                    .toSet();
                final countries = destinations
                    .map((d) => d.split(',').last.trim())
                    .toSet();

                double totalBudget = 0;
                for (final t in trips) {
                  if (t.budgetTotal != null) totalBudget += t.budgetTotal!;
                }

                final categories = <String, int>{};
                for (final t in trips) {
                  final cat = t.category ?? 'general';
                  categories[cat] = (categories[cat] ?? 0) + 1;
                }

                return SliverList(
                  delegate: SliverChildListDelegate([
                    Row(children: [
                      Expanded(child: _statCard('Trips', '$totalTrips',
                          Icons.flight_takeoff, AppColors.brandBlue, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Destinations', '${destinations.length}',
                          Icons.place, AppColors.success, isDark)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _statCard('Countries', '${countries.length}',
                          Icons.public, const Color(0xFF8B5CF6), isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Budget',
                          '\$${totalBudget.toStringAsFixed(0)}',
                          Icons.savings, AppColors.warning, isDark)),
                    ]),
                    const SizedBox(height: 24),
                    Text('Travel Style',
                        style: GoogleFonts.dmSans(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    ...categories.entries.map((e) => _categoryBar(
                        e.key, e.value, totalTrips, isDark)),
                    const SizedBox(height: 24),
                    Text('Destinations Visited',
                        style: GoogleFonts.dmSans(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: destinations.map((d) => Chip(
                        avatar: const Icon(Icons.place, size: 16, color: AppColors.brandBlue),
                        label: Text(d, style: const TextStyle(fontSize: 12)),
                        backgroundColor: isDark ? AppColors.cardDarkMode : Colors.white,
                        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                      )).toList(),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statCard(String label, String value, IconData icon,
      Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkMode : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.dmSans(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
        ],
      ),
    );
  }

  static Widget _categoryBar(String category, int count, int total, bool isDark) {
    final pct = total > 0 ? count / total : 0.0;
    final colors = {
      'nature': AppColors.success,
      'culture': const Color(0xFF8B5CF6),
      'food': AppColors.warning,
      'adventure': AppColors.error,
      'beach': AppColors.brandBlue,
      'city': AppColors.brandBlueDark,
    };
    final color = colors[category.toLowerCase()] ?? AppColors.brandBluePale;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category[0].toUpperCase() + category.substring(1),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
              Text('$count trips',
                  style: TextStyle(fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: isDark ? AppColors.borderDark : AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
