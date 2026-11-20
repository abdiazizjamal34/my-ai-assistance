import 'package:flutter/foundation.dart';

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const userId = String.fromEnvironment(
    'USER_ID',
    defaultValue: '00000000-0000-4000-8000-000000000001',
  );
  static const voiceEnabled = bool.fromEnvironment(
    'VOICE_ENABLED',
    defaultValue: true,
  );

  static String get resolvedApiBaseUrl {
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;
    if (kIsWeb) return 'http://localhost:4000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:4000'
        : 'http://localhost:4000';
  }
}