import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Booking Integration Service
// Mirrors: useSearchBooking.ts, useAffiliateMarker.ts
// ──────────────────────────────────────────────

class BookingResult {
  final String platform;
  final String title;
  final String? price;
  final String? currency;
  final String url;
  final String? rating;
  final String? availability;
  final String? imageUrl;

  BookingResult({
    required this.platform,
    required this.title,
    this.price,
    this.currency,
    required this.url,
    this.rating,
    this.availability,
    this.imageUrl,
  });

  factory BookingResult.fromJson(Map<String, dynamic> json) => BookingResult(
        platform: json['platform'] as String? ?? '',
        title: json['title'] as String? ?? '',
        price: json['price'] as String?,
        currency: json['currency'] as String?,
        url: json['url'] as String? ?? '',
        rating: json['rating'] as String?,
        availability: json['availability'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

class BookingService {
  BookingService._();
  static final instance = BookingService._();

  final _client = SupabaseConfig.client;
  String? _affiliateMarker;

  /// Search bookings via edge function.
  Future<List<BookingResult>> searchBookings(
    String placeName, {
    String? placeAddress,
    String? activityType,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'search-booking',
        body: {
          'placeName': placeName,
          if (placeAddress != null) 'placeAddress': placeAddress,
          if (activityType != null) 'activityType': activityType,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data?['success'] == true) {
        return ((data?['bookings'] as List<dynamic>?) ?? [])
            .map((b) => BookingResult.fromJson(b as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[BookingService] searchBookings error: $e');
    }

    // Fallback bookings
    return _fallbackBookings(placeName);
  }

  List<BookingResult> _fallbackBookings(String placeName) {
    final encoded = Uri.encodeComponent(placeName);
    return [
      BookingResult(
        platform: 'GetYourGuide',
        title: 'Search $placeName on GetYourGuide',
        url: 'https://www.getyourguide.com/s/?q=$encoded',
        availability: 'Check website',
      ),
      BookingResult(
        platform: 'Klook',
        title: 'Search $placeName on Klook',
        url: 'https://www.klook.com/search/?query=$encoded',
        availability: 'Check website',
      ),
      BookingResult(
        platform: 'Viator',
        title: 'Search $placeName on Viator',
        url: 'https://www.viator.com/searchResults/all?text=$encoded',
        availability: 'Check website',
      ),
    ];
  }

  /// Load affiliate marker from edge function.
  Future<String?> _getMarker() async {
    if (_affiliateMarker != null) return _affiliateMarker;
    try {
      final response =
          await _client.functions.invoke('get-affiliate-marker');
      final data = response.data as Map<String, dynamic>?;
      _affiliateMarker = data?['marker'] as String?;
    } catch (_) {}
    return _affiliateMarker;
  }

  /// Generate Aviasales affiliate URL for flights.
  String getFlightAffiliateUrl({
    required String origin,
    required String destination,
    required String departureDate,
    String? returnDate,
  }) {
    String formatDate(String dateStr) {
      final parts = dateStr.split('-');
      return '${parts[2]}${parts[1]}'; // DDMM
    }

    final depDate = formatDate(departureDate);
    final retDate = returnDate != null ? formatDate(returnDate) : '';
    final route = retDate.isNotEmpty
        ? '$origin$depDate$destination${retDate}1'
        : '$origin$depDate${destination}1';
    final url = 'https://www.aviasales.com/search/$route';
    final marker = _affiliateMarker;
    return marker != null ? '$url?marker=$marker' : url;
  }

  /// Generate Booking.com URL for hotels.
  String getBookingUrl({
    String? hotelName,
    required String city,
    required String checkIn,
    required String checkOut,
  }) {
    final params = {
      'ss': hotelName ?? city,
      'checkin': checkIn,
      'checkout': checkOut,
      'group_adults': '1',
      'no_rooms': '1',
    };
    return Uri.https(
            'www.booking.com', '/searchresults.html', params)
        .toString();
  }

  /// Generate Klook URL.
  String getKlookUrl(String query, {String? city}) {
    final searchQuery = city != null ? '$query $city' : query;
    final params = {'query': searchQuery};
    final marker = _affiliateMarker;
    if (marker != null) params['aid'] = marker;
    return Uri.https('www.klook.com', '/search/result/', params).toString();
  }

  /// Track affiliate click.
  Future<void> trackClick({
    required String platform,
    String? placeName,
    required String destinationUrl,
    required String searchType,
  }) async {
    try {
      await _client.functions.invoke('track-affiliate-click', body: {
        'platform': platform,
        if (placeName != null) 'placeName': placeName,
        'destinationUrl': destinationUrl,
        'searchType': searchType,
      });
    } catch (_) {}
  }
}

// ── Riverpod Providers ──

final bookingSearchProvider = FutureProvider.family<List<BookingResult>,
    ({String name, String? address})>((ref, params) async {
  return BookingService.instance
      .searchBookings(params.name, placeAddress: params.address);
});
