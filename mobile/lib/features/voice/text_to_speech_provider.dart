  import 'package:flutter_tts/flutter_tts.dart';

abstract interface class TextToSpeechProvider {
  Future<void> speak(String text);
  Future<void> stop();
}

class DeviceTextToSpeechProvider implements TextToSpeechProvider {
  DeviceTextToSpeechProvider({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_configured) {
      await _tts.setLanguage('en-US');
      await _tts.awaitSpeakCompletion(true);
      _configured = true;
    }
    await _tts.speak(normalizeSpeechText(text));
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

String normalizeSpeechText(String text) {
  var normalized = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' code omitted ');
  normalized = normalized.replaceAll(RegExp(r'https?://\S+'), ' link ');
  normalized = normalized.replaceAll(RegExp(r'(^|\s)[-•]\s*'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[#*_>`]'), '');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}
