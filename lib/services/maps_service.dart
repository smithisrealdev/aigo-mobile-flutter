import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Maps service — matches website geocode-place, calculate-travel,
// check-traffic patterns
// ──────────────────────────────────────────────

class MapsService {
  MapsService._();
  static final MapsService instance = MapsService._();

  /// Geocode a place name (matches website geocode-place).
  Future<Map<String, dynamic>> geocodePlace(String query) async {
    final res = await _invokeWithRetry('geocode-place',
        body: {'query': query});
    return _parseResponse(res);
  }

  /// Get directions/travel info between two points (matches website calculate-travel).
  Future<Map<String, dynamic>> calculateTravel(
      LatLng origin, LatLng dest) async {
    final res = await _invokeWithRetry('calculate-travel', body: {
      'origin': {'lat': origin.latitude, 'lng': origin.longitude},
      'destination': {'lat': dest.latitude, 'lng': dest.longitude},
    });
    return _parseResponse(res);
  }

  /// Check traffic conditions (matches website check-traffic).
  Future<Map<String, dynamic>> checkTraffic({
    required double latitude,
    required double longitude,
    double? radius,
  }) async {
    final res = await _invokeWithRetry('check-traffic', body: {
      'latitude': latitude,
      'longitude': longitude,
      if (radius != null) 'radius': radius,
    });
    return _parseResponse(res);
  }

  /// Get place details via edge function (matches website place-details).
  Future<Map<String, dynamic>> getPlaceDetails(
      String placeName, {String? placeAddress}) async {
    final res = await _invokeWithRetry('place-details', body: {
      'placeName': placeName,
      if (placeAddress != null) 'placeAddress': placeAddress,
    });
    return _parseResponse(res);
  }

  /// Get nearby places (matches website nearby-places).
  Future<Map<String, dynamic>> getNearbyPlaces(
      LatLng location, String type) async {
    final res = await _invokeWithRetry('nearby-places', body: {
      'lat': location.latitude,
      'lng': location.longitude,
      'type': type,
    });
    return _parseResponse(res);
  }

  /// Open Google Maps deep link.
  Future<void> openInGoogleMaps(String googleMapsUrl) async {
    final uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Map<String, dynamic> _parseResponse(dynamic response) {
    final data = (response as dynamic).data;
    if (data is String) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }

  /// Invoke with retry matching supabaseRetry.ts pattern.
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

final mapsServiceProvider = Provider((_) => MapsService.instance);
