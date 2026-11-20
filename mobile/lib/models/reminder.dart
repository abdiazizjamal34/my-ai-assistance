class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    this.description,
    this.taskId,
    required this.remindAt,
    required this.status,
    this.completedAt,
    this.cancelledAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? taskId;
  final DateTime remindAt;
  final String status;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        taskId: json['taskId'] as String?,
        remindAt: DateTime.parse(json['remindAt'] as String),
        status: json['status'] as String? ?? 'PENDING',
        completedAt: _date(json['completedAt']),
        cancelledAt: _date(json['cancelledAt']),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'taskId': taskId,
        'remindAt': remindAt.toIso8601String(),
        'status': status,
      };

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value as String);
}