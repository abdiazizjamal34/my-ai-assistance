import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single SSE event from the backend's `/api/agent/chat/stream` endpoint.
class AgentStreamEvent {
  const AgentStreamEvent({
    required this.type,
    this.delta,
    this.message,
    this.conversationId,
    this.toolName,
    this.toolSuccess,
    this.memoryCandidates,
  });

  final String type; // meta | tool | text | done | error
  final String? delta;
  final String? message;
  final String? conversationId;
  final String? toolName;
  final bool? toolSuccess;
  final List<Map<String, dynamic>>? memoryCandidates;

  factory AgentStreamEvent.fromJson(Map<String, dynamic> json) {
    return AgentStreamEvent(
      type: json['type'] as String? ?? 'text',
      delta: json['delta'] as String?,
      message: json['message'] as String?,
      conversationId: json['conversationId'] as String?,
      toolName: json['name'] as String?,
      toolSuccess: json['success'] as bool?,
      memoryCandidates: json['memoryCandidates'] is List
          ? (json['memoryCandidates'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : null,
    );
  }
}

class StreamingClient {
  StreamingClient({
    required this.baseUrl,
    required this.userId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String userId;
  final http.Client _client;

  /// Sends a message and yields SSE events as they arrive.
  Stream<AgentStreamEvent> chatStream({
    required String message,
    String? conversationId,
  }) async* {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/agent/chat/stream',
    );
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'x-user-id': userId,
      })
      ..body = jsonEncode({
        'message': message,
        if (conversationId != null) 'conversationId': conversationId,
      });

    final response = await _client.send(request);

    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw Exception('Stream failed: ${response.statusCode} $body');
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final buffer = StringBuffer();

    await for (final line in lines) {
      if (line.isEmpty) {
        final frame = buffer.toString().trim();
        buffer.clear();
        if (frame.isEmpty) continue;
        if (frame.startsWith('data:')) {
          final payload = frame.substring(5).trim();
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            yield AgentStreamEvent.fromJson(json);
          } catch (_) {
            // skip malformed frames
          }
        }
      } else {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line);
      }
    }

    // flush trailing frame if any
    final tail = buffer.toString().trim();
    if (tail.startsWith('data:')) {
      final payload = tail.substring(5).trim();
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        yield AgentStreamEvent.fromJson(json);
      } catch (_) {}
    }
  }

  void dispose() => _client.close();
}