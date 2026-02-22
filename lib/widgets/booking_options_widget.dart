import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/booking_service.dart';
import '../theme/app_colors.dart';

/// Shows booking options (Booking.com, Klook, Viator, etc.) for a place.
class BookingOptionsWidget extends ConsumerWidget {
  final String placeName;
  final String? placeAddress;

  const BookingOptionsWidget({
    super.key,
    required this.placeName,
    this.placeAddress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(
      bookingSearchProvider((name: placeName, address: placeAddress)),
    );

    return bookingsAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.brandBlue)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (bookings) {
        if (bookings.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Book & Tickets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...bookings.map((b) => _BookingCard(booking: b)),
          ],
        );
      },
    );
  }
}

/// Compact booking button for itinerary place cards.
class BookingChip extends StatelessWidget {
  final String placeName;

  const BookingChip({super.key, required this.placeName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final encoded = Uri.encodeComponent(placeName);
        launchUrl(
          Uri.parse('https://www.klook.com/search/?query=$encoded'),
          mode: LaunchMode.externalApplication,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.brandBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined,
              size: 13, color: AppColors.brandBlue),
          SizedBox(width: 4),
          Text('Book',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.brandBlue,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingResult booking;
  const _BookingCard({required this.booking});

  String _platformLogo() {
    switch (booking.platform.toLowerCase()) {
      case 'booking.com':
        return '🏨';
      case 'agoda':
        return '🏠';
      case 'klook':
        return '🎫';
      case 'viator':
        return '🗺️';
      case 'getyourguide':
        return '🎯';
      default:
        return '🔗';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Text(_platformLogo(), style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(booking.platform,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(booking.title,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (booking.price != null)
                Text(
                  '${booking.currency ?? ''} ${booking.price}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => launchUrl(Uri.parse(booking.url),
              mode: LaunchMode.externalApplication),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.brandBlue,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child:
              const Text('Book', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
