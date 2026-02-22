import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/reservation_service.dart';
import '../theme/app_colors.dart';

/// Trip reservations widget grouped by day.
class TripReservationsWidget extends ConsumerWidget {
  final String tripId;
  const TripReservationsWidget({super.key, required this.tripId});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'hotel':
        return Icons.hotel;
      case 'flight':
        return Icons.flight;
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      default:
        return Icons.event;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'hotel':
        return AppColors.brandBlue;
      case 'flight':
        return const Color(0xFF8B5CF6);
      case 'restaurant':
        return AppColors.warning;
      case 'transport':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(tripReservationsProvider(tripId));

    return reservationsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Error: $e'),
      data: (reservations) {
        if (reservations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.receipt_long,
                      size: 32, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text('No reservations yet',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }

        // Group by day_index
        final grouped = <int, List<Reservation>>{};
        for (final r in reservations) {
          grouped.putIfAbsent(r.dayIndex ?? 0, () => []).add(r);
        }
        final sortedKeys = grouped.keys.toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final dayIdx in sortedKeys) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Text(
                  dayIdx > 0 ? 'Day $dayIdx' : 'General',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
              ...grouped[dayIdx]!.map((r) => _ReservationCard(
                    reservation: r,
                    icon: _typeIcon(r.type),
                    iconColor: _typeColor(r.type),
                    onDelete: () async {
                      await ReservationService.instance
                          .deleteReservation(r.id);
                      ref.invalidate(tripReservationsProvider(tripId));
                    },
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDelete;

  const _ReservationCard({
    required this.reservation,
    required this.icon,
    required this.iconColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reservation.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (reservation.confirmationNumber != null)
                  Text('Conf: ${reservation.confirmationNumber}',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                if (reservation.checkIn != null)
                  Text(
                    '${reservation.checkIn}${reservation.checkOut != null ? ' → ${reservation.checkOut}' : ''}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (reservation.cost != null)
            Text(
              '${reservation.currency ?? '฿'}${reservation.cost!.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandBlue),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.more_vert,
                size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
