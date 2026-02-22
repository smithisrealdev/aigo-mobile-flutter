import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Maps service — edge-function proxy + deep links
// ──────────────────────────────────────────────

class MapsService {
  MapsService._();
  static final MapsService instance = MapsService._();

  /// Get directions between two points via the `calculate-travel` edge function.
  Future<Map<String, dynamic>> getDirections(LatLng origin, LatLng dest) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'calculate-travel',
      body: {
        'origin': {'lat': origin.latitude, 'lng': origin.longitude},
        'destination': {'lat': dest.latitude, 'lng': dest.longitude},
      },
    );
    return _parse(response);
  }

  /// Get details for a Google place via `place-details` edge function.
  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'place-details',
      body: {'place_id': placeId},
    );
    return _parse(response);
  }

  /// Get nearby places via `nearby-places` edge function.
  Future<Map<String, dynamic>> getNearbyPlaces(
      LatLng location, String type) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'nearby-places',
      body: {
        'lat': location.latitude,
        'lng': location.longitude,
        'type': type,
      },
    );
    return _parse(response);
  }

  /// Geocode a place name/query via `geocode-place` edge function.
  Future<Map<String, dynamic>> geocodePlace(String query) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'geocode-place',
      body: {'query': query},
    );
    return _parse(response);
  }

  /// Open Google Maps (deep link) in external app.
  Future<void> openInGoogleMaps(String googleMapsUrl) async {
    final uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Map<String, dynamic> _parse(dynamic response) {
    // response is the result of functions.invoke() — FunctionResponse
    final status = (response as dynamic).status as int;
    final data = (response as dynamic).data;
    if (status != 200) {
      throw Exception('Edge function error ($status)');
    }
    return data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
  }
}
