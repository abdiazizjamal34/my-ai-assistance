class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.projectId,
    this.dueDate,
    this.reminderAt,
    required this.source,
    this.completedAt,
    this.cancelledAt,
  });

  final String id;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final String? projectId;
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final String source;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        priority: json['priority'] as String? ?? 'MEDIUM',
        status: json['status'] as String? ?? 'TODO',
        projectId: json['projectId'] as String?,
        dueDate: _date(json['dueDate']),
        reminderAt: _date(json['reminderAt']),
        source: json['source'] as String? ?? 'USER',
        completedAt: _date(json['completedAt']),
        cancelledAt: _date(json['cancelledAt']),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'projectId': projectId,
        'dueDate': dueDate?.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'source': source,
      };

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value as String);
}