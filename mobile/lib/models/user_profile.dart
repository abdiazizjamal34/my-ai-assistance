class UserProfile {
  const UserProfile({
    required this.id,
    this.firstName,
    this.lastName,
    this.displayName,
    this.email,
    this.profileImageUrl,
    this.bio,
    required this.timezone,
    required this.preferredLanguage,
    this.locationCountry,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? email;
  final String? profileImageUrl;
  final String? bio;
  final String timezone;
  final String preferredLanguage;
  final String? locationCountry;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        displayName: json['displayName'] as String?,
        email: json['email'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
        bio: json['bio'] as String?,
        timezone: json['timezone'] as String? ?? 'Africa/Nairobi',
        preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
        locationCountry: json['locationCountry'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'email': email,
        'profileImageUrl': profileImageUrl,
        'bio': bio,
        'timezone': timezone,
        'preferredLanguage': preferredLanguage,
        'locationCountry': locationCountry,
      };
}