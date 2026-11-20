class Dashboard {
  const Dashboard({
    required this.greetingName,
    required this.todayTaskCount,
    required this.overdueTaskCount,
    required this.upcomingReminderCount,
    required this.completedTodayCount,
    required this.nextReminderAt,
    required this.nextReminderTitle,
    required this.currentFocusCount,
  });

  final String? greetingName;
  final int todayTaskCount;
  final int overdueTaskCount;
  final int upcomingReminderCount;
  final int completedTodayCount;
  final DateTime? nextReminderAt;
  final String? nextReminderTitle;
  final int currentFocusCount;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
    greetingName: json['greetingName'] as String?,
    todayTaskCount: (json['todayTaskCount'] as num?)?.toInt() ?? 0,
    overdueTaskCount: (json['overdueTaskCount'] as num?)?.toInt() ?? 0,
    upcomingReminderCount:
        (json['upcomingReminderCount'] as num?)?.toInt() ?? 0,
    completedTodayCount:
        (json['completedTodayCount'] as num?)?.toInt() ?? 0,
    nextReminderAt: json['nextReminderAt'] is String
        ? DateTime.tryParse(json['nextReminderAt'] as String)?.toLocal()
        : null,
    nextReminderTitle: json['nextReminderTitle'] as String?,
    currentFocusCount: (json['currentFocusCount'] as num?)?.toInt() ?? 0,
  );

  static const empty = Dashboard(
    greetingName: null,
    todayTaskCount: 0,
    overdueTaskCount: 0,
    upcomingReminderCount: 0,
    completedTodayCount: 0,
    nextReminderAt: null,
    nextReminderTitle: null,
    currentFocusCount: 0,
  );
}