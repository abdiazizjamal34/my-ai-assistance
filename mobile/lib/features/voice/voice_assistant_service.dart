import 'package:flutter/foundation.dart';

import '../../core/network/personal_api_service.dart';
import 'speech_to_text_provider.dart';
import 'text_to_speech_provider.dart';
import 'voice_types.dart';

class VoiceAssistantService extends ChangeNotifier {
  VoiceAssistantService({
    required PersonalApiService apiService,
    SpeechToTextProvider? speechToText,
    TextToSpeechProvider? textToSpeech,
  }) : _apiService = apiService,
       _speechToText = speechToText ?? DeviceSpeechToTextProvider(),
       _textToSpeech = textToSpeech ?? DeviceTextToSpeechProvider();

  final PersonalApiService _apiService;
  final SpeechToTextProvider _speechToText;
  final TextToSpeechProvider _textToSpeech;
  VoiceSessionState _state = VoiceSessionState.idle;
  String? _errorMessage;
  String? _transcript;
  VoiceTurn? _lastTurn;
  bool _disposed = false;
  int _runId = 0;

  VoiceSessionState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get transcript => _transcript;
  VoiceTurn? get lastTurn => _lastTurn;

  Future<void> startListening({String? conversationId}) async {
    if (_state == VoiceSessionState.listening ||
        _state == VoiceSessionState.processing) {
      return;
    }
    if (_state == VoiceSessionState.speaking) await stopSpeaking();
    final runId = ++_runId;
    _errorMessage = null;
    _transcript = null;
    _setState(VoiceSessionState.requestingPermission);
    try {
      if (!await _speechToText.initialize()) {
        throw const VoiceException(
          'Microphone permission is unavailable. Check app settings and try again.',
        );
      }
      _setState(VoiceSessionState.ready);
      _setState(VoiceSessionState.listening);
      final transcript =
          (await _speechToText.listen(
            onPartial: _updatePartialTranscript,
          ))?.trim() ??
          '';
      if (transcript.isEmpty) {
        throw const VoiceException("I didn't hear anything. Please try again.");
      }
      _transcript = transcript;
      _setState(VoiceSessionState.processing);
      final response = await _apiService.sendAgentMessage(
        transcript,
        conversationId: conversationId,
      );
      if (runId != _runId) return;
      _lastTurn = VoiceTurn(
        transcript: transcript,
        response: response.message,
        conversationId: response.conversationId,
        memoryUsed: response.memoryUsed,
        memoryCandidates: response.memoryCandidates,
      );
      _setState(VoiceSessionState.speaking);
      await _textToSpeech.speak(response.message);
      _setState(VoiceSessionState.idle);
    } catch (error) {
      await _speechToText.cancel();
      _errorMessage = error is VoiceException
          ? error.message
          : error is StateError
          ? error.message
          : 'Voice interaction failed. Please try again.';
      _setState(VoiceSessionState.error);
    }
  }

  Future<void> stopListening() async {
    if (_state != VoiceSessionState.listening) return;
    await _speechToText.stop();
  }

  Future<void> stopSpeaking() async {
    if (_state != VoiceSessionState.speaking) return;
    _runId++;
    await _textToSpeech.stop();
    _setState(VoiceSessionState.idle);
  }

  Future<void> cancel() async {
    _runId++;
    await _speechToText.cancel();
    await _textToSpeech.stop();
    _setState(VoiceSessionState.idle);
  }

  void clearError() {
    _errorMessage = null;
    if (_state == VoiceSessionState.error) _setState(VoiceSessionState.idle);
  }

  @override
  void dispose() {
    _disposed = true;
    _speechToText.cancel();
    _textToSpeech.stop();
    super.dispose();
  }

  void _setState(VoiceSessionState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  void _updatePartialTranscript(String transcript) {
    if (_disposed) return;
    _transcript = transcript;
    notifyListeners();
  }
}