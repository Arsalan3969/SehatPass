/// Represents a medical reference citation returned by Sehat AI RAG retrieval.
class CitationItem {
  final String title;
  final String source;
  final String sourceUrl;
  final double similarity;

  const CitationItem({
    required this.title,
    required this.source,
    required this.sourceUrl,
    required this.similarity,
  });

  factory CitationItem.fromJson(Map<String, dynamic> json) {
    return CitationItem(
      title: json['title'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'source': source,
        'source_url': sourceUrl,
        'similarity': similarity,
      };
}
