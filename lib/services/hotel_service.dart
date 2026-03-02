import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Hotel service — matches useHotelSearch.ts
// Calls search-hotels edge function
// ──────────────────────────────────────────────

class HotelPrice {
  final double total;
  final String currency;
  final double perNight;

  HotelPrice(
      {required this.total,
      required this.currency,
      required this.perNight});

  factory HotelPrice.fromJson(Map<String, dynamic> json) => HotelPrice(
        total: (json['total'] as num).toDouble(),
        currency: json['currency'] as String,
        perNight: (json['perNight'] as num).toDouble(),
      );
}

class HotelRoom {
  final String type;
  final int beds;
  final String bedType;
  final String description;

  HotelRoom({
    required this.type,
    required this.beds,
    required this.bedType,
    required this.description,
  });

  factory HotelRoom.fromJson(Map<String, dynamic> json) => HotelRoom(
        type: json['type'] as String? ?? '',
        beds: json['beds'] as int? ?? 1,
        bedType: json['bedType'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

class Hotel {
  final String id;
  final String name;
  final String address;
  final String city;
  final double? rating;
  final ({double lat, double lng})? coordinates;
  final HotelPrice? price;
  final HotelRoom? room;
  final String? cancellation;
  final bool available;

  Hotel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.rating,
    this.coordinates,
    this.price,
    this.room,
    this.cancellation,
    this.available = true,
  });

  factory Hotel.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>?;
    return Hotel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      coordinates: coords != null
          ? (
              lat: (coords['lat'] as num).toDouble(),
              lng: (coords['lng'] as num).toDouble(),
            )
          : null,
      price: json['price'] != null
          ? HotelPrice.fromJson(json['price'] as Map<String, dynamic>)
          : null,
      room: json['room'] != null
          ? HotelRoom.fromJson(json['room'] as Map<String, dynamic>)
          : null,
      cancellation: json['cancellation'] as String?,
      available: json['available'] as bool? ?? true,
    );
  }
}

class SearchHotelsParams {
  final String cityCode;
  final String checkInDate;
  final String checkOutDate;
  final int adults;
  final int roomQuantity;
  final String? ratings;
  final String? priceRange;

  SearchHotelsParams({
    required this.cityCode,
    required this.checkInDate,
    required this.checkOutDate,
    this.adults = 1,
    this.roomQuantity = 1,
    this.ratings,
    this.priceRange,
  });

  Map<String, dynamic> toJson() => {
        'cityCode': cityCode,
        'checkInDate': checkInDate,
        'checkOutDate': checkOutDate,
        'adults': adults,
        'roomQuantity': roomQuantity,
        'ratings': ?ratings,
        'priceRange': ?priceRange,
      };
}

class HotelService {
  HotelService._();
  static final HotelService instance = HotelService._();

  /// Search hotels (matches useHotelSearch.ts searchHotels).
  Future<List<Hotel>> searchHotels(SearchHotelsParams params) async {
    final res = await _invokeWithRetry('search-hotels',
        body: params.toJson());
    final data = res.data as Map<String, dynamic>?;

    if (data?['error'] != null) {
      throw Exception(data!['error'] as String);
    }

    return (data?['hotels'] as List?)
            ?.map(
                (h) => Hotel.fromJson(h as Map<String, dynamic>))
            .toList() ??
        [];
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

final hotelServiceProvider =
    Provider((_) => HotelService.instance);
