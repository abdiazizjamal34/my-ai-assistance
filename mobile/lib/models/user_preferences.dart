class UserPreferences {
  const UserPreferences({
    required this.timezone,
    required this.preferredLanguage,
    required this.dateFormat,
    required this.timeFormat,
    required this.weekStartDay,
    required this.notificationPreference,
    required this.morningPlanningEnabled,
    required this.morningPlanningTime,
    required this.eveningReviewEnabled,
    required this.eveningReviewTime,
  });

  final String timezone;
  final String preferredLanguage;
  final String dateFormat;
  final String timeFormat;
  final String weekStartDay;
  final String notificationPreference;
  final bool morningPlanningEnabled;
  final String morningPlanningTime;
  final bool eveningReviewEnabled;
  final String eveningReviewTime;

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
        timezone: json['timezone'] as String? ?? 'Africa/Nairobi',
        preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
        dateFormat: json['dateFormat'] as String? ?? 'DMY',
        timeFormat: json['timeFormat'] as String? ?? 'H24',
        weekStartDay: json['weekStartDay'] as String? ?? 'MONDAY',
        notificationPreference: json['notificationPreference'] as String? ?? 'ALL',
        morningPlanningEnabled: json['morningPlanningEnabled'] as bool? ?? true,
        morningPlanningTime: json['morningPlanningTime'] as String? ?? '07:30',
        eveningReviewEnabled: json['eveningReviewEnabled'] as bool? ?? true,
        eveningReviewTime: json['eveningReviewTime'] as String? ?? '20:00',
      );

  Map<String, dynamic> toJson() => {
        'timezone': timezone,
        'preferredLanguage': preferredLanguage,
        'dateFormat': dateFormat,
        'timeFormat': timeFormat,
        'weekStartDay': weekStartDay,
        'notificationPreference': notificationPreference,
        'morningPlanningEnabled': morningPlanningEnabled,
        'morningPlanningTime': morningPlanningTime,
        'eveningReviewEnabled': eveningReviewEnabled,
        'eveningReviewTime': eveningReviewTime,
      };
}