import 'citation_item.dart';

/// Structured response returned by the `sehat-ai` Supabase Edge Function.
class SehatAiResponse {
  final String answer;
  final List<CitationItem> citations;
  final Map<String, dynamic>? metadata;

  const SehatAiResponse({
    required this.answer,
    this.citations = const [],
    this.metadata,
  });

  factory SehatAiResponse.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'] as List<dynamic>? ?? [];
    return SehatAiResponse(
      answer: json['answer'] as String? ?? '',
      citations: rawCitations
          .whereType<Map<String, dynamic>>()
          .map((c) => CitationItem.fromJson(c))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'answer': answer,
        'citations': citations.map((c) => c.toJson()).toList(),
        if (metadata != null) 'metadata': metadata,
      };
}
