import '../../models/memory_candidate.dart';

enum VoiceSessionState {
  idle,
  requestingPermission,
  ready,
  listening,
  processing,
  speaking,
  error,
}

class VoiceTurn {
  const VoiceTurn({
    required this.transcript,
    required this.response,
    required this.conversationId,
    required this.memoryUsed,
    required this.memoryCandidates,
  });

  final String transcript;
  final String response;
  final String? conversationId;
  final bool memoryUsed;
  final List<MemoryCandidate> memoryCandidates;
}

class VoiceException implements Exception {
  const VoiceException(this.message);

  final String message;

  @override
  String toString() => message;
}