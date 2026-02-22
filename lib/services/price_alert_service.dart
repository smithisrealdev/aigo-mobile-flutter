import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Price Alert Service
// Tables: flight_price_alerts, hotel_price_alerts, price_history
// ──────────────────────────────────────────────

class FlightPriceAlert {
  final String id;
  final String userId;
  final String originCode;
  final String? originName;
  final String destinationCode;
  final String? destinationName;
  final String departureDate;
  final String? returnDate;
  final int adults;
  final double? targetPrice;
  final double? lastKnownPrice;
  final String? lastKnownCurrency;
  final bool isActive;
  final String? lastCheckedAt;
  final String createdAt;

  FlightPriceAlert({
    required this.id,
    required this.userId,
    required this.originCode,
    this.originName,
    required this.destinationCode,
    this.destinationName,
    required this.departureDate,
    this.returnDate,
    this.adults = 1,
    this.targetPrice,
    this.lastKnownPrice,
    this.lastKnownCurrency,
    this.isActive = true,
    this.lastCheckedAt,
    required this.createdAt,
  });

  factory FlightPriceAlert.fromJson(Map<String, dynamic> json) =>
      FlightPriceAlert(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        originCode: json['origin_code'] as String,
        originName: json['origin_name'] as String?,
        destinationCode: json['destination_code'] as String,
        destinationName: json['destination_name'] as String?,
        departureDate: json['departure_date'] as String,
        returnDate: json['return_date'] as String?,
        adults: json['adults'] as int? ?? 1,
        targetPrice: (json['target_price'] as num?)?.toDouble(),
        lastKnownPrice: (json['last_known_price'] as num?)?.toDouble(),
        lastKnownCurrency: json['last_known_currency'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        lastCheckedAt: json['last_checked_at'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class HotelPriceAlert {
  final String id;
  final String userId;
  final String hotelName;
  final String? hotelAddress;
  final String destination;
  final String checkInDate;
  final String checkOutDate;
  final int rooms;
  final int guests;
  final double? targetPrice;
  final double? lastKnownPrice;
  final String? lastKnownCurrency;
  final bool isActive;
  final String? lastCheckedAt;
  final String createdAt;

  HotelPriceAlert({
    required this.id,
    required this.userId,
    required this.hotelName,
    this.hotelAddress,
    required this.destination,
    required this.checkInDate,
    required this.checkOutDate,
    this.rooms = 1,
    this.guests = 1,
    this.targetPrice,
    this.lastKnownPrice,
    this.lastKnownCurrency,
    this.isActive = true,
    this.lastCheckedAt,
    required this.createdAt,
  });

  factory HotelPriceAlert.fromJson(Map<String, dynamic> json) =>
      HotelPriceAlert(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        hotelName: json['hotel_name'] as String,
        hotelAddress: json['hotel_address'] as String?,
        destination: json['destination'] as String,
        checkInDate: json['check_in_date'] as String,
        checkOutDate: json['check_out_date'] as String,
        rooms: json['rooms'] as int? ?? 1,
        guests: json['guests'] as int? ?? 1,
        targetPrice: (json['target_price'] as num?)?.toDouble(),
        lastKnownPrice: (json['last_known_price'] as num?)?.toDouble(),
        lastKnownCurrency: json['last_known_currency'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        lastCheckedAt: json['last_checked_at'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class PriceHistoryEntry {
  final String id;
  final String? alertId;
  final String placeName;
  final String platform;
  final double price;
  final String? currency;
  final String recordedAt;

  PriceHistoryEntry({
    required this.id,
    this.alertId,
    required this.placeName,
    required this.platform,
    required this.price,
    this.currency,
    required this.recordedAt,
  });

  factory PriceHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PriceHistoryEntry(
        id: json['id'] as String,
        alertId: json['alert_id'] as String?,
        placeName: json['place_name'] as String,
        platform: json['platform'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String?,
        recordedAt: json['recorded_at'] as String? ?? '',
      );
}

class PriceAlertService {
  PriceAlertService._();
  static final instance = PriceAlertService._();

  final _client = SupabaseConfig.client;

  // ── Flight Price Alerts ──

  Future<List<FlightPriceAlert>> fetchFlightAlerts() async {
    try {
      final data = await _client
          .from('flight_price_alerts')
          .select()
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => FlightPriceAlert.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PriceAlertService] fetchFlightAlerts error: $e');
      return [];
    }
  }

  Future<FlightPriceAlert?> createFlightAlert({
    required String originCode,
    String? originName,
    required String destinationCode,
    String? destinationName,
    required String departureDate,
    String? returnDate,
    double? targetPrice,
    int adults = 1,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _client
          .from('flight_price_alerts')
          .insert({
            'user_id': userId,
            'origin_code': originCode,
            'origin_name': originName,
            'destination_code': destinationCode,
            'destination_name': destinationName,
            'departure_date': departureDate,
            'return_date': returnDate,
            'target_price': targetPrice,
            'adults': adults,
          })
          .select()
          .single();
      return FlightPriceAlert.fromJson(data);
    } catch (e) {
      debugPrint('[PriceAlertService] createFlightAlert error: $e');
      return null;
    }
  }

  Future<bool> toggleFlightAlert(String id, bool isActive) async {
    try {
      await _client
          .from('flight_price_alerts')
          .update({'is_active': isActive}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[PriceAlertService] toggleFlightAlert error: $e');
      return false;
    }
  }

  Future<bool> deleteFlightAlert(String id) async {
    try {
      await _client.from('flight_price_alerts').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[PriceAlertService] deleteFlightAlert error: $e');
      return false;
    }
  }

  // ── Hotel Price Alerts ──

  Future<List<HotelPriceAlert>> fetchHotelAlerts() async {
    try {
      final data = await _client
          .from('hotel_price_alerts')
          .select()
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => HotelPriceAlert.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PriceAlertService] fetchHotelAlerts error: $e');
      return [];
    }
  }

  Future<HotelPriceAlert?> createHotelAlert({
    required String hotelName,
    String? hotelAddress,
    required String destination,
    required String checkInDate,
    required String checkOutDate,
    double? targetPrice,
    int rooms = 1,
    int guests = 1,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _client
          .from('hotel_price_alerts')
          .insert({
            'user_id': userId,
            'hotel_name': hotelName,
            'hotel_address': hotelAddress,
            'destination': destination,
            'check_in_date': checkInDate,
            'check_out_date': checkOutDate,
            'target_price': targetPrice,
            'rooms': rooms,
            'guests': guests,
          })
          .select()
          .single();
      return HotelPriceAlert.fromJson(data);
    } catch (e) {
      debugPrint('[PriceAlertService] createHotelAlert error: $e');
      return null;
    }
  }

  Future<bool> toggleHotelAlert(String id, bool isActive) async {
    try {
      await _client
          .from('hotel_price_alerts')
          .update({'is_active': isActive}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[PriceAlertService] toggleHotelAlert error: $e');
      return false;
    }
  }

  Future<bool> deleteHotelAlert(String id) async {
    try {
      await _client.from('hotel_price_alerts').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[PriceAlertService] deleteHotelAlert error: $e');
      return false;
    }
  }

  // ── Price History ──

  Future<List<PriceHistoryEntry>> fetchPriceHistory(String alertId) async {
    try {
      final data = await _client
          .from('price_history')
          .select()
          .eq('alert_id', alertId)
          .order('recorded_at', ascending: true);
      return (data as List<dynamic>)
          .map((r) => PriceHistoryEntry.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PriceAlertService] fetchPriceHistory error: $e');
      return [];
    }
  }

  // ── Check alerts via edge functions ──

  Future<void> checkFlightAlerts() async {
    try {
      await _client.functions.invoke('check-flight-price-alerts');
    } catch (e) {
      debugPrint('[PriceAlertService] checkFlightAlerts error: $e');
    }
  }

  Future<void> checkHotelAlerts() async {
    try {
      await _client.functions.invoke('check-hotel-price-alerts');
    } catch (e) {
      debugPrint('[PriceAlertService] checkHotelAlerts error: $e');
    }
  }

  /// Check generic price alerts via edge function.
  Future<Map<String, dynamic>> checkPriceAlerts() async {
    try {
      final response = await _client.functions.invoke('check-price-alerts');
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('[PriceAlertService] checkPriceAlerts error: $e');
      return {};
    }
  }

  // ── Generic Price Alerts (price_alerts table) ──

  Future<List<Map<String, dynamic>>> fetchGenericAlerts() async {
    try {
      final data = await _client
          .from('price_alerts')
          .select()
          .order('created_at', ascending: false);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[PriceAlertService] fetchGenericAlerts error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createGenericAlert(
      Map<String, dynamic> alertData) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _client
          .from('price_alerts')
          .insert({...alertData, 'user_id': userId})
          .select()
          .single();
      return data;
    } catch (e) {
      debugPrint('[PriceAlertService] createGenericAlert error: $e');
      return null;
    }
  }

  Future<bool> deleteGenericAlert(String id) async {
    try {
      await _client.from('price_alerts').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[PriceAlertService] deleteGenericAlert error: $e');
      return false;
    }
  }

  // ── Price History (generic, for charts) ──

  Future<List<PriceHistoryEntry>> fetchPriceHistoryByPlace(
      String placeName) async {
    try {
      final data = await _client
          .from('price_history')
          .select()
          .eq('place_name', placeName)
          .order('recorded_at', ascending: true);
      return (data as List<dynamic>)
          .map((r) => PriceHistoryEntry.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PriceAlertService] fetchPriceHistoryByPlace error: $e');
      return [];
    }
  }
}

// ── Riverpod Providers ──

final flightAlertsProvider =
    FutureProvider<List<FlightPriceAlert>>((ref) async {
  return PriceAlertService.instance.fetchFlightAlerts();
});

final hotelAlertsProvider =
    FutureProvider<List<HotelPriceAlert>>((ref) async {
  return PriceAlertService.instance.fetchHotelAlerts();
});

final priceHistoryProvider =
    FutureProvider.family<List<PriceHistoryEntry>, String>(
        (ref, alertId) async {
  return PriceAlertService.instance.fetchPriceHistory(alertId);
});
