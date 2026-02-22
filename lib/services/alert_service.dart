import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Trip Alerts Service
// Mirrors: usePreTripAlerts.ts
// ──────────────────────────────────────────────

class TripAlert {
  final String id;
  final String tripId;
  final String type; // weather | price_drop | schedule_change | reminder
  final String title;
  final String? message;
  final String severity; // info | warning | critical
  final bool isRead;
  final String? createdAt;

  TripAlert({
    required this.id,
    required this.tripId,
    required this.type,
    required this.title,
    this.message,
    this.severity = 'info',
    this.isRead = false,
    this.createdAt,
  });

  factory TripAlert.fromJson(Map<String, dynamic> json) => TripAlert(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        type: json['type'] as String? ?? 'reminder',
        title: json['title'] as String? ?? '',
        message: json['message'] as String?,
        severity: json['severity'] as String? ?? 'info',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'trip_id': tripId,
        'type': type,
        'title': title,
        if (message != null) 'message': message,
        'severity': severity,
        'is_read': isRead,
      };
}

class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final _client = SupabaseConfig.client;

  Future<List<TripAlert>> getAlerts(String tripId) async {
    try {
      final data = await _client
          .from('trip_alerts')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => TripAlert.fromJson(e)).toList();
    } catch (e) {
      debugPrint('AlertService.getAlerts error: $e');
      return [];
    }
  }

  Future<TripAlert?> addAlert(TripAlert alert) async {
    try {
      final data = await _client
          .from('trip_alerts')
          .insert(alert.toInsertJson())
          .select()
          .single();
      return TripAlert.fromJson(data);
    } catch (e) {
      debugPrint('AlertService.addAlert error: $e');
      return null;
    }
  }

  Future<void> markAsRead(String alertId) async {
    try {
      await _client
          .from('trip_alerts')
          .update({'is_read': true})
          .eq('id', alertId);
    } catch (e) {
      debugPrint('AlertService.markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead(String tripId) async {
    try {
      await _client
          .from('trip_alerts')
          .update({'is_read': true})
          .eq('trip_id', tripId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('AlertService.markAllAsRead error: $e');
    }
  }

  Future<void> deleteAlert(String alertId) async {
    try {
      await _client.from('trip_alerts').delete().eq('id', alertId);
    } catch (e) {
      debugPrint('AlertService.deleteAlert error: $e');
    }
  }

  Future<int> getUnreadCount(String tripId) async {
    try {
      final data = await _client
          .from('trip_alerts')
          .select('id')
          .eq('trip_id', tripId)
          .eq('is_read', false);
      return (data as List).length;
    } catch (e) {
      debugPrint('AlertService.getUnreadCount error: $e');
      return 0;
    }
  }
}

// ── Providers ──

final alertServiceProvider =
    Provider<AlertService>((_) => AlertService.instance);

final tripAlertsProvider =
    FutureProvider.family<List<TripAlert>, String>((ref, tripId) async {
  return AlertService.instance.getAlerts(tripId);
});

final unreadAlertsCountProvider =
    FutureProvider.family<int, String>((ref, tripId) async {
  return AlertService.instance.getUnreadCount(tripId);
});
