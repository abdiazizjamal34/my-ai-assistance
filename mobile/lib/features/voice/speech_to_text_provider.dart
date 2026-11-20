import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract interface class SpeechToTextProvider {
  Future<bool> initialize();
  Future<String?> listen({void Function(String transcript)? onPartial});
  Future<void> stop();
  Future<void> cancel();
}

class DeviceSpeechToTextProvider implements SpeechToTextProvider {
  DeviceSpeechToTextProvider({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  Completer<String?>? _completion;
  String _transcript = '';
  void Function(String transcript)? _onPartial;
  Timer? _timeout;
  String? _lastError;

  @override
  Future<bool> initialize() => _speech.initialize(
    onError: (error) {
      _lastError = error.errorMsg;
      _complete();
    },
  );

  @override
  Future<String?> listen({void Function(String transcript)? onPartial}) async {
    _completion = Completer<String?>();
    _transcript = '';
    _onPartial = onPartial;
    _lastError = null;
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 65), () async {
      await _speech.stop();
      _complete();
    });
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: true,
      ),
    );
    final transcript = await _completion!.future;
    if ((transcript ?? '').trim().isEmpty && _lastError != null) {
      throw StateError(_lastError!);
    }
    return transcript;
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _complete();
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _complete(value: null);
  }

  void _onResult(SpeechRecognitionResult result) {
    _transcript = result.recognizedWords;
    _onPartial?.call(_transcript);
    if (result.finalResult) _complete();
  }

  void _complete({String? value}) {
    _timeout?.cancel();
    _timeout = null;
    final completion = _completion;
    if (completion == null || completion.isCompleted) return;
    completion.complete(value ?? _transcript);
  }
}
