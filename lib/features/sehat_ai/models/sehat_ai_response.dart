import 'citation_item.dart';

/// Structured response returned by the `sehat-ai` Supabase Edge Function.
class SehatAiResponse {
  final String answer;
  final List<CitationItem> citations;
  final Map<String, dynamic>? metadata;
  final bool persisted;

  const SehatAiResponse({
    required this.answer,
    this.citations = const [],
    this.metadata,
    this.persisted = true,
  });

  factory SehatAiResponse.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'] as List<dynamic>? ?? [];
    return SehatAiResponse(
      answer: json['answer'] as String? ?? '',
      citations: rawCitations
          .whereType<Map>()
          .map((c) => CitationItem.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      persisted: json['persisted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'answer': answer,
        'citations': citations.map((c) => c.toJson()).toList(),
        if (metadata != null) 'metadata': metadata,
        'persisted': persisted,
      };
}
