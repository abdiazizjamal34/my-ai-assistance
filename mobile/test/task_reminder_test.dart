import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_chief_of_staff/models/reminder.dart';
import 'package:personal_ai_chief_of_staff/models/task.dart';
import 'package:personal_ai_chief_of_staff/models/memory.dart';
import 'package:personal_ai_chief_of_staff/models/agent_response.dart';

void main() {
  test('parses and serializes a task', () {
    final task = Task.fromJson({
      'id': 'task-1',
      'title': 'Review plan',
      'priority': 'HIGH',
      'status': 'TODO',
      'source': 'USER',
      'dueDate': '2026-10-08T08:00:00.000Z',
    });

    expect(task.title, 'Review plan');
    expect(task.priority, 'HIGH');
    expect(task.dueDate, isNotNull);
    expect(task.toJson()['status'], 'TODO');
  });

  test('parses and serializes a reminder', () {
    final reminder = Reminder.fromJson({
      'id': 'reminder-1',
      'title': 'Review plan reminder',
      'taskId': 'task-1',
      'remindAt': '2026-10-08T07:30:00.000Z',
      'status': 'PENDING',
    });

    expect(reminder.taskId, 'task-1');
    expect(reminder.status, 'PENDING');
    expect(reminder.remindAt, isNotNull);
    expect(reminder.toJson()['taskId'], 'task-1');
  });

  test('parses and serializes a memory', () {
    final memory = Memory.fromJson({
      'id': 'memory-1',
      'category': 'PREFERENCE',
      'title': 'Communication style',
      'content': 'Prefer concise answers.',
      'importance': 'MEDIUM',
      'status': 'ACTIVE',
      'source': 'USER',
      'confidence': 1,
      'updatedAt': '2026-10-08T08:00:00.000Z',
    });

    expect(memory.category, 'PREFERENCE');
    expect(memory.content, 'Prefer concise answers.');
    expect(memory.updatedAt, isNotNull);
    expect(memory.toJson()['importance'], 'MEDIUM');
  });

  test('parses memory-aware agent responses', () {
    final response = AgentResponse.fromJson({
      'message': 'Personalized response.',
      'actions': [],
      'toolCalls': [],
      'memoryUsed': true,
      'memoryCandidates': [
        {
          'category': 'GOAL',
          'title': 'Personal goal',
          'content': 'I might learn Rust next month.',
          'importance': 'HIGH',
          'confidence': 0.65,
          'decision': 'ASK_CONFIRMATION',
        },
      ],
    });

    expect(response.memoryUsed, isTrue);
    expect(response.memoryCandidates.single.decision, 'ASK_CONFIRMATION');
  });
}
