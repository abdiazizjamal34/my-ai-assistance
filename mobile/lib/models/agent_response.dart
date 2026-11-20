import 'memory_candidate.dart';

class AgentResponse {
  const AgentResponse({
    required this.message,
    required this.conversationId,
    required this.actions,
    required this.toolCalls,
    required this.memoryUsed,
    required this.memoryCandidates,
  });

  final String message;
  final String? conversationId;
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> toolCalls;
  final bool memoryUsed;
  final List<MemoryCandidate> memoryCandidates;

  factory AgentResponse.fromJson(Map<String, dynamic> json) => AgentResponse(
    message: json['message'] as String? ?? '',
    conversationId: json['conversationId'] as String?,
    actions: _maps(json['actions']),
    toolCalls: _maps(json['toolCalls']),
    memoryUsed: json['memoryUsed'] as bool? ?? false,
    memoryCandidates: (json['memoryCandidates'] is List)
        ? (json['memoryCandidates'] as List)
              .whereType<Map<String, dynamic>>()
              .map(MemoryCandidate.fromJson)
              .toList()
        : const [],
  );

  static List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];
}