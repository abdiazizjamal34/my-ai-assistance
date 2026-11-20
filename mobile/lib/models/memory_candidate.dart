class MemoryCandidate {
  const MemoryCandidate({
    required this.category,
    required this.title,
    required this.content,
    required this.importance,
    required this.confidence,
    required this.decision,
    this.expiresAt,
  });

  final String category;
  final String title;
  final String content;
  final String importance;
  final double confidence;
  final String decision;
  final DateTime? expiresAt;

  factory MemoryCandidate.fromJson(Map<String, dynamic> json) =>
      MemoryCandidate(
        category: json['category'] as String? ?? 'IMPORTANT_CONTEXT',
        title: json['title'] as String? ?? 'Suggested memory',
        content: json['content'] as String? ?? '',
        importance: json['importance'] as String? ?? 'MEDIUM',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.65,
        decision: json['decision'] as String? ?? 'ASK_CONFIRMATION',
        expiresAt: json['expiresAt'] is String
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
      );

  Map<String, dynamic> toMemoryJson() => {
    'category': category,
    'title': title,
    'content': content,
    'importance': importance,
    'source': 'USER',
    'confidence': confidence,
    'expiresAt': expiresAt?.toIso8601String(),
  };
}
