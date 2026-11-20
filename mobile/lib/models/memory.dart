class Memory {
  const Memory({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.importance,
    required this.status,
    required this.source,
    required this.confidence,
    required this.accessCount,
    this.createdAt,
    this.updatedAt,
    this.lastAccessedAt,
    this.expiresAt,
  });

  final String id;
  final String category;
  final String title;
  final String content;
  final String importance;
  final String status;
  final String source;
  final double confidence;
  final int accessCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastAccessedAt;
  final DateTime? expiresAt;

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
    id: json['id'] as String,
    category: json['category'] as String? ?? 'IMPORTANT_CONTEXT',
    title: json['title'] as String,
    content: json['content'] as String,
    importance: json['importance'] as String? ?? 'MEDIUM',
    status: json['status'] as String? ?? 'ACTIVE',
    source: json['source'] as String? ?? 'USER',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
    accessCount: (json['accessCount'] as num?)?.toInt() ?? 0,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
    lastAccessedAt: _date(json['lastAccessedAt']),
    expiresAt: _date(json['expiresAt']),
  );

  Map<String, dynamic> toJson() => {
    'category': category,
    'title': title,
    'content': content,
    'importance': importance,
    'source': source,
    'confidence': confidence,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}