import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Flight service — matches useFlightSearch.ts
// Calls search-flights edge function
// ──────────────────────────────────────────────

class FlightPrice {
  final double total;
  final String currency;

  FlightPrice({required this.total, required this.currency});

  factory FlightPrice.fromJson(Map<String, dynamic> json) => FlightPrice(
        total: (json['total'] as num).toDouble(),
        currency: json['currency'] as String,
      );
}

class FlightLeg {
  final String departureAirport;
  final String departureTime;
  final String arrivalAirport;
  final String arrivalTime;
  final String duration;
  final int stops;
  final String airline;
  final String flightNumber;

  FlightLeg({
    required this.departureAirport,
    required this.departureTime,
    required this.arrivalAirport,
    required this.arrivalTime,
    required this.duration,
    required this.stops,
    required this.airline,
    required this.flightNumber,
  });

  factory FlightLeg.fromJson(Map<String, dynamic> json) => FlightLeg(
        departureAirport:
            (json['departure'] as Map<String, dynamic>)['airport'] as String,
        departureTime:
            (json['departure'] as Map<String, dynamic>)['time'] as String,
        arrivalAirport:
            (json['arrival'] as Map<String, dynamic>)['airport'] as String,
        arrivalTime:
            (json['arrival'] as Map<String, dynamic>)['time'] as String,
        duration: json['duration'] as String,
        stops: json['stops'] as int,
        airline: json['airline'] as String,
        flightNumber: json['flightNumber'] as String,
      );
}

class BaggageAllowance {
  final bool carryOnIncluded;
  final String? carryOnWeight;
  final bool checkedBagIncluded;
  final String? checkedBagWeight;

  BaggageAllowance({
    required this.carryOnIncluded,
    this.carryOnWeight,
    required this.checkedBagIncluded,
    this.checkedBagWeight,
  });

  factory BaggageAllowance.fromJson(Map<String, dynamic> json) {
    final carryOn = json['carryOn'] as Map<String, dynamic>? ?? {};
    final checked = json['checkedBag'] as Map<String, dynamic>? ?? {};
    return BaggageAllowance(
      carryOnIncluded: carryOn['included'] as bool? ?? false,
      carryOnWeight: carryOn['weight'] as String?,
      checkedBagIncluded: checked['included'] as bool? ?? false,
      checkedBagWeight: checked['weight'] as String?,
    );
  }
}

class Flight {
  final String id;
  final FlightPrice price;
  final FlightLeg outbound;
  final FlightLeg? returnLeg;
  final String bookingClass;
  final int seatsAvailable;
  final BaggageAllowance? baggage;

  Flight({
    required this.id,
    required this.price,
    required this.outbound,
    this.returnLeg,
    required this.bookingClass,
    required this.seatsAvailable,
    this.baggage,
  });

  factory Flight.fromJson(Map<String, dynamic> json) => Flight(
        id: json['id'] as String,
        price: FlightPrice.fromJson(json['price'] as Map<String, dynamic>),
        outbound:
            FlightLeg.fromJson(json['outbound'] as Map<String, dynamic>),
        returnLeg: json['return'] != null
            ? FlightLeg.fromJson(json['return'] as Map<String, dynamic>)
            : null,
        bookingClass: json['bookingClass'] as String? ?? 'ECONOMY',
        seatsAvailable: json['seatsAvailable'] as int? ?? 0,
        baggage: json['baggage'] != null
            ? BaggageAllowance.fromJson(
                json['baggage'] as Map<String, dynamic>)
            : null,
      );
}

class SearchLink {
  final String name;
  final String url;
  final String icon;

  SearchLink(
      {required this.name, required this.url, required this.icon});

  factory SearchLink.fromJson(Map<String, dynamic> json) => SearchLink(
        name: json['name'] as String,
        url: json['url'] as String,
        icon: json['icon'] as String? ?? '',
      );
}

class SearchFlightsParams {
  final String origin;
  final String destination;
  final String departureDate;
  final String? returnDate;
  final int adults;
  final String travelClass;

  SearchFlightsParams({
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.returnDate,
    this.adults = 1,
    this.travelClass = 'ECONOMY',
  });

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'destination': destination,
        'departureDate': departureDate,
        'returnDate': ?returnDate,
        'adults': adults,
        'travelClass': travelClass,
      };
}

class FlightService {
  FlightService._();
  static final FlightService instance = FlightService._();

  /// Search flights (matches useFlightSearch.ts searchFlights).
  Future<({List<Flight> flights, List<SearchLink> searchLinks, String? message})>
      searchFlights(SearchFlightsParams params) async {
    final res = await _invokeWithRetry('search-flights',
        body: params.toJson());
    final data = res.data as Map<String, dynamic>?;

    if (data?['error'] != null) {
      throw Exception(data!['error'] as String);
    }

    final flights = (data?['flights'] as List?)
            ?.map((f) =>
                Flight.fromJson(f as Map<String, dynamic>))
            .toList() ??
        [];

    final searchLinks = (data?['searchLinks'] as List?)
            ?.map((l) =>
                SearchLink.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [];

    final message = data?['message'] as String?;

    return (
      flights: flights,
      searchLinks: searchLinks,
      message: message,
    );
  }

  Future<dynamic> _invokeWithRetry(String functionName,
      {Map<String, dynamic>? body, int maxRetries = 3}) async {
    dynamic lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await SupabaseConfig.client.functions
          .invoke(functionName, body: body);
      final d = result.data;
      final isBootError = d is Map && d['code'] == 'BOOT_ERROR';
      if (isBootError && attempt < maxRetries) {
        lastError = Exception('BOOT_ERROR');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
        continue;
      }
      return result;
    }
    throw lastError ?? Exception('All retries exhausted');
  }
}

// ── Riverpod providers ──

final flightServiceProvider =
    Provider((_) => FlightService.instance);
