import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Parses and applies AIGO_PATCH operations from AI itinerary chat responses.
/// Mirrors web's src/lib/itineraryPatch.ts behavior.

class PatchOperation {
  final String
  operation; // add_place, delete_place, replace_day, reorder_places, update_place, move_place, restore_place, update_day
  final int? dayIndex;
  final int? placeIndex;
  final String? placeId;
  final int? toDay;
  final int? toIndex;
  final int? dayNumber;
  final int? deletedIndex;
  final Map<String, dynamic>? fields;
  final Map<String, dynamic>? place;
  final List<Map<String, dynamic>>? places;
  final Map<String, dynamic> raw;

  PatchOperation({
    required this.operation,
    this.dayIndex,
    this.placeIndex,
    this.placeId,
    this.toDay,
    this.toIndex,
    this.dayNumber,
    this.deletedIndex,
    this.fields,
    this.place,
    this.places,
    required this.raw,
  });

  factory PatchOperation.fromJson(Map<String, dynamic> json) {
    return PatchOperation(
      operation: json['operation'] ?? json['op'] ?? 'unknown',
      dayIndex: json['dayIndex'] as int?,
      placeIndex: json['placeIndex'] as int?,
      placeId: json['placeId']?.toString(),
      toDay: json['toDay'] as int?,
      toIndex: json['toIndex'] as int?,
      dayNumber: json['dayNumber'] as int?,
      deletedIndex: json['deletedIndex'] as int?,
      fields: json['fields'] as Map<String, dynamic>?,
      place: json['place'] as Map<String, dynamic>?,
      places: (json['places'] as List?)?.cast<Map<String, dynamic>>(),
      raw: json,
    );
  }

  @override
  String toString() => 'PatchOperation($operation, day=$dayIndex)';
}

class PatchResult {
  final List<PatchOperation> operations;
  final String displayText; // Text with PATCH blocks removed
  final List<String> suggestions; // Follow-up suggestions

  const PatchResult({
    required this.operations,
    required this.displayText,
    this.suggestions = const [],
  });

  bool get hasPatches => operations.isNotEmpty;
}

class ItineraryPatchService {
  static final _patchRegex = RegExp(
    r'<<<AIGO_PATCH>>>([\s\S]*?)<<<(?:END_)?AIGO_PATCH>>>',
  );
  static final _suggestionsRegex = RegExp(
    r'<<<AIGO_SUGGESTIONS>>>([\s\S]*?)<<<(?:END_)?AIGO_SUGGESTIONS>>>',
  );

  /// Parse PATCH and SUGGESTIONS blocks from AI response text.
  static PatchResult parse(String text) {
    final operations = <PatchOperation>[];
    final suggestions = <String>[];

    // Extract PATCH blocks
    for (final match in _patchRegex.allMatches(text)) {
      final jsonStr = match.group(1)?.trim() ?? '';
      try {
        final json = jsonDecode(jsonStr);
        if (json is Map<String, dynamic>) {
          operations.add(PatchOperation.fromJson(json));
        } else if (json is List) {
          for (final item in json) {
            if (item is Map<String, dynamic>) {
              operations.add(PatchOperation.fromJson(item));
            }
          }
        }
      } catch (e) {
        debugPrint('[ItineraryPatch] Failed to parse PATCH JSON: $e');
      }
    }

    // Extract SUGGESTIONS blocks
    for (final match in _suggestionsRegex.allMatches(text)) {
      final jsonStr = match.group(1)?.trim() ?? '';
      try {
        final json = jsonDecode(jsonStr);
        if (json is List) {
          for (final item in json) {
            if (item is String) suggestions.add(item);
          }
        }
      } catch (e) {
        debugPrint('[ItineraryPatch] Failed to parse SUGGESTIONS: $e');
      }
    }

    // Remove PATCH and SUGGESTIONS blocks from display text
    final displayText = text
        .replaceAll(_patchRegex, '')
        .replaceAll(_suggestionsRegex, '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return PatchResult(
      operations: operations,
      displayText: displayText,
      suggestions: suggestions,
    );
  }

  /// Apply patch operations to an itinerary data structure.
  /// Returns the updated itinerary.
  static Map<String, dynamic> applyPatches(
    Map<String, dynamic> itinerary,
    List<PatchOperation> patches,
  ) {
    var result = Map<String, dynamic>.from(itinerary);
    final days =
        (result['days'] as List?)
            ?.map((d) => Map<String, dynamic>.from(d as Map))
            .toList() ??
        [];

    // Helper: Find day index by day number (1-indexed usually)
    int findDayIndexByNumber(int dayNum) {
      return days.indexWhere((d) => d['day'] == dayNum);
    }

    // Helper: Find place location by placeId
    Map<String, int>? findPlaceLocation(String id) {
      for (int di = 0; di < days.length; di++) {
        final places = (days[di]['places'] as List?) ?? [];
        for (int pi = 0; pi < places.length; pi++) {
          if (places[pi]['id'] == id) {
            return {'dayIndex': di, 'placeIndex': pi};
          }
        }
      }
      return null;
    }

    for (final patch in patches) {
      try {
        switch (patch.operation) {
          case 'add_place':
            // Existing logic or using toDay
            int targetDayIdx = -1;
            if (patch.toDay != null) {
              targetDayIdx = findDayIndexByNumber(patch.toDay!);
            } else if (patch.dayIndex != null) {
              targetDayIdx = patch.dayIndex!;
            }

            if (targetDayIdx >= 0 &&
                targetDayIdx < days.length &&
                patch.place != null) {
              final places = (days[targetDayIdx]['places'] as List?) ?? [];
              final insertAt =
                  patch.toIndex ?? patch.placeIndex ?? places.length;

              // Ensure place has required fields and ID if missing
              final newPlace = Map<String, dynamic>.from(patch.place!);
              if (!newPlace.containsKey('id')) {
                newPlace['id'] = 'ai-${DateTime.now().millisecondsSinceEpoch}';
              }

              places.insert(insertAt.clamp(0, places.length), newPlace);
              days[targetDayIdx]['places'] = places;
            }
            break;

          case 'delete_place':
            if (patch.placeId != null) {
              final loc = findPlaceLocation(patch.placeId!);
              if (loc != null) {
                final places =
                    (days[loc['dayIndex']!]['places'] as List?) ?? [];
                places.removeAt(loc['placeIndex']!);
                days[loc['dayIndex']!]['places'] = places;
              }
            } else if (patch.dayIndex != null && patch.placeIndex != null) {
              final dayIdx = patch.dayIndex!;
              if (dayIdx >= 0 && dayIdx < days.length) {
                final places = (days[dayIdx]['places'] as List?) ?? [];
                if (patch.placeIndex! >= 0 &&
                    patch.placeIndex! < places.length) {
                  places.removeAt(patch.placeIndex!);
                  days[dayIdx]['places'] = places;
                }
              }
            }
            break;

          case 'update_place':
            if (patch.placeId != null && patch.fields != null) {
              final loc = findPlaceLocation(patch.placeId!);
              if (loc != null) {
                final places =
                    (days[loc['dayIndex']!]['places'] as List?) ?? [];
                final place = Map<String, dynamic>.from(
                  places[loc['placeIndex']!],
                );
                // Merge allowed fields
                for (final key in [
                  'name',
                  'category',
                  'startTime',
                  'endTime',
                  'duration',
                  'description',
                ]) {
                  if (patch.fields!.containsKey(key)) {
                    place[key] = patch.fields![key];
                  }
                }
                places[loc['placeIndex']!] = place;
                days[loc['dayIndex']!]['places'] = places;
              }
            }
            break;

          case 'move_place':
            if (patch.placeId != null && patch.toDay != null) {
              final from = findPlaceLocation(patch.placeId!);
              final toDayIndex = findDayIndexByNumber(patch.toDay!);

              if (from != null && toDayIndex != -1) {
                final sourcePlaces =
                    (days[from['dayIndex']!]['places'] as List?) ?? [];
                final targetPlaces =
                    (days[toDayIndex]['places'] as List?) ?? [];

                if (from['placeIndex']! >= 0 &&
                    from['placeIndex']! < sourcePlaces.length) {
                  final placeToMove = sourcePlaces.removeAt(
                    from['placeIndex']!,
                  );
                  days[from['dayIndex']!]['places'] = sourcePlaces;

                  final toIndex = patch.toIndex ?? targetPlaces.length;
                  targetPlaces.insert(
                    toIndex.clamp(0, targetPlaces.length),
                    placeToMove,
                  );
                  days[toDayIndex]['places'] = targetPlaces;
                }
              }
            }
            break;

          case 'restore_place':
            // Logic typically handled by the front-end directly via history
            debugPrint(
              '[ItineraryPatch] restore_place requested for deletedIndex: ${patch.deletedIndex}',
            );
            break;

          case 'update_day':
            if (patch.dayNumber != null && patch.fields != null) {
              final dayIndex = findDayIndexByNumber(patch.dayNumber!);
              if (dayIndex != -1) {
                if (patch.fields!['title'] != null) {
                  days[dayIndex]['title'] = patch.fields!['title'];
                }
              }
            }
            break;

          case 'replace_day':
            int targetDayIdx = -1;
            if (patch.dayNumber != null) {
              targetDayIdx = findDayIndexByNumber(patch.dayNumber!);
            } else if (patch.dayIndex != null) {
              targetDayIdx = patch.dayIndex!;
            }

            if (targetDayIdx >= 0 &&
                targetDayIdx < days.length &&
                patch.places != null) {
              final newPlaces = patch.places!.map((p) {
                final newP = Map<String, dynamic>.from(p);
                if (!newP.containsKey('id')) {
                  newP['id'] =
                      'ai-${DateTime.now().millisecondsSinceEpoch}-${p.hashCode}';
                }
                return newP;
              }).toList();

              days[targetDayIdx]['places'] = newPlaces;
              if (patch.fields != null && patch.fields!['title'] != null) {
                days[targetDayIdx]['title'] = patch.fields!['title'];
              } else if (patch.raw['title'] != null) {
                days[targetDayIdx]['title'] = patch.raw['title'];
              }
            }
            break;

          case 'reorder_places':
            if (patch.dayIndex != null && patch.places != null) {
              final dayIdx = patch.dayIndex!;
              if (dayIdx >= 0 && dayIdx < days.length) {
                days[dayIdx]['places'] = patch.places;
              }
            }
            break;

          default:
            debugPrint(
              '[ItineraryPatch] Unknown operation: ${patch.operation}',
            );
        }
      } catch (e) {
        debugPrint('[ItineraryPatch] Failed to apply patch: $patch — $e');
      }
    }

    result['days'] = days;
    return result;
  }
}
