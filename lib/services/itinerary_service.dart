import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

// ──────────────────────────────────────────────
// Itinerary service — matches useGenerateItinerary.ts
// Uses streaming fetch to generate-itinerary edge function
// ──────────────────────────────────────────────

/// Parameters matching website GenerateItineraryParams.
class GenerateItineraryParams {
  final String destination;
  final String startDate;
  final String endDate;
  final String? budget;
  final String? tripStyle;
  final String? travelers;
  final String? specialRequirements;
  final String? conversationContext;
  final bool forceRegenerate;
  final Map<String, dynamic>? tripSummary;

  GenerateItineraryParams({
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.budget,
    this.tripStyle,
    this.travelers,
    this.specialRequirements,
    this.conversationContext,
    this.forceRegenerate = false,
    this.tripSummary,
  });

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'startDate': startDate,
        'endDate': endDate,
        if (budget != null) 'budget': budget,
        if (tripStyle != null) 'tripStyle': tripStyle,
        if (travelers != null) 'travelers': travelers,
        if (specialRequirements != null)
          'specialRequirements': specialRequirements,
        if (conversationContext != null)
          'conversationContext': conversationContext,
        if (forceRegenerate) 'forceRegenerate': true,
        if (tripSummary != null) 'tripSummary': tripSummary,
      };
}

/// SSE progress event from generate-itinerary stream.
class StreamProgress {
  final int day;
  final int totalPlaces;
  final String currentPlace;
  final String message;

  StreamProgress({
    required this.day,
    required this.totalPlaces,
    required this.currentPlace,
    required this.message,
  });
}

/// AI recommended reservation.
class AIRecommendedReservation {
  final String type;
  final String title;
  final String? date;
  final String? time;
  final String? location;
  final String? notes;
  final Map<String, dynamic>? estimatedPrice;
  final List<String>? bookingTips;
  final String priority;

  AIRecommendedReservation({
    required this.type,
    required this.title,
    this.date,
    this.time,
    this.location,
    this.notes,
    this.estimatedPrice,
    this.bookingTips,
    required this.priority,
  });

  factory AIRecommendedReservation.fromJson(Map<String, dynamic> json) =>
      AIRecommendedReservation(
        type: json['type'] as String,
        title: json['title'] as String,
        date: json['date'] as String?,
        time: json['time'] as String?,
        location: json['location'] as String?,
        notes: json['notes'] as String?,
        estimatedPrice: json['estimatedPrice'] as Map<String, dynamic>?,
        bookingTips: (json['bookingTips'] as List?)?.cast<String>(),
        priority: json['priority'] as String? ?? 'optional',
      );
}

class ItineraryService {
  ItineraryService._();
  static final ItineraryService instance = ItineraryService._();

  final Dio _dio = Dio();

  /// Generate itinerary via streaming edge function.
  /// Matches website's authFetch to generate-itinerary.
  ///
  /// Returns parsed itinerary data map on success.
  Future<Map<String, dynamic>> generateItinerary({
    required GenerateItineraryParams params,
    void Function(StreamProgress)? onProgress,
  }) async {
    final token = await AuthService.instance.getAccessToken();
    if (token == null) {
      throw Exception('Authentication required - please sign in');
    }

    final url =
        '${SupabaseConfig.supabaseUrl}/functions/v1/generate-itinerary';

    final response = await _dio.post<ResponseBody>(
      url,
      data: jsonEncode(params.toJson()),
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': 'Bearer $token',
        },
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    if (response.statusCode == 401) {
      // Try refresh token
      final refreshed =
          await SupabaseConfig.client.auth.refreshSession();
      if (refreshed.session == null) {
        throw Exception('Session expired - please sign in again');
      }
      // Retry with new token
      return generateItinerary(params: params, onProgress: onProgress);
    }

    if (response.statusCode != 200) {
      throw Exception(
          'Itinerary generation failed (${response.statusCode})');
    }

    // Parse SSE stream matching website's reader.read() loop
    final stream = response.data!.stream;
    final decoder = const Utf8Decoder();
    var buffer = '';
    Map<String, dynamic>? itineraryResult;

    await for (final chunk in stream) {
      buffer += decoder.convert(chunk);
      final events = buffer.split('\n\n');
      buffer = events.removeLast(); // Keep incomplete event

      for (final event in events) {
        // Collect all data: lines in the event
        final dataLines = event
            .split('\n')
            .where((l) => l.startsWith('data: '))
            .map((l) => l.substring(6))
            .toList();
        if (dataLines.isEmpty) continue;
        final data = dataLines.join('').trim();
        if (data.isEmpty) continue;

        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          final type = parsed['type'] as String?;

          if (type == 'progress') {
            onProgress?.call(StreamProgress(
              day: parsed['day'] as int? ?? 0,
              totalPlaces: parsed['totalPlaces'] as int? ?? 0,
              currentPlace: parsed['currentPlace'] as String? ?? '',
              message: parsed['message'] as String? ?? '',
            ));
          } else if (type == 'complete') {
            itineraryResult =
                parsed['itinerary'] as Map<String, dynamic>?;
          } else if (type == 'error') {
            throw Exception(
                parsed['error'] as String? ?? 'Generation failed');
          }
        } on FormatException {
          // Try to repair truncated JSON
          try {
            final lastBrace = data.lastIndexOf('}');
            if (lastBrace > 0) {
              final trimmed = data.substring(0, lastBrace + 1);
              final parsed =
                  jsonDecode(trimmed) as Map<String, dynamic>;
              if (parsed['type'] == 'complete') {
                itineraryResult =
                    parsed['itinerary'] as Map<String, dynamic>?;
              } else if (parsed['type'] == 'progress') {
                onProgress?.call(StreamProgress(
                  day: parsed['day'] as int? ?? 0,
                  totalPlaces: parsed['totalPlaces'] as int? ?? 0,
                  currentPlace:
                      parsed['currentPlace'] as String? ?? '',
                  message: parsed['message'] as String? ?? '',
                ));
              }
            }
          } catch (_) {
            debugPrint(
                'Skipping unparseable SSE chunk, length: ${data.length}');
          }
        }
      }
    }

    if (itineraryResult == null) {
      throw Exception('No itinerary received');
    }

    return itineraryResult;
  }

  /// Fetch place image from cache or via edge function.
  /// Matches website's fetchAndCacheImage.
  Future<String?> fetchPlaceImage(
      String placeName, String destination) async {
    final placeKey =
        '${placeName.toLowerCase().trim()}|${destination.toLowerCase().trim()}';

    // Check place_details_cache
    final cached = await SupabaseConfig.client
        .from('place_details_cache')
        .select('image_url, photo_urls')
        .eq('place_key', placeKey)
        .maybeSingle();

    if (cached != null) {
      final imageUrl = cached['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
      final photoUrls = cached['photo_urls'] as List?;
      if (photoUrls != null && photoUrls.isNotEmpty) {
        return photoUrls[0] as String?;
      }
    }

    // Call place-details edge function
    try {
      final res =
          await SupabaseConfig.client.functions.invoke('place-details', body: {
        'placeName': placeName,
        'placeAddress': destination,
      });

      final data = res.data as Map<String, dynamic>?;
      if (data?['success'] == true && data?['data'] != null) {
        final d = data!['data'] as Map<String, dynamic>;
        final urls = d['photoUrls'] as List?;
        return (urls?.isNotEmpty == true ? urls![0] as String? : null) ??
            d['photoUrl'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching image for $placeName: $e');
    }

    return null;
  }

  /// Watch trip status via realtime.
  Stream<Trip> watchTripStatus(String tripId) {
    return SupabaseConfig.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((rows) {
          if (rows.isEmpty) throw Exception('Trip not found');
          return Trip.fromJson(rows.first);
        });
  }

  /// Save itinerary data on existing trip.
  Future<void> saveItineraryData(
      String tripId, Map<String, dynamic> data) async {
    await SupabaseConfig.client.from('trips').update({
      'itinerary_data': data,
      'status': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', tripId);
  }
}

// ──────────────────────────────────────────────
// Riverpod providers
// ──────────────────────────────────────────────

final itineraryServiceProvider =
    Provider((_) => ItineraryService.instance);

/// State for an in-progress itinerary generation.
class ItineraryGenState {
  final bool isGenerating;
  final StreamProgress? progress;
  final String? error;
  final Map<String, dynamic>? completedItinerary;
  final List<AIRecommendedReservation> recommendations;

  ItineraryGenState({
    this.isGenerating = false,
    this.progress,
    this.error,
    this.completedItinerary,
    this.recommendations = const [],
  });

  ItineraryGenState copyWith({
    bool? isGenerating,
    StreamProgress? progress,
    String? error,
    Map<String, dynamic>? completedItinerary,
    List<AIRecommendedReservation>? recommendations,
  }) =>
      ItineraryGenState(
        isGenerating: isGenerating ?? this.isGenerating,
        progress: progress ?? this.progress,
        error: error,
        completedItinerary:
            completedItinerary ?? this.completedItinerary,
        recommendations: recommendations ?? this.recommendations,
      );
}

class ItineraryGenNotifier extends Notifier<ItineraryGenState> {
  @override
  ItineraryGenState build() => ItineraryGenState();

  Future<Map<String, dynamic>?> generate(
      GenerateItineraryParams params) async {
    state = ItineraryGenState(isGenerating: true);

    try {
      final result = await ItineraryService.instance.generateItinerary(
        params: params,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );

      // Extract recommendations
      final recs = (result['recommendedReservations'] as List?)
              ?.map((r) => AIRecommendedReservation.fromJson(
                  r as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(
        isGenerating: false,
        completedItinerary: result,
        recommendations: recs,
      );

      return result;
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      return null;
    }
  }
}

final itineraryGenProvider =
    NotifierProvider<ItineraryGenNotifier, ItineraryGenState>(
        ItineraryGenNotifier.new);
