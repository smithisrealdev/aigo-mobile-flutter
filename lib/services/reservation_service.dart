import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Reservations Service
// CRUD on `reservations` table
// ──────────────────────────────────────────────

class Reservation {
  final String id;
  final String tripId;
  final int? dayIndex;
  final String type; // hotel | flight | restaurant | activity | transport
  final String title;
  final String? confirmationNumber;
  final String? bookingUrl;
  final String? checkIn;
  final String? checkOut;
  final String? notes;
  final double? cost;
  final String? currency;
  final String? status;
  final String? createdAt;

  Reservation({
    required this.id,
    required this.tripId,
    this.dayIndex,
    required this.type,
    required this.title,
    this.confirmationNumber,
    this.bookingUrl,
    this.checkIn,
    this.checkOut,
    this.notes,
    this.cost,
    this.currency,
    this.status,
    this.createdAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        dayIndex: json['day_index'] as int?,
        type: json['type'] as String? ?? 'activity',
        title: json['title'] as String? ?? '',
        confirmationNumber: json['confirmation_number'] as String?,
        bookingUrl: json['booking_url'] as String?,
        checkIn: json['check_in'] as String?,
        checkOut: json['check_out'] as String?,
        notes: json['notes'] as String?,
        cost: (json['cost'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        status: json['status'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'trip_id': tripId,
        'day_index': ?dayIndex,
        'type': type,
        'title': title,
        'confirmation_number': ?confirmationNumber,
        'booking_url': ?bookingUrl,
        'check_in': ?checkIn,
        'check_out': ?checkOut,
        'notes': ?notes,
        'cost': ?cost,
        'currency': ?currency,
        'status': ?status,
      };
}

class ReservationService {
  ReservationService._();
  static final ReservationService instance = ReservationService._();

  final _client = SupabaseConfig.client;

  Future<List<Reservation>> getReservations(String tripId) async {
    try {
      final data = await _client
          .from('reservations')
          .select()
          .eq('trip_id', tripId)
          .order('day_index', ascending: true);
      return (data as List).map((e) => Reservation.fromJson(e)).toList();
    } catch (e) {
      debugPrint('ReservationService.getReservations error: $e');
      return [];
    }
  }

  Future<Reservation?> addReservation(Reservation reservation) async {
    try {
      final data = await _client
          .from('reservations')
          .insert(reservation.toInsertJson())
          .select()
          .single();
      return Reservation.fromJson(data);
    } catch (e) {
      debugPrint('ReservationService.addReservation error: $e');
      return null;
    }
  }

  Future<void> updateReservation(
      String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('reservations').update(updates).eq('id', id);
    } catch (e) {
      debugPrint('ReservationService.updateReservation error: $e');
    }
  }

  Future<void> deleteReservation(String id) async {
    try {
      await _client.from('reservations').delete().eq('id', id);
    } catch (e) {
      debugPrint('ReservationService.deleteReservation error: $e');
    }
  }
}

// ── Providers ──

final reservationServiceProvider =
    Provider<ReservationService>((_) => ReservationService.instance);

final tripReservationsProvider =
    FutureProvider.family<List<Reservation>, String>((ref, tripId) async {
  return ReservationService.instance.getReservations(tripId);
});
