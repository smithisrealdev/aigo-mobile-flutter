import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/trip_service.dart';

// ─── Models ───
class _ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final DateTime timestamp;

  _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
  });
}

// ─── Screen ───
class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 140,
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
                      Text('Activity Feed',
                          style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.brandBlue)),
                      const SizedBox(height: 4),
                      const Text('Your recent travel activity', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        tripsAsync.when(
          loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.brandBlue))),
          error: (e, _) => SliverFillRemaining(child: Center(child: Text('Failed to load', style: TextStyle(color: AppColors.textSecondary)))),
          data: (trips) {
            final activities = <_ActivityItem>[];
            for (final trip in trips) {
              activities.add(_ActivityItem(
                title: 'Trip created: ${trip.title}',
                subtitle: trip.destination,
                icon: Icons.flight_takeoff,
                color: AppColors.brandBlue,
                timestamp: DateTime.tryParse(trip.createdAt ?? '') ?? DateTime.now(),
              ));
              if (trip.itineraryData != null) {
                activities.add(_ActivityItem(
                  title: 'Itinerary generated',
                  subtitle: '${trip.title} - ${trip.destination}',
                  icon: Icons.auto_awesome,
                  color: const Color(0xFF8B5CF6),
                  timestamp: DateTime.tryParse(trip.updatedAt ?? trip.createdAt ?? '') ?? DateTime.now(),
                ));
              }
              if (trip.budgetTotal != null && trip.budgetTotal! > 0) {
                activities.add(_ActivityItem(
                  title: 'Budget set: \$${trip.budgetTotal!.toStringAsFixed(0)}',
                  subtitle: trip.title,
                  icon: Icons.account_balance_wallet,
                  color: AppColors.success,
                  timestamp: DateTime.tryParse(trip.updatedAt ?? '') ?? DateTime.now(),
                ));
              }
            }
            activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            if (activities.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history, size: 48, color: AppColors.brandBlue.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('No activity yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                    Text('Start by creating a trip', style: TextStyle(fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                  ]),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => _TimelineItem(item: activities[i], isLast: i == activities.length - 1, isDark: isDark),
                childCount: activities.length,
              )),
            );
          },
        ),
      ]),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _ActivityItem item;
  final bool isLast;
  final bool isDark;
  const _TimelineItem({required this.item, required this.isLast, required this.isDark});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline line + dot
        SizedBox(
          width: 40,
          child: Column(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
            ),
            if (!isLast)
              Expanded(child: Container(width: 2, color: isDark ? AppColors.borderDark : AppColors.border)),
          ]),
        ),
        // Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDarkMode : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: TextStyle(fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                ],
              )),
              Text(_timeAgo(item.timestamp), style: TextStyle(fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
            ]),
          ),
        ),
      ]),
    );
  }
}
