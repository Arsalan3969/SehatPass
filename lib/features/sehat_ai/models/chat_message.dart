import 'dart:convert';
import 'citation_item.dart';

/// Identifies who sent a chat message.
enum MessageSender { user, ai }

/// A single chat message in the local conversation.
class ChatMessage {
  final String? id;
  final String? conversationId;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final List<CitationItem> citations;

  ChatMessage({
    this.id,
    this.conversationId,
    required this.text,
    required this.sender,
    DateTime? timestamp,
    this.citations = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => sender == MessageSender.user;

  /// Creates a ChatMessage from a `public.sehat_ai_chats` Supabase record.
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final senderStr = map['sender'] as String? ?? 'user';

    Map<String, dynamic> metadata = {};
    if (map['metadata'] is Map) {
      metadata = Map<String, dynamic>.from(map['metadata'] as Map);
    } else if (map['metadata'] is String && (map['metadata'] as String).isNotEmpty) {
      try {
        final decoded = json.decode(map['metadata'] as String);
        if (decoded is Map) {
          metadata = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final rawCitations = metadata['citations'] is List ? metadata['citations'] as List : const [];

    DateTime ts = DateTime.now();
    if (map['created_at'] != null) {
      ts = DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
    }

    return ChatMessage(
      id: map['id']?.toString(),
      conversationId: map['conversation_id']?.toString(),
      text: map['message'] as String? ?? '',
      sender: senderStr.toLowerCase() == 'ai'
          ? MessageSender.ai
          : MessageSender.user,
      timestamp: ts,
      citations: rawCitations
          .whereType<Map>()
          .map((c) => CitationItem.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }
}
