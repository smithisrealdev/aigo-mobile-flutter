import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';

// ──────────────────────────────────────────────
// Itinerary service — AI generation via edge function + trip updates
// ──────────────────────────────────────────────

class ItineraryService {
  ItineraryService._();
  static final ItineraryService instance = ItineraryService._();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Call the `generate-itinerary` edge function.
  ///
  /// Returns a map with at minimum:
  ///   - `trip_id`   — the created trip row id
  ///   - `status`    — 'processing' | 'completed' | 'failed'
  ///   - plus full itinerary_data when completed synchronously
  Future<Map<String, dynamic>> generateItinerary({
    required String prompt,
    double? budget,
    String currency = 'THB',
    Map<String, dynamic>? preferences,
  }) async {
    final body = {
      'prompt': prompt,
      if (budget != null) 'budget': budget,
      'currency': currency,
      if (preferences != null) 'preferences': preferences,
    };

    final response = await _client.functions.invoke(
      'generate-itinerary',
      body: body,
    );

    if (response.status != 200) {
      throw Exception(
          'Itinerary generation failed (${response.status}): ${response.data}');
    }

    final data = response.data is String
        ? jsonDecode(response.data) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    return data;
  }

  /// Poll trip status until itinerary_data is populated.
  Stream<Trip> watchTripStatus(String tripId) {
    // Use Supabase realtime to listen for changes on the trip row.
    return _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((rows) {
          if (rows.isEmpty) throw Exception('Trip not found');
          return Trip.fromJson(rows.first);
        });
  }

  /// Save / overwrite itinerary_data on an existing trip.
  Future<void> saveItineraryData(
      String tripId, Map<String, dynamic> data) async {
    await _client.from('trips').update({
      'itinerary_data': data,
      'status': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }

  /// Call voice-to-text edge function (Whisper).
  Future<String> voiceToText(List<int> audioBytes,
      {String mimeType = 'audio/webm'}) async {
    final response = await _client.functions.invoke(
      'voice-to-text',
      body: {
        'audio': base64Encode(audioBytes),
        'mime_type': mimeType,
      },
    );

    if (response.status != 200) {
      throw Exception('Voice-to-text failed (${response.status})');
    }

    final data = response.data is String
        ? jsonDecode(response.data) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    return data['text'] as String? ?? '';
  }
}

// ──────────────────────────────────────────────
// Riverpod providers
// ──────────────────────────────────────────────

final itineraryServiceProvider = Provider((_) => ItineraryService.instance);

/// State for an in-progress itinerary generation.
class ItineraryGenState {
  final bool isGenerating;
  final String? tripId;
  final String? error;
  final Trip? completedTrip;

  ItineraryGenState({
    this.isGenerating = false,
    this.tripId,
    this.error,
    this.completedTrip,
  });

  ItineraryGenState copyWith({
    bool? isGenerating,
    String? tripId,
    String? error,
    Trip? completedTrip,
  }) =>
      ItineraryGenState(
        isGenerating: isGenerating ?? this.isGenerating,
        tripId: tripId ?? this.tripId,
        error: error,
        completedTrip: completedTrip ?? this.completedTrip,
      );
}

class ItineraryGenNotifier extends Notifier<ItineraryGenState> {
  @override
  ItineraryGenState build() => ItineraryGenState();

  Future<void> generate(String prompt,
      {double? budget, String currency = 'THB'}) async {
    state = ItineraryGenState(isGenerating: true);

    try {
      final result = await ItineraryService.instance.generateItinerary(
        prompt: prompt,
        budget: budget,
        currency: currency,
      );

      final tripId = result['trip_id'] as String?;
      state = state.copyWith(isGenerating: false, tripId: tripId);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
    }
  }
}

final itineraryGenProvider =
    NotifierProvider<ItineraryGenNotifier, ItineraryGenState>(
        ItineraryGenNotifier.new);
