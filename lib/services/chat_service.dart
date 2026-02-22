import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

// ──────────────────────────────────────────────
// Chat service — calls Supabase edge functions
// ──────────────────────────────────────────────

/// A single chat message (local model for UI).
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final String? intent;
  final Map<String, dynamic>? responseData;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.intent,
    this.responseData,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
}

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Send a message to the AI chat edge function.
  ///
  /// The edge function name should match what's deployed on the mobile
  /// Supabase project (e.g. `chat`, `ai-chat`, etc.).
  /// Adjust the function name as needed.
  Future<ChatMessage> sendMessage({
    required String message,
    String? conversationId,
    String? tripId,
    Map<String, double>? currentLocation,
  }) async {
    final body = {
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
      if (tripId != null) 'trip_id': tripId,
      if (currentLocation != null) 'current_location': currentLocation,
    };

    final response = await _client.functions.invoke(
      'trip-chat',
      body: body,
    );

    if (response.status != 200) {
      throw Exception(
          'Chat request failed (${response.status}): ${response.data}');
    }

    final data = response.data is String
        ? jsonDecode(response.data) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;

    return ChatMessage(
      role: 'assistant',
      content: data['response'] as String? ?? data['message'] as String? ?? '',
      intent: data['intent'] as String?,
      responseData: data,
    );
  }

  /// Submit feedback on an AI response.
  Future<void> submitFeedback({
    required String feedbackType,
    required String messageContent,
    String? sessionId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('chat_feedback').insert({
      if (uid != null) 'user_id': uid,
      if (sessionId != null) 'session_id': sessionId,
      'feedback_type': feedbackType,
      'message_content': messageContent,
    });
  }
}

// ──────────────────────────────────────────────
// Riverpod providers
// ──────────────────────────────────────────────

final chatServiceProvider = Provider((_) => ChatService.instance);

/// Holds the current conversation state.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final String? conversationId;

  ChatState({
    required this.messages,
    this.isLoading = false,
    this.error,
    this.conversationId,
  });

  factory ChatState.initial() => ChatState(messages: []);

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? conversationId,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        conversationId: conversationId ?? this.conversationId,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => ChatState.initial();

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(role: 'user', content: text);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final reply = await ChatService.instance.sendMessage(
        message: text,
        conversationId: state.conversationId,
      );

      final newConvId = reply.responseData?['conversation_id'] as String? ??
          state.conversationId;

      state = state.copyWith(
        messages: [...state.messages, reply],
        isLoading: false,
        conversationId: newConvId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearConversation() {
    state = ChatState.initial();
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
