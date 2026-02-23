import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../config/supabase_config.dart';
import '../services/reservation_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<Reservation> _reservations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _loading = false;
          _error = 'Not logged in';
        });
        return;
      }
      final data = await SupabaseConfig.client
          .from('reservations')
          .select()
          .eq('user_id', userId)
          .order('check_in', ascending: true);
      final list =
          (data as List).map((e) => Reservation.fromJson(e)).toList();
      if (mounted) setState(() { _reservations = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Reservation> get _upcoming {
    final now = DateTime.now();
    return _reservations.where((r) {
      final date = DateTime.tryParse(r.checkIn ?? r.createdAt ?? '');
      return date != null && date.isAfter(now);
    }).toList();
  }

  List<Reservation> get _past {
    final now = DateTime.now();
    return _reservations.where((r) {
      final date = DateTime.tryParse(r.checkIn ?? r.createdAt ?? '');
      return date == null || !date.isAfter(now);
    }).toList();
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return Icons.flight;
      case 'hotel':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      default:
        return Icons.confirmation_number;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Bookings', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                      const Spacer(),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _actionButton(Icons.flight, 'Search Flights', () => context.push('/flight-search')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(Icons.hotel, 'Search Hotels', () => context.push('/hotel-search')),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: GoogleFonts.dmSans(color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _loadReservations,
                        child: _reservations.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 100),
                                  Center(
                                    child: Column(children: [
                                      Icon(Icons.luggage, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                                      const SizedBox(height: 16),
                                      Text('No bookings yet', style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textSecondary)),
                                    ]),
                                  ),
                                ],
                              )
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  if (_upcoming.isNotEmpty) ...[
                                    _sectionHeader('Upcoming'),
                                    ..._upcoming.map(_reservationCard),
                                  ],
                                  if (_past.isNotEmpty) ...[
                                    if (_upcoming.isNotEmpty) const SizedBox(height: 24),
                                    _sectionHeader('Past'),
                                    ..._past.map(_reservationCard),
                                  ],
                                ],
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }

  Widget _reservationCard(Reservation r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon(r.type), color: AppColors.brandBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                if (r.checkIn != null)
                  Text(_formatDate(r.checkIn), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                if (r.confirmationNumber != null)
                  Text(r.confirmationNumber!, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (r.status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(r.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                r.status!.substring(0, 1).toUpperCase() + r.status!.substring(1),
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
