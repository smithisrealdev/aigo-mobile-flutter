import 'dart:convert';

/// Represents an offline mutation that needs to be synced.
class PendingChange {
  final String table;
  final String operation; // 'insert' | 'update' | 'delete'
  final Map<String, dynamic> data;
  final DateTime timestamp;

  PendingChange({
    required this.table,
    required this.operation,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'table': table,
        'operation': operation,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PendingChange.fromJson(Map<String, dynamic> json) => PendingChange(
        table: json['table'] as String,
        operation: json['operation'] as String,
        data: json['data'] as Map<String, dynamic>,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  String encode() => jsonEncode(toJson());

  static PendingChange decode(String raw) =>
      PendingChange.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
