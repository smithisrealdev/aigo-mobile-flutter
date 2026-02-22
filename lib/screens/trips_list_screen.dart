import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../services/trip_service.dart';
import '../services/auth_service.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';

class TripsListScreen extends ConsumerStatefulWidget {
  const TripsListScreen({super.key});

  @override
  ConsumerState<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends ConsumerState<TripsListScreen> {
  int _selectedFilter = 0;
  final _filters = ['All', 'Upcoming', 'Active', 'Done', 'Drafts'];

  List<Trip> _filterTrips(List<Trip> trips) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 1: // Upcoming
        return trips.where((t) {
          if (t.startDate == null) return false;
          final start = DateTime.tryParse(t.startDate!);
          return start != null && start.isAfter(now);
        }).toList();
      case 2: // Active
        return trips.where((t) {
          if (t.startDate == null || t.endDate == null) return false;
          final start = DateTime.tryParse(t.startDate!);
          final end = DateTime.tryParse(t.endDate!);
          return start != null && end != null && now.isAfter(start) && now.isBefore(end);
        }).toList();
      case 3: // Done
        return trips.where((t) {
          if (t.endDate == null) return false;
          final end = DateTime.tryParse(t.endDate!);
          return end != null && now.isAfter(end);
        }).toList();
      case 4: // Drafts
        return trips.where((t) => t.status == 'draft' || t.startDate == null).toList();
      default:
        return trips;
    }
  }

  String _formatDateRange(Trip trip) {
    if (trip.startDate == null) return 'Not scheduled yet';
    final start = DateTime.tryParse(trip.startDate!);
    final end = trip.endDate != null ? DateTime.tryParse(trip.endDate!) : null;
    if (start == null) return 'Not scheduled yet';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final s = '${months[start.month - 1]} ${start.day}';
    if (end != null) return '$s – ${months[end.month - 1]} ${end.day}, ${end.year}';
    return '$s, ${start.year}';
  }

  _Badge _getBadge(Trip trip) {
    final now = DateTime.now();
    if (trip.status == 'draft' || trip.startDate == null) return const _Badge('Draft', Color(0xFF9CA3AF));
    final start = DateTime.tryParse(trip.startDate!);
    final end = trip.endDate != null ? DateTime.tryParse(trip.endDate!) : null;
    if (end != null && now.isAfter(end)) return const _Badge('Completed', Color(0xFF374151));
    if (start != null && end != null && now.isAfter(start) && now.isBefore(end)) return const _Badge('In Progress', Color(0xFF10B981));
    return const _Badge('Upcoming', AppColors.brandBlue);
  }

  void _showCreateTripSheet(BuildContext context) {
    final destController = TextEditingController();
    final budgetController = TextEditingController();
    String currency = 'USD';
    String style = 'balanced';
    DateTime? startDate;
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Create New Trip', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                TextField(
                  controller: destController,
                  decoration: InputDecoration(
                    labelText: 'Destination',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                          if (d != null) setSheetState(() => startDate = d);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(startDate != null ? '${startDate!.month}/${startDate!.day}/${startDate!.year}' : 'Select', style: GoogleFonts.dmSans(fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: ctx, firstDate: startDate ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                          if (d != null) setSheetState(() => endDate = d);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(endDate != null ? '${endDate!.month}/${endDate!.day}/${endDate!.year}' : 'Select', style: GoogleFonts.dmSans(fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: budgetController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Budget',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        value: currency,
                        items: ['USD', 'EUR', 'GBP', 'THB', 'JPY'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => currency = v ?? 'USD',
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: style,
                  items: ['budget', 'balanced', 'comfort', 'luxury'].map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                  onChanged: (v) => style = v ?? 'balanced',
                  decoration: InputDecoration(
                    labelText: 'Travel Style',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final dest = destController.text.trim();
                      if (dest.isEmpty) return;
                      final uid = SupabaseConfig.client.auth.currentUser?.id;
                      if (uid == null) return;
                      final trip = Trip(
                        id: '',
                        userId: uid,
                        title: dest,
                        destination: dest,
                        status: 'draft',
                        startDate: startDate?.toIso8601String(),
                        endDate: endDate?.toIso8601String(),
                        budgetTotal: double.tryParse(budgetController.text),
                        budgetCurrency: currency,
                      );
                      try {
                        await TripService.instance.createTrip(trip);
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(tripsProvider);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Create Trip', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTripSheet(context),
        backgroundColor: AppColors.brandBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Brand blue header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2B6FFF), Color(0xFF1A5EFF), Color(0xFF0044E6)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _TripsHeaderDecoPainter()))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('My Trips', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                              Text('Go places and see the world', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/ai-chat'),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Trip'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.brandBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter chips
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final active = i == _selectedFilter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: active ? AppColors.brandBlue : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: active ? null : Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Trip cards
          Expanded(
            child: tripsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandBlue)),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Failed to load trips', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(tripsProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ]),
              ),
              data: (trips) {
                final filtered = _filterTrips(trips);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.flight_takeoff, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No trips found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Create your first trip with AI!', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/ai-chat'),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Plan a Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ]),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.brandBlue,
                  onRefresh: () async => ref.invalidate(tripsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) {
                      final trip = filtered[i];
                      final badge = _getBadge(trip);
                      final progress = (trip.budgetTotal != null && trip.budgetTotal! > 0 && trip.budgetSpent != null)
                          ? (trip.budgetSpent! / trip.budgetTotal!).clamp(0.0, 1.0)
                          : 0.0;

                      return Dismissible(
                        key: ValueKey(trip.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Trip'),
                              content: Text('Delete "${trip.title}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          try {
                            await TripService.instance.deleteTrip(trip.id);
                            ref.invalidate(tripsProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                            }
                          }
                        },
                        child: GestureDetector(
                          onTap: () => context.push('/itinerary', extra: trip),
                          child: _TripCard(
                            imageUrl: trip.coverImage ?? 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&h=400&fit=crop',
                            badge: badge,
                            title: trip.title,
                            subtitle: _formatDateRange(trip),
                            extra: progress > 0
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 6,
                                          backgroundColor: AppColors.border,
                                          valueColor: const AlwaysStoppedAnimation(AppColors.brandBlue),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(children: [
                                        Text('${(progress * 100).toInt()}% budget used', style: _metaStyle),
                                        if (trip.itineraryData != null) ...[
                                          _dot,
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.brandBlue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('AI Generated', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                                          ),
                                        ],
                                      ]),
                                    ],
                                  )
                                : trip.status == 'draft'
                                    ? const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text('✨ AI Draft — tap to continue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.brandBlue)),
                                      )
                                    : null,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final _metaStyle = const TextStyle(fontSize: 12, color: AppColors.textSecondary);
const _dot = Padding(
  padding: EdgeInsets.symmetric(horizontal: 6),
  child: Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
);

class _Badge {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
}

class _TripCard extends StatelessWidget {
  final String imageUrl;
  final _Badge badge;
  final String title;
  final String subtitle;
  final Widget? extra;

  const _TripCard({
    required this.imageUrl,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(height: 140, color: AppColors.border, child: const Center(child: Icon(Icons.image, color: AppColors.textSecondary))),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badge.color, borderRadius: BorderRadius.circular(8)),
                  child: Text(badge.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    child: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                if (extra != null) extra!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsHeaderDecoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final fill = Paint()..style = PaintingStyle.fill;

    fill.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(sw * 0.88, sh * 0.2), 40, fill);
    canvas.drawCircle(Offset(sw * 0.1, sh * 0.8), 30, fill);

    fill.color = const Color(0xFFFFB347).withValues(alpha: 0.3);
    canvas.drawCircle(Offset(sw * 0.92, sh * 0.5), 3.5, fill);

    canvas.save();
    canvas.translate(sw * 0.07, sh * 0.4);
    canvas.rotate(math.pi / 5);
    fill.color = Colors.white.withValues(alpha: 0.06);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -5, 10, 10), const Radius.circular(2)), fill);
    canvas.restore();

    fill.color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(sw * 0.75, sh * 0.25), 2, fill);
    canvas.drawCircle(Offset(sw * 0.25, sh * 0.75), 1.5, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
