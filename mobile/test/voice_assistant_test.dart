import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:personal_ai_chief_of_staff/core/network/api_client.dart';
import 'package:personal_ai_chief_of_staff/core/network/personal_api_service.dart';
import 'package:personal_ai_chief_of_staff/features/voice/speech_to_text_provider.dart';
import 'package:personal_ai_chief_of_staff/features/voice/text_to_speech_provider.dart';
import 'package:personal_ai_chief_of_staff/features/voice/voice_assistant_service.dart';
import 'package:personal_ai_chief_of_staff/features/voice/voice_types.dart';

class FakeSpeechToText implements SpeechToTextProvider {
  FakeSpeechToText(this.transcript);

  final String? transcript;
  bool stopped = false;
  bool cancelled = false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<String?> listen({void Function(String transcript)? onPartial}) async {
    if (transcript != null) onPartial?.call(transcript!);
    return transcript;
  }

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<void> cancel() async => cancelled = true;
}

class FakeTextToSpeech implements TextToSpeechProvider {
  String? spoken;
  bool stopped = false;

  @override
  Future<void> speak(String text) async => spoken = text;

  @override
  Future<void> stop() async => stopped = true;
}

class FakeAgentClient extends http.BaseClient {
  String? requestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestBody = await request.finalize().bytesToString();
    final body = jsonEncode({
      'message': 'Done. I created the reminder.',
      'actions': [],
      'toolCalls': [],
      'memoryUsed': false,
      'memoryCandidates': [],
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

PersonalApiService serviceFor(FakeAgentClient client) => PersonalApiService(
  ApiClient(
    baseUrl: 'http://localhost:4000',
    userId: 'test-user',
    client: client,
  ),
);

void main() {
  test(
    'voice service sends the transcript through the existing agent and speaks the response',
    () async {
      final client = FakeAgentClient();
      final speech = FakeSpeechToText(
        'Remind me to call Ahmed tomorrow at 10 AM.',
      );
      final tts = FakeTextToSpeech();
      final voice = VoiceAssistantService(
        apiService: serviceFor(client),
        speechToText: speech,
        textToSpeech: tts,
      );

      await voice.startListening();

      expect(voice.state, VoiceSessionState.idle);
      expect(voice.lastTurn?.transcript, contains('Ahmed'));
      expect(tts.spoken, contains('created the reminder'));
      expect(client.requestBody, contains('Ahmed'));
      voice.dispose();
    },
  );

  test(
    'empty transcripts become a recoverable error and are not sent',
    () async {
      final client = FakeAgentClient();
      final speech = FakeSpeechToText('   ');
      final tts = FakeTextToSpeech();
      final voice = VoiceAssistantService(
        apiService: serviceFor(client),
        speechToText: speech,
        textToSpeech: tts,
      );

      await voice.startListening();

      expect(voice.state, VoiceSessionState.error);
      expect(voice.errorMessage, contains("didn't hear"));
      expect(client.requestBody, isNull);
      expect(speech.cancelled, isTrue);
      voice.dispose();
    },
  );

  test(
    'speech normalization removes formatting that is unsuitable for TTS',
    () {
      expect(
        normalizeSpeechText('# Done\n- Visit https://example.com'),
        'Done Visit link',
      );
    },
  );
}
