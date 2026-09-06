import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_conversation_model.dart';
import '../models/chat_message.dart';
import '../models/sehat_ai_response.dart';
import '../../home/data/patient_home_repository.dart';

/// Exception thrown for Sehat AI specific errors.
class SehatAiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const SehatAiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

/// Repository responsible for Sehat AI communication via Supabase Edge Functions
/// and multi-chat conversation history management via `public.sehat_ai_conversations`
/// and `public.sehat_ai_chats`.
///
/// Security Guardrails:
/// - Never accepts or handles Gemini API keys or service-role keys.
/// - Authenticated user JWT is passed explicitly via Authorization header.
/// - Database reads and mutations strictly scoped to `user_id = auth.uid()` under RLS.
class SehatAiRepository {
  final SupabaseClient? _clientOverride;
  final PatientHomeRepository? _homeRepoOverride;

  SehatAiRepository({
    SupabaseClient? client,
    PatientHomeRepository? homeRepository,
  })  : _clientOverride = client,
        _homeRepoOverride = homeRepository;

  static final SehatAiRepository instance = SehatAiRepository();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    return Supabase.instance.client;
  }

  PatientHomeRepository get _homeRepo {
    final override = _homeRepoOverride;
    if (override != null) return override;
    return _clientOverride != null
        ? PatientHomeRepository(client: _clientOverride)
        : PatientHomeRepository.instance;
  }

  /// Current authenticated user ID (null if unauthenticated).
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the patient display name using the shared PatientHomeRepository.
  Future<String> getPatientName() async {
    return _homeRepo.getPatientName();
  }

  /// Fetches all chat conversations for the current patient.
  /// Fetches all chat conversations for the current patient.
  Future<List<ChatConversationModel>> getConversations() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> data = await _client
          .from('sehat_ai_conversations')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return data
          .whereType<Map>()
          .map((row) => ChatConversationModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('[SehatAiRepository] getConversations notice: $e');
      return [];
    }
  }

  /// Creates a new conversation thread for the current patient.
  Future<ChatConversationModel> createConversation({String? title}) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw const SehatAiException('Authentication required to start a chat.');
    }

    try {
      final response = await _client
          .from('sehat_ai_conversations')
          .insert({
            'user_id': userId,
            'title': title?.trim().isNotEmpty == true ? title!.trim() : 'New Conversation',
          })
          .select()
          .single();

      return ChatConversationModel.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('[SehatAiRepository] createConversation error: $e');
      throw const SehatAiException(
        'Unable to start new chat conversation. Please try again.',
        code: 'CREATE_CONVERSATION_FAILED',
      );
    }
  }

  /// Deletes a specific conversation thread and its associated chat messages.
  Future<bool> deleteConversation(String conversationId) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty || conversationId.isEmpty) return false;

    try {
      // 1. Delete associated messages
      await _client
          .from('sehat_ai_chats')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      // 2. Delete conversation record
      await _client
          .from('sehat_ai_conversations')
          .delete()
          .eq('id', conversationId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('[SehatAiRepository] deleteConversation error: $e');
      return false;
    }
  }

  /// Updates conversation title.
  Future<void> updateConversationTitle(String conversationId, String title) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty || conversationId.isEmpty) return;

    try {
      await _client
          .from('sehat_ai_conversations')
          .update({
            'title': title.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[SehatAiRepository] updateConversationTitle error: $e');
    }
  }

  /// Loads chronological chat history for a specific conversation.
  Future<List<ChatMessage>> loadChatHistory({
    String? conversationId,
    int limit = 50,
  }) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    try {
      var query = _client
          .from('sehat_ai_chats')
          .select('id, conversation_id, sender, message, metadata, created_at')
          .eq('user_id', userId);

      if (conversationId != null && conversationId.isNotEmpty) {
        query = query.eq('conversation_id', conversationId);
      }

      final List<dynamic> data =
          await query.order('created_at', ascending: true).limit(limit);

      debugPrint(
        '[SehatAiRepository] loadChatHistory: convId=$conversationId, '
        'userId=${userId.substring(0, userId.length > 8 ? 8 : userId.length)}..., '
        'rowsReturned=${data.length}',
      );

      final messages = data
          .whereType<Map>()
          .map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      debugPrint(
        '[SehatAiRepository] loadChatHistory: parsedMessages=${messages.length}',
      );

      return messages;
    } catch (e) {
      debugPrint('[SehatAiRepository] loadChatHistory error: $e');
      throw const SehatAiException(
        'Unable to load conversation history. Please try again.',
        code: 'LOAD_HISTORY_FAILED',
      );
    }
  }

  /// Sends a message to the deployed `sehat-ai` Supabase Edge Function.
  Future<SehatAiResponse> sendMessage(
    String message, {
    List<ChatMessage>? sessionHistory,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const SehatAiException(
        'Please enter a valid message.',
        statusCode: 400,
        code: 'INVALID_REQUEST',
      );
    }

    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken;
    final userEmail = session?.user.email ?? _client.auth.currentUser?.email ?? 'unknown';

    debugPrint(
      '[SehatAiRepository] Invoking sehat-ai: sessionExists=${session != null}, '
      'hasAccessToken=${accessToken != null && accessToken.isNotEmpty}, '
      'userEmail=$userEmail, inSessionMessages=${sessionHistory?.length ?? 0}',
    );

    if (accessToken == null || accessToken.isEmpty) {
      throw const SehatAiException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
        code: 'UNAUTHORIZED',
      );
    }

    try {
      final bodyPayload = <String, dynamic>{
        'message': trimmed,
      };

      if (sessionHistory != null && sessionHistory.isNotEmpty) {
        bodyPayload['history'] = sessionHistory
            .map((msg) => {
                  'sender': msg.sender == MessageSender.ai ? 'ai' : 'user',
                  'message': msg.text,
                })
            .toList();
      }

      final FunctionResponse response = await _client.functions.invoke(
        'sehat-ai',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: bodyPayload,
      );

      final status = response.status;
      final dynamic rawData = response.data;

      debugPrint('[SehatAiRepository] Edge Function HTTP response status: $status');

      if (status == 200) {
        Map<String, dynamic> dataMap;
        if (rawData is Map<String, dynamic>) {
          dataMap = rawData;
        } else if (rawData is Map) {
          dataMap = Map<String, dynamic>.from(rawData);
        } else if (rawData is String) {
          final decoded = json.decode(rawData);
          if (decoded is Map) {
            dataMap = Map<String, dynamic>.from(decoded);
          } else {
            throw const SehatAiException(
              'Unexpected response format from Sehat AI.',
              statusCode: 200,
            );
          }
        } else {
          throw const SehatAiException(
            'Unexpected response format from Sehat AI.',
            statusCode: 200,
          );
        }

        return SehatAiResponse.fromJson(dataMap);
      }

      // Handle non-200 responses mapped safely
      if (status == 401) {
        throw const SehatAiException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
          code: 'UNAUTHORIZED',
        );
      } else if (status == 400) {
        throw const SehatAiException(
          'Please enter a valid message.',
          statusCode: 400,
          code: 'INVALID_REQUEST',
        );
      } else if (status == 502 || status == 500) {
        throw const SehatAiException(
          'Sehat AI is temporarily unavailable. Please try again.',
          statusCode: 502,
          code: 'AI_PROVIDER_ERROR',
        );
      } else {
        throw SehatAiException(
          'Unable to connect to Sehat AI. Please check your connection and try again.',
          statusCode: status,
        );
      }
    } on FunctionException catch (fe) {
      debugPrint('[SehatAiRepository] FunctionException status: ${fe.status}, error: ${fe.details}');
      if (fe.status == 401) {
        throw const SehatAiException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
          code: 'UNAUTHORIZED',
        );
      } else if (fe.status == 400) {
        throw const SehatAiException(
          'Please enter a valid message.',
          statusCode: 400,
          code: 'INVALID_REQUEST',
        );
      } else if (fe.status == 502 || fe.status == 500) {
        throw const SehatAiException(
          'Sehat AI is temporarily unavailable. Please try again.',
          statusCode: 502,
          code: 'AI_PROVIDER_ERROR',
        );
      }
      throw SehatAiException(
        'Unable to connect to Sehat AI. Please check your connection and try again.',
        statusCode: fe.status,
      );
    } catch (e) {
      if (e is SehatAiException) rethrow;
      debugPrint('[SehatAiRepository] Exception: ${e.runtimeType}: $e');
      throw const SehatAiException(
        'Unable to connect to Sehat AI. Please check your connection and try again.',
      );
    }
  }

  /// Clears chat history for a specific conversation or all messages for current user.
  Future<bool> clearChatHistory({String? conversationId}) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) return false;

    try {
      var query = _client.from('sehat_ai_chats').delete().eq('user_id', userId);
      if (conversationId != null && conversationId.isNotEmpty) {
        query = query.eq('conversation_id', conversationId);
      }
      await query;
      return true;
    } catch (e) {
      debugPrint('[SehatAiRepository] clearChatHistory error: $e');
      return false;
    }
  }
}
