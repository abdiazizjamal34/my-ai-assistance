import '../../models/assistant_profile.dart';
import '../../models/agent_response.dart';
import '../../models/goal.dart';
import '../../models/memory.dart';
import '../../models/memory_candidate.dart';
import '../../models/user_preferences.dart';
import '../../models/user_profile.dart';
import '../../models/reminder.dart';
import '../../models/task.dart';
import 'api_client.dart';
import 'streaming_client.dart';
import '../../models/dashboard.dart';



class PersonalApiService {
  const PersonalApiService(this.client);

  final ApiClient client;

  Future<Dashboard> getDashboard() async {
  final response = await client.getJson('/api/dashboard');
  return Dashboard.fromJson(
    response['data'] as Map<String, dynamic>,
  );
}
// Inside PersonalApiService:

Stream<AgentStreamEvent> streamAgentMessage(
  String message, {
  String? conversationId,
}) {
  final streaming = StreamingClient(
    baseUrl: client.baseUrl,
    userId: client.userId,
  );
  return streaming.chatStream(
    message: message,
    conversationId: conversationId,
  );
}


Future<List<Map<String, dynamic>>> getConversations({int limit = 30}) async {
  final response = await client.getJson('/api/conversations?limit=$limit');
  final list = response['data'] as List? ?? const [];
  return list.whereType<Map<String, dynamic>>().toList();
}

Future<List<Map<String, dynamic>>> getConversationMessages(
  String conversationId, {
  int limit = 200,
}) async {
  final response = await client.getJson(
    '/api/conversations/$conversationId/messages?limit=$limit',
  );
  final list = response['data'] as List? ?? const [];
  return list.whereType<Map<String, dynamic>>().toList();
}

  Future<UserProfile> getProfile() async =>
      UserProfile.fromJson((await client.getJson('/api/profile'))['data']);

  Future<UserProfile> updateProfile(UserProfile profile) async =>
      UserProfile.fromJson(
        (await client.putJson('/api/profile', profile.toJson()))['data'],
      );

  Future<UserPreferences> getPreferences() async => UserPreferences.fromJson(
    (await client.getJson('/api/preferences'))['data'],
  );

  Future<UserPreferences> updatePreferences(
    UserPreferences preferences,
  ) async => UserPreferences.fromJson(
    (await client.putJson('/api/preferences', preferences.toJson()))['data'],
  );

  Future<AssistantProfile> getAssistantProfile() async =>
      AssistantProfile.fromJson(
        (await client.getJson('/api/assistant-profile'))['data'],
      );

  Future<AssistantProfile> updateAssistantProfile(
    AssistantProfile profile,
  ) async => AssistantProfile.fromJson(
    (await client.putJson('/api/assistant-profile', profile.toJson()))['data'],
  );

  Future<AgentResponse> sendAgentMessage(
    String message, {
    String? conversationId,
  }) async {
    final response = await client.postJson('/api/agent/chat', {
      'message': message,
      if (conversationId != null) 'conversationId': conversationId,
    });
    return AgentResponse.fromJson(response);
  }

  Future<List<Goal>> getGoals() async =>
      ((await client.getJson('/api/goals'))['data'] as List)
          .map((item) => Goal.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<Goal> createGoal(Goal goal) async => Goal.fromJson(
    (await client.postJson('/api/goals', goal.toJson()))['data'],
  );

  Future<Goal> updateGoal(Goal goal) async => Goal.fromJson(
    (await client.putJson('/api/goals/${goal.id}', goal.toJson()))['data'],
  );

  Future<Goal> cancelGoal(String id) async =>
      Goal.fromJson((await client.deleteJson('/api/goals/$id'))['data']);

  Future<List<Memory>> getMemories({
    String? category,
    String? importance,
    String? status,
  }) async {
    final query = <String, String>{
      if (category != null) 'category': category,
      if (importance != null) 'importance': importance,
      if (status != null) 'status': status,
    };
    final suffix = query.isEmpty
        ? ''
        : '?${query.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    return _memories((await client.getJson('/api/memories$suffix'))['data']);
  }

  Future<List<Memory>> searchMemories(String query) async => _memories(
    (await client.getJson(
      '/api/memories/search?q=${Uri.encodeQueryComponent(query)}',
    ))['data'],
  );

  Future<Memory> createMemory(Memory memory) async => Memory.fromJson(
    (await client.postJson('/api/memories', memory.toJson()))['data'],
  );

  Future<Memory> saveMemoryCandidate(MemoryCandidate candidate) async =>
      Memory.fromJson(
        (await client.postJson(
          '/api/memories',
          candidate.toMemoryJson(),
        ))['data'],
      );

  Future<Memory> updateMemory(Memory memory) async => Memory.fromJson(
    (await client.putJson(
      '/api/memories/${memory.id}',
      memory.toJson(),
    ))['data'],
  );

  Future<Memory> archiveMemory(String id) async => Memory.fromJson(
    (await client.postJson('/api/memories/$id/archive', {}))['data'],
  );

  Future<Memory> deleteMemory(String id) async =>
      Memory.fromJson((await client.deleteJson('/api/memories/$id'))['data']);

  Future<List<Task>> getTasks({
    String? status,
    String? priority,
    String? date,
    bool? completed,
  }) async {
    final query = <String, String>{
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (date != null) 'date': date,
      if (completed != null) 'completed': completed.toString(),
    };
    final suffix = query.isEmpty
        ? ''
        : '?${query.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    return _tasks((await client.getJson('/api/tasks$suffix'))['data']);
  }

  Future<List<Task>> getTodayTasks() => getTasks(date: 'today');
  Future<List<Task>> getUpcomingTasks() => getTasks(date: 'upcoming');
  Future<List<Task>> getPendingTasks() => getTasks(status: 'TODO');
  Future<List<Task>> getCompletedTasks() => getTasks(completed: true);
  Future<List<Task>> getOverdueTasks() => getTasks(date: 'overdue');

  Future<Task> createTask(Task task) async => Task.fromJson(
    (await client.postJson('/api/tasks', task.toJson()))['data'],
  );

  Future<Task> updateTask(Task task) async => Task.fromJson(
    (await client.putJson('/api/tasks/${task.id}', task.toJson()))['data'],
  );

  Future<Task> updateTaskStatus(String id, String status) async =>
      Task.fromJson(
        (await client.patchJson('/api/tasks/$id/status', {
          'status': status,
        }))['data'],
      );

  Future<Task> cancelTask(String id) async =>
      Task.fromJson((await client.deleteJson('/api/tasks/$id'))['data']);

  Future<List<Reminder>> getReminders({String? status, bool? upcoming}) async {
    final query = <String, String>{
      if (status != null) 'status': status,
      if (upcoming != null) 'upcoming': upcoming.toString(),
    };
    final suffix = query.isEmpty
        ? ''
        : '?${query.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    return _reminders((await client.getJson('/api/reminders$suffix'))['data']);
  }

  Future<List<Reminder>> getUpcomingReminders() => getReminders(upcoming: true);

  Future<Reminder> createReminder(Reminder reminder) async => Reminder.fromJson(
    (await client.postJson('/api/reminders', reminder.toJson()))['data'],
  );

  Future<Reminder> updateReminder(Reminder reminder) async => Reminder.fromJson(
    (await client.putJson(
      '/api/reminders/${reminder.id}',
      reminder.toJson(),
    ))['data'],
  );

  Future<Reminder> updateReminderStatus(String id, String status) async =>
      Reminder.fromJson(
        (await client.patchJson('/api/reminders/$id/status', {
          'status': status,
        }))['data'],
      );

  Future<Reminder> cancelReminder(String id) async => Reminder.fromJson(
    (await client.deleteJson('/api/reminders/$id'))['data'],
  );

  List<Task> _tasks(Object? value) => (value as List)
      .map((item) => Task.fromJson(item as Map<String, dynamic>))
      .toList();

  List<Reminder> _reminders(Object? value) => (value as List)
      .map((item) => Reminder.fromJson(item as Map<String, dynamic>))
      .toList();

  List<Memory> _memories(Object? value) => (value as List)
      .map((item) => Memory.fromJson(item as Map<String, dynamic>))
      .toList();
}
