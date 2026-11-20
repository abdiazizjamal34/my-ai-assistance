class AssistantProfile {
  const AssistantProfile({
    required this.name,
    required this.personality,
    required this.communicationStyle,
    required this.responseLength,
    required this.proactivity,
  });

  final String name;
  final String personality;
  final String communicationStyle;
  final String responseLength;
  final String proactivity;

  factory AssistantProfile.fromJson(Map<String, dynamic> json) => AssistantProfile(
        name: json['name'] as String? ?? 'Chief',
        personality: json['personality'] as String? ?? 'FRIENDLY',
        communicationStyle: json['communicationStyle'] as String? ?? 'BALANCED',
        responseLength: json['responseLength'] as String? ?? 'BALANCED',
        proactivity: json['proactivity'] as String? ?? 'MEDIUM',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'personality': personality,
        'communicationStyle': communicationStyle,
        'responseLength': responseLength,
        'proactivity': proactivity,
      };
}