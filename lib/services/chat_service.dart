import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import 'auth_service.dart';

// ──────────────────────────────────────────────
// Chat service — matches lib/chat.ts + useTripChat.tsx
// Uses streaming HTTP fetch to trip-chat, NOT supabase.functions.invoke
// ──────────────────────────────────────────────

// Error codes matching website ERROR_CODES
class ChatErrorCodes {
  static const sessionExpired = 'ERROR_SESSION_EXPIRED';
  static const rateLimit = 'ERROR_RATE_LIMIT';
  static const creditsExhausted = 'ERROR_CREDITS_EXHAUSTED';
  static const timeout = 'ERROR_TIMEOUT';
  static const network = 'ERROR_NETWORK';
  static const streamInterrupted = 'ERROR_STREAM_INTERRUPTED';
  static const serverError = 'ERROR_SERVER';
}

/// A single chat message.
class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isError;
  final String? errorCode;
  final Map<String, dynamic>? responseData;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isError = false,
    this.errorCode,
    this.responseData,
  })  : id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';

  ChatMessage copyWith({String? content}) => ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        timestamp: timestamp,
        isError: isError,
        errorCode: errorCode,
        responseData: responseData,
      );

  static String _generateId() =>
      Random().nextInt(1 << 30).toRadixString(36).padLeft(8, '0');
}

/// Trip info extracted from chat messages (matches useTripChat.tsx extractTripInfo).
class ExtractedTripInfo {
  String? destination;
  int? duration;
  String? budget;
  String? tripStyle;
  String? travelers;

  bool get hasMinimumInfo => destination != null;

  Map<String, dynamic> toJson() => {
        if (destination != null) 'destination': destination,
        if (duration != null) 'duration': duration,
        if (budget != null) 'budget': budget,
        if (tripStyle != null) 'tripStyle': tripStyle,
        if (travelers != null) 'travelers': travelers,
      };
}

/// Trip summary parsed from AI [TRIP_SUMMARY] blocks.
class TripSummary {
  final String? destination;
  final List<String>? destinations;
  final int? duration;
  final Map<String, dynamic>? budget;
  final Map<String, dynamic>? travelers;
  final List<String>? tripStyle;
  final List<String>? preferences;
  final List<String>? restrictions;
  final List<String>? dietaryRestrictions;
  final List<String>? mustVisit;
  final List<String>? mustAvoid;
  final List<String>? specialInterests;

  TripSummary({
    this.destination,
    this.destinations,
    this.duration,
    this.budget,
    this.travelers,
    this.tripStyle,
    this.preferences,
    this.restrictions,
    this.dietaryRestrictions,
    this.mustVisit,
    this.mustAvoid,
    this.specialInterests,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) => TripSummary(
        destination: json['destination'] as String?,
        destinations: (json['destinations'] as List?)?.cast<String>(),
        duration: json['duration'] as int?,
        budget: json['budget'] as Map<String, dynamic>?,
        travelers: json['travelers'] as Map<String, dynamic>?,
        tripStyle: (json['tripStyle'] as List?)?.cast<String>(),
        preferences: (json['preferences'] as List?)?.cast<String>(),
        restrictions: (json['restrictions'] as List?)?.cast<String>(),
        dietaryRestrictions:
            (json['dietaryRestrictions'] as List?)?.cast<String>(),
        mustVisit: (json['mustVisit'] as List?)?.cast<String>(),
        mustAvoid: (json['mustAvoid'] as List?)?.cast<String>(),
        specialInterests:
            (json['specialInterests'] as List?)?.cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        if (destination != null) 'destination': destination,
        if (destinations != null) 'destinations': destinations,
        if (duration != null) 'duration': duration,
        if (budget != null) 'budget': budget,
        if (travelers != null) 'travelers': travelers,
        if (tripStyle != null) 'tripStyle': tripStyle,
        if (preferences != null) 'preferences': preferences,
        if (restrictions != null) 'restrictions': restrictions,
        if (dietaryRestrictions != null)
          'dietaryRestrictions': dietaryRestrictions,
        if (mustVisit != null) 'mustVisit': mustVisit,
        if (mustAvoid != null) 'mustAvoid': mustAvoid,
        if (specialInterests != null) 'specialInterests': specialInterests,
      };
}

// Timeout configuration matching website
const _chatInitialTimeoutMs = 30000;
const _chatStreamTimeoutMs = 60000;
const _maxAutoRetries = 2;
const _retryDelayMs = 1500;

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final Dio _dio = Dio();

  String get _chatUrl =>
      '${SupabaseConfig.supabaseUrl}/functions/v1/trip-chat';

  /// Stream chat with SSE, matching website's streamChat().
  ///
  /// [messages] — conversation history as {role, content}.
  /// [onDelta] — called for each text chunk.
  /// [onDone] — called when stream completes.
  /// [onError] — called on error with error code.
  /// [onRetryAttempt] — called when auto-retrying.
  /// [cancelToken] — optional Dio cancel token.
  /// [maxRetries] — auto-retry attempts (default 2).
  Future<void> streamChat({
    required List<Map<String, String>> messages,
    required void Function(String delta) onDelta,
    required void Function() onDone,
    required void Function(String errorCode, {bool isRetrying}) onError,
    void Function(int attempt, int maxRetries)? onRetryAttempt,
    CancelToken? cancelToken,
    int maxRetries = _maxAutoRetries,
  }) async {
    try {
      final token = await AuthService.instance.getAccessToken();

      final response = await _dio.post<ResponseBody>(
        _chatUrl,
        data: jsonEncode({'messages': messages}),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.supabaseAnonKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
          responseType: ResponseType.stream,
          sendTimeout: Duration(milliseconds: _chatInitialTimeoutMs),
          receiveTimeout: Duration(milliseconds: _chatStreamTimeoutMs),
        ),
        cancelToken: cancelToken,
      );

      final statusCode = response.statusCode ?? 0;

      if (statusCode != 200) {
        String errorCode;
        if (statusCode == 401) {
          // Try refresh and retry
          if (maxRetries > 0) {
            final refreshed =
                await SupabaseConfig.client.auth.refreshSession();
            if (refreshed.session != null) {
              return streamChat(
                messages: messages,
                onDelta: onDelta,
                onDone: onDone,
                onError: onError,
                onRetryAttempt: onRetryAttempt,
                cancelToken: cancelToken,
                maxRetries: maxRetries - 1,
              );
            }
          }
          errorCode = ChatErrorCodes.sessionExpired;
        } else if (statusCode == 429) {
          errorCode = ChatErrorCodes.rateLimit;
        } else if (statusCode == 402) {
          errorCode = ChatErrorCodes.creditsExhausted;
        } else {
          errorCode = ChatErrorCodes.serverError;
        }

        // Auto-retry for server errors
        final isRetryable = statusCode >= 500 || statusCode == 429;
        if (isRetryable && maxRetries > 0) {
          onRetryAttempt?.call(
              _maxAutoRetries - maxRetries + 1, _maxAutoRetries);
          onError(errorCode, isRetrying: true);
          await Future.delayed(
              const Duration(milliseconds: _retryDelayMs));
          return streamChat(
            messages: messages,
            onDelta: onDelta,
            onDone: onDone,
            onError: onError,
            onRetryAttempt: onRetryAttempt,
            cancelToken: cancelToken,
            maxRetries: maxRetries - 1,
          );
        }

        onError(errorCode, isRetrying: false);
        onDone();
        return;
      }

      // Parse SSE stream
      final stream = response.data!.stream;
      final decoder = const Utf8Decoder();
      var textBuffer = '';
      var lastActivityTime = DateTime.now();

      await for (final chunk in stream) {
        lastActivityTime = DateTime.now();
        textBuffer += decoder.convert(chunk);

        int newlineIndex;
        while ((newlineIndex = textBuffer.indexOf('\n')) != -1) {
          var line = textBuffer.substring(0, newlineIndex);
          textBuffer = textBuffer.substring(newlineIndex + 1);

          if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
          if (line.startsWith(':') || line.trim().isEmpty) continue;
          if (!line.startsWith('data: ')) continue;

          final jsonStr = line.substring(6).trim();
          if (jsonStr == '[DONE]') {
            onDone();
            return;
          }

          try {
            final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
            final choices = parsed['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta =
                  (choices[0] as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null) onDelta(content);
            }
          } catch (_) {
            // Incomplete JSON — put back and wait
            textBuffer = '$line\n$textBuffer';
            break;
          }
        }

        // Check stream timeout
        if (DateTime.now().difference(lastActivityTime).inMilliseconds >
            _chatStreamTimeoutMs) {
          onError(ChatErrorCodes.timeout, isRetrying: false);
          onDone();
          return;
        }
      }

      // Final flush
      if (textBuffer.trim().isNotEmpty) {
        for (var raw in textBuffer.split('\n')) {
          if (raw.isEmpty) continue;
          if (raw.endsWith('\r')) raw = raw.substring(0, raw.length - 1);
          if (raw.startsWith(':') || raw.trim().isEmpty) continue;
          if (!raw.startsWith('data: ')) continue;
          final jsonStr = raw.substring(6).trim();
          if (jsonStr == '[DONE]') continue;
          try {
            final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
            final choices = parsed['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta =
                  (choices[0] as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null) onDelta(content);
            }
          } catch (_) {
            // ignore
          }
        }
      }

      onDone();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        if (maxRetries > 0) {
          onRetryAttempt?.call(
              _maxAutoRetries - maxRetries + 1, _maxAutoRetries);
          onError(ChatErrorCodes.timeout, isRetrying: true);
          await Future.delayed(
              const Duration(milliseconds: _retryDelayMs));
          return streamChat(
            messages: messages,
            onDelta: onDelta,
            onDone: onDone,
            onError: onError,
            onRetryAttempt: onRetryAttempt,
            cancelToken: cancelToken,
            maxRetries: maxRetries - 1,
          );
        }
        onError(ChatErrorCodes.timeout, isRetrying: false);
      } else if (e.type == DioExceptionType.cancel) {
        // User cancelled — no error
      } else if (e.type == DioExceptionType.connectionError) {
        onError(ChatErrorCodes.network, isRetrying: false);
      } else {
        onError(ChatErrorCodes.serverError, isRetrying: false);
      }
      onDone();
    } catch (e) {
      debugPrint('Chat stream error: $e');
      onError(ChatErrorCodes.serverError, isRetrying: false);
      onDone();
    }
  }

  /// Non-streaming convenience method for backward compatibility.
  /// Collects the full streamed response and returns a ChatMessage.
  Future<ChatMessage> sendMessage({
    required String message,
    String? conversationId,
    String? tripId,
  }) async {
    final messages = [
      {'role': 'user', 'content': message},
    ];
    final buffer = StringBuffer();
    final completer = Completer<ChatMessage>();

    await streamChat(
      messages: messages,
      onDelta: (delta) => buffer.write(delta),
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(ChatMessage(
            role: 'assistant',
            content: buffer.toString(),
          ));
        }
      },
      onError: (errorCode, {bool isRetrying = false}) {
        if (!isRetrying && !completer.isCompleted) {
          completer.completeError(Exception(errorCode));
        }
      },
    );

    return completer.future;
  }

  /// Submit feedback on an AI response.
  Future<void> submitFeedback({
    required String feedbackType,
    required String messageContent,
    String? sessionId,
  }) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    await SupabaseConfig.client.from('chat_feedback').insert({
      if (uid != null) 'user_id': uid,
      if (sessionId != null) 'session_id': sessionId,
      'feedback_type': feedbackType,
      'message_content': messageContent,
    });
  }

  // ── Domain-specific chat edge functions ──

  /// Flight search chat via edge function.
  Future<Map<String, dynamic>> flightChat(String message,
      {Map<String, dynamic>? context}) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'flight-chat',
        body: {
          'message': message,
          if (context != null) 'context': context,
        },
      );
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('[ChatService] flightChat error: $e');
      return {'error': e.toString()};
    }
  }

  /// Hotel search chat via edge function.
  Future<Map<String, dynamic>> hotelChat(String message,
      {Map<String, dynamic>? context}) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'hotel-chat',
        body: {
          'message': message,
          if (context != null) 'context': context,
        },
      );
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('[ChatService] hotelChat error: $e');
      return {'error': e.toString()};
    }
  }

  /// Itinerary-specific chat context via edge function.
  Future<Map<String, dynamic>> itineraryChat(String message,
      {String? tripId, Map<String, dynamic>? itineraryContext}) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'itinerary-chat',
        body: {
          'message': message,
          if (tripId != null) 'tripId': tripId,
          if (itineraryContext != null) 'context': itineraryContext,
        },
      );
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('[ChatService] itineraryChat error: $e');
      return {'error': e.toString()};
    }
  }
}

// ──────────────────────────────────────────────
// Trip info extraction — matches useTripChat.tsx
// ──────────────────────────────────────────────

/// Extract trip info from message text (destination, duration, budget, etc.)
ExtractedTripInfo extractTripInfo(List<ChatMessage> messages) {
  final info = ExtractedTripInfo();
  final allText =
      messages.map((m) => m.content.toLowerCase()).join(' ');

  // Destination patterns
  final destPatterns = [
    RegExp(r'(?:go|travel|visit|trip)\s+to\s+([A-Z][a-zA-Z\s]+)', caseSensitive: false),
    RegExp(r'(?:heading|going)\s+to\s+([A-Z][a-zA-Z\s]+)', caseSensitive: false),
    RegExp(r'(?:destination|place)\s*:?\s*([A-Z][a-zA-Z\s]+)', caseSensitive: false),
  ];
  for (final p in destPatterns) {
    final m = p.firstMatch(allText);
    if (m != null) {
      info.destination = m.group(1)?.trim();
      break;
    }
  }

  // Duration
  final durMatch = RegExp(r'(\d+)\s*(?:day|night)', caseSensitive: false)
      .firstMatch(allText);
  if (durMatch != null) {
    info.duration = int.tryParse(durMatch.group(1)!);
  }

  // Budget
  final budgetMatch = RegExp(
          r'(?:budget|spend)\s*(?:is|of|around|about)?\s*[\$฿€£]?\s*([\d,]+)',
          caseSensitive: false)
      .firstMatch(allText);
  if (budgetMatch != null) {
    info.budget = budgetMatch.group(1)?.replaceAll(',', '');
  }

  return info;
}

/// Parse TRIP_SUMMARY block from AI response.
TripSummary? parseTripSummary(String text) {
  final startTag = '[TRIP_SUMMARY]';
  final endTag = '[/TRIP_SUMMARY]';
  final startIdx = text.indexOf(startTag);
  final endIdx = text.indexOf(endTag);
  if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) return null;

  final jsonStr =
      text.substring(startIdx + startTag.length, endIdx).trim();
  try {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return TripSummary.fromJson(json);
  } catch (_) {
    return null;
  }
}

/// Check if AI response contains READY_TO_GENERATE signal.
bool isReadyToGenerate(String text) {
  return text.contains('[READY_TO_GENERATE]');
}

/// Strip TRIP_SUMMARY and READY_TO_GENERATE tags from display text.
String cleanDisplayText(String text) {
  return text
      .replaceAll(RegExp(r'\[TRIP_SUMMARY\][\s\S]*?\[/TRIP_SUMMARY\]'), '')
      .replaceAll('[READY_TO_GENERATE]', '')
      .trim();
}

// ──────────────────────────────────────────────
// Riverpod providers
// ──────────────────────────────────────────────

final chatServiceProvider = Provider((_) => ChatService.instance);

/// Chat conversation state.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isStreaming;
  final String? error;
  final String? errorCode;
  final ExtractedTripInfo tripInfo;
  final TripSummary? tripSummary;
  final bool readyToGenerate;

  ChatState({
    required this.messages,
    this.isLoading = false,
    this.isStreaming = false,
    this.error,
    this.errorCode,
    ExtractedTripInfo? tripInfo,
    this.tripSummary,
    this.readyToGenerate = false,
  }) : tripInfo = tripInfo ?? ExtractedTripInfo();

  factory ChatState.initial() => ChatState(messages: []);

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
    String? error,
    String? errorCode,
    ExtractedTripInfo? tripInfo,
    TripSummary? tripSummary,
    bool? readyToGenerate,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isStreaming: isStreaming ?? this.isStreaming,
        error: error,
        errorCode: errorCode,
        tripInfo: tripInfo ?? this.tripInfo,
        tripSummary: tripSummary ?? this.tripSummary,
        readyToGenerate: readyToGenerate ?? this.readyToGenerate,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  CancelToken? _cancelToken;

  @override
  ChatState build() => ChatState.initial();

  /// Send a message and stream the response.
  Future<void> sendMessage(String text) async {
    // Add user message
    final userMsg = ChatMessage(role: 'user', content: text);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      isStreaming: true,
      error: null,
      errorCode: null,
    );

    // Prepare assistant placeholder
    final assistantMsg = ChatMessage(role: 'assistant', content: '');
    state = state.copyWith(
      messages: [...state.messages, assistantMsg],
    );

    final buffer = StringBuffer();
    _cancelToken = CancelToken();

    // Build messages array for API
    final apiMessages = state.messages
        .where((m) => !m.isError)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    // Remove the empty assistant placeholder from API messages
    if (apiMessages.isNotEmpty && apiMessages.last['content']!.isEmpty) {
      apiMessages.removeLast();
    }

    await ChatService.instance.streamChat(
      messages: apiMessages,
      cancelToken: _cancelToken,
      onDelta: (delta) {
        buffer.write(delta);
        final updatedContent = buffer.toString();

        // Update the last message (assistant) in place
        final msgs = List<ChatMessage>.from(state.messages);
        msgs[msgs.length - 1] = msgs.last.copyWith(content: updatedContent);

        // Check for TRIP_SUMMARY and READY_TO_GENERATE
        final summary = parseTripSummary(updatedContent) ?? state.tripSummary;
        final ready =
            isReadyToGenerate(updatedContent) || state.readyToGenerate;

        state = state.copyWith(
          messages: msgs,
          tripSummary: summary,
          readyToGenerate: ready,
        );
      },
      onDone: () {
        // Extract trip info from all messages
        final info = extractTripInfo(state.messages);

        state = state.copyWith(
          isLoading: false,
          isStreaming: false,
          tripInfo: info,
        );
      },
      onError: (errorCode, {bool isRetrying = false}) {
        if (!isRetrying) {
          // Remove the empty assistant message on error
          final msgs = List<ChatMessage>.from(state.messages);
          if (msgs.isNotEmpty && msgs.last.role == 'assistant' && msgs.last.content.isEmpty) {
            msgs.removeLast();
          }
          // Add error message
          msgs.add(ChatMessage(
            role: 'assistant',
            content: _errorMessage(errorCode),
            isError: true,
            errorCode: errorCode,
          ));

          state = state.copyWith(
            messages: msgs,
            isLoading: false,
            isStreaming: false,
            error: _errorMessage(errorCode),
            errorCode: errorCode,
          );
        }
      },
    );
  }

  /// Cancel ongoing stream.
  void cancelStream() {
    _cancelToken?.cancel('User cancelled');
    _cancelToken = null;
    state = state.copyWith(isLoading: false, isStreaming: false);
  }

  /// Clear conversation.
  void clearConversation() {
    _cancelToken?.cancel();
    state = ChatState.initial();
  }

  String _errorMessage(String code) {
    switch (code) {
      case ChatErrorCodes.sessionExpired:
        return 'Session expired. Please sign in again.';
      case ChatErrorCodes.rateLimit:
        return 'Too many requests. Please wait a moment.';
      case ChatErrorCodes.creditsExhausted:
        return 'AI credits exhausted. Please upgrade your plan.';
      case ChatErrorCodes.timeout:
        return 'Request timed out. Please try again.';
      case ChatErrorCodes.network:
        return 'Network error. Please check your connection.';
      case ChatErrorCodes.streamInterrupted:
        return 'Stream interrupted. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
