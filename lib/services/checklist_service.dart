import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Trip Checklists Service
// Mirrors: usePackingList.ts / trip_checklists table
// ──────────────────────────────────────────────

class ChecklistItem {
  final String id;
  final String tripId;
  final String title;
  final bool isChecked;
  final String category; // packing | todo | shopping
  final String urgency; // low | medium | high
  final String? dueDate;
  final String? notes;
  final String? createdAt;

  ChecklistItem({
    required this.id,
    required this.tripId,
    required this.title,
    this.isChecked = false,
    this.category = 'todo',
    this.urgency = 'medium',
    this.dueDate,
    this.notes,
    this.createdAt,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        title: json['title'] as String? ?? '',
        isChecked: json['is_checked'] as bool? ?? false,
        category: json['category'] as String? ?? 'todo',
        urgency: json['urgency'] as String? ?? 'medium',
        dueDate: json['due_date'] as String?,
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'trip_id': tripId,
        'title': title,
        'is_checked': isChecked,
        'category': category,
        'urgency': urgency,
        'due_date': ?dueDate,
        'notes': ?notes,
      };

  ChecklistItem copyWith({
    String? title,
    bool? isChecked,
    String? category,
    String? urgency,
    String? dueDate,
    String? notes,
  }) =>
      ChecklistItem(
        id: id,
        tripId: tripId,
        title: title ?? this.title,
        isChecked: isChecked ?? this.isChecked,
        category: category ?? this.category,
        urgency: urgency ?? this.urgency,
        dueDate: dueDate ?? this.dueDate,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

class ChecklistService {
  ChecklistService._();
  static final ChecklistService instance = ChecklistService._();

  final _client = SupabaseConfig.client;

  Future<List<ChecklistItem>> getChecklist(String tripId) async {
    try {
      final data = await _client
          .from('trip_checklists')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: true);
      return (data as List).map((e) => ChecklistItem.fromJson(e)).toList();
    } catch (e) {
      debugPrint('ChecklistService.getChecklist error: $e');
      return [];
    }
  }

  Future<ChecklistItem?> addItem(ChecklistItem item) async {
    try {
      final data = await _client
          .from('trip_checklists')
          .insert(item.toInsertJson())
          .select()
          .single();
      return ChecklistItem.fromJson(data);
    } catch (e) {
      debugPrint('ChecklistService.addItem error: $e');
      return null;
    }
  }

  Future<void> toggleItem(String id, bool isChecked) async {
    try {
      await _client
          .from('trip_checklists')
          .update({'is_checked': isChecked})
          .eq('id', id);
    } catch (e) {
      debugPrint('ChecklistService.toggleItem error: $e');
    }
  }

  Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    try {
      await _client.from('trip_checklists').update(updates).eq('id', id);
    } catch (e) {
      debugPrint('ChecklistService.updateItem error: $e');
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _client.from('trip_checklists').delete().eq('id', id);
    } catch (e) {
      debugPrint('ChecklistService.deleteItem error: $e');
    }
  }

  /// Auto-generate checklist from AI using trip-chat edge function.
  Future<List<ChecklistItem>> generateFromAI(String tripId, String destination) async {
    try {
      final response = await _client.functions.invoke(
        'trip-chat',
        body: {
          'tripId': tripId,
          'message':
              'Generate a packing and todo checklist for a trip to $destination. Return as JSON array with fields: title, category (packing/todo/shopping), urgency (low/medium/high).',
        },
      );
      if (response.status != 200) return [];

      final data = response.data;
      List items = [];
      if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else if (data is List) {
        items = data;
      }

      final results = <ChecklistItem>[];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final created = await addItem(ChecklistItem(
            id: '',
            tripId: tripId,
            title: item['title']?.toString() ?? '',
            category: item['category']?.toString() ?? 'todo',
            urgency: item['urgency']?.toString() ?? 'medium',
          ));
          if (created != null) results.add(created);
        }
      }
      return results;
    } catch (e) {
      debugPrint('ChecklistService.generateFromAI error: $e');
      return [];
    }
  }
}

// ── Providers ──

final checklistServiceProvider =
    Provider<ChecklistService>((_) => ChecklistService.instance);

final tripChecklistsProvider =
    FutureProvider.family<List<ChecklistItem>, String>((ref, tripId) async {
  return ChecklistService.instance.getChecklist(tripId);
});
