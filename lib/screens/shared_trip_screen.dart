import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/sharing_service.dart';
import '../services/trip_service.dart';

class SharedTripScreen extends ConsumerStatefulWidget {
  final String token;
  const SharedTripScreen({super.key, required this.token});

  @override
  ConsumerState<SharedTripScreen> createState() => _SharedTripScreenState();
}

class _SharedTripScreenState extends ConsumerState<SharedTripScreen> {
  Map<String, dynamic>? _trip;
  bool _loading = true;
  String? _error;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final data = await SharingService.instance.getSharedTrip(widget.token);
      if (mounted) {
        setState(() {
          _trip = data;
          _loading = false;
          if (data == null) _error = 'Trip not found or link expired';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleFollow() async {
    final tripId = _trip?['id'] as String?;
    if (tripId == null) return;
    setState(() => _following = !_following);
    try {
      await TripFollowService.instance.toggleFollow(tripId);
    } catch (_) {
      if (mounted) setState(() => _following = !_following);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.blueBorder, width: 1)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Shared Trip', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brandBlue))
                : _error != null
                    ? Center(child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.textSecondary)))
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final trip = _trip!;
    final title = trip['title'] as String? ?? 'Untitled Trip';
    final destination = trip['destination'] as String? ?? '';
    final startDate = trip['start_date'] as String?;
    final endDate = trip['end_date'] as String?;
    final budgetTotal = (trip['budget_total'] as num?)?.toDouble();
    final budgetCurrency = trip['budget_currency'] as String? ?? 'USD';
    final itinerary = trip['itinerary_data'] as Map<String, dynamic>?;
    final days = itinerary?['days'] as List?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Trip overview card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              if (destination.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on, size: 16, color: AppColors.brandBlue),
                  const SizedBox(width: 4),
                  Text(destination, style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary)),
                ]),
              ],
              if (startDate != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('$startDate${endDate != null ? ' - $endDate' : ''}', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ],
              if (budgetTotal != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('$budgetCurrency ${budgetTotal.toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(_following ? Icons.favorite : Icons.favorite_border, size: 18),
                label: Text(_following ? 'Following' : 'Follow Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _following ? AppColors.success : AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/ai-chat', extra: 'Create a trip similar to $destination'),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Create Similar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandBlue,
                  side: const BorderSide(color: AppColors.brandBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Itinerary
        if (days != null && days.isNotEmpty) ...[
          Text('Itinerary', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...days.asMap().entries.map((entry) {
            final day = entry.value as Map<String, dynamic>?;
            final dayNum = entry.key + 1;
            final activities = day?['activities'] as List? ?? [];
            final dayTitle = day?['title'] as String? ?? 'Day $dayNum';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dayTitle, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  ...activities.map((a) {
                    final act = a as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle, size: 6, color: AppColors.brandBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              act['title'] as String? ?? act['name'] as String? ?? '',
                              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
