import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Weather service — matches useWeather.ts
// Calls `weather` edge function
// ──────────────────────────────────────────────

class WeatherForecast {
  final String date;
  final double tempMax;
  final double tempMin;
  final int precipitationProbability;
  final int weathercode;
  final String condition;

  WeatherForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationProbability,
    required this.weathercode,
    required this.condition,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) =>
      WeatherForecast(
        date: json['date'] as String,
        tempMax: (json['tempMax'] as num).toDouble(),
        tempMin: (json['tempMin'] as num).toDouble(),
        precipitationProbability:
            json['precipitationProbability'] as int? ?? 0,
        weathercode: json['weathercode'] as int? ?? 0,
        condition: json['condition'] as String? ?? '',
      );
}

class CurrentWeather {
  final double temperature;
  final int weathercode;
  final String time;
  final String condition;

  CurrentWeather({
    required this.temperature,
    required this.weathercode,
    required this.time,
    required this.condition,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) =>
      CurrentWeather(
        temperature: (json['temperature'] as num).toDouble(),
        weathercode: json['weathercode'] as int? ?? 0,
        time: json['time'] as String? ?? '',
        condition: json['condition'] as String? ?? '',
      );
}

class WeatherResponse {
  final bool success;
  final List<WeatherForecast>? forecast;
  final CurrentWeather? current;
  final String? error;

  WeatherResponse({
    required this.success,
    this.forecast,
    this.current,
    this.error,
  });
}

/// Round coordinate for cache keys.
double _roundCoord(double v, int decimals) {
  final factor = 10.0 * decimals;
  return (v * factor).round() / factor;
}

// In-memory cache matching website's staleTime approach
class _CacheEntry<T> {
  final T data;
  final DateTime fetchedAt;
  _CacheEntry(this.data) : fetchedAt = DateTime.now();
}

final _forecastCache = <String, _CacheEntry<WeatherResponse>>{};
final _currentCache = <String, _CacheEntry<WeatherResponse>>{};

const _forecastStaleMs = 2 * 60 * 60 * 1000; // 2 hours
const _currentStaleMs = 30 * 60 * 1000; // 30 minutes

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  /// Get weather forecast (matches useWeather.getForecast).
  Future<WeatherResponse?> getForecast(
      double latitude, double longitude) async {
    final rLat = _roundCoord(latitude, 2);
    final rLon = _roundCoord(longitude, 2);
    final key = 'forecast_${rLat}_$rLon';

    // Check cache
    final cached = _forecastCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMilliseconds <
            _forecastStaleMs) {
      return cached.data;
    }

    try {
      final res = await SupabaseConfig.client.functions.invoke('weather',
          body: {
            'latitude': latitude,
            'longitude': longitude,
            'action': 'get-forecast',
          });

      final data = res.data as Map<String, dynamic>;
      if (data['success'] != true) {
        return WeatherResponse(
            success: false, error: data['error'] as String?);
      }

      final forecasts = (data['forecast'] as List?)
          ?.map((f) =>
              WeatherForecast.fromJson(f as Map<String, dynamic>))
          .toList();

      final result =
          WeatherResponse(success: true, forecast: forecasts);
      _forecastCache[key] = _CacheEntry(result);
      return result;
    } catch (e) {
      return WeatherResponse(success: false, error: e.toString());
    }
  }

  /// Get current weather (matches useWeather.getCurrent).
  Future<WeatherResponse?> getCurrent(
      double latitude, double longitude) async {
    final rLat = _roundCoord(latitude, 2);
    final rLon = _roundCoord(longitude, 2);
    final key = 'current_${rLat}_$rLon';

    // Check cache
    final cached = _currentCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMilliseconds <
            _currentStaleMs) {
      return cached.data;
    }

    try {
      final res = await SupabaseConfig.client.functions.invoke('weather',
          body: {
            'latitude': latitude,
            'longitude': longitude,
            'action': 'get-current',
          });

      final data = res.data as Map<String, dynamic>;
      if (data['success'] != true) {
        return WeatherResponse(
            success: false, error: data['error'] as String?);
      }

      final current = data['current'] != null
          ? CurrentWeather.fromJson(
              data['current'] as Map<String, dynamic>)
          : null;

      final result =
          WeatherResponse(success: true, current: current);
      _currentCache[key] = _CacheEntry(result);
      return result;
    } catch (e) {
      return WeatherResponse(success: false, error: e.toString());
    }
  }
}

// ── Riverpod providers ──

final weatherServiceProvider =
    Provider((_) => WeatherService.instance);
