class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.targetDate,
  });

  final String id;
  final String title;
  final String? description;
  final String category;
  final String priority;
  final String status;
  final DateTime? targetDate;

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        category: json['category'] as String? ?? 'OTHER',
        priority: json['priority'] as String? ?? 'MEDIUM',
        status: json['status'] as String? ?? 'ACTIVE',
        targetDate: json['targetDate'] == null
            ? null
            : DateTime.tryParse(json['targetDate'] as String),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        'status': status,
        'targetDate': targetDate?.toIso8601String(),
      };
}