import '../../models/reminder.dart';
import '../network/personal_api_service.dart';
import 'notification_service.dart';

/// Syncs the user's reminders with local notifications.
///
/// Strategy: whenever the app opens, on reminder change, or when the user
/// signs in, we clear all our scheduled notifications and re-schedule from
/// the current list. This is idempotent and self-healing: if a reminder was
/// cancelled on another device, or the OS dropped a schedule, the next sync
/// fixes it.
class ReminderScheduler {
  ReminderScheduler({required this.service});

  final PersonalApiService service;

  Future<void> sync() async {
    final ns = NotificationService.instance;

    // 1. Fetch reminders. Include past-due ones so we can decide what to do
    //    with each — we won't schedule past-due, we just skip them.
    List<Reminder> reminders;
    try {
      reminders = await service.getReminders();
    } catch (_) {
      return;
    }

    // 2. Grab what's currently scheduled so we know what to cancel.
    final pending = await ns.pending();
    final pendingIds = pending.map((p) => p.id).toSet();

    final now = DateTime.now();
    final upcoming = reminders
        .where((r) => r.status == 'PENDING' && r.remindAt.isAfter(now))
        .toList();

    // 3. Compute the set of IDs we want scheduled.
    final desiredIds = upcoming
        .map((r) => NotificationService.idForReminder(r.id))
        .toSet();

    // 4. Cancel stale notifications (no longer wanted).
    for (final id in pendingIds.difference(desiredIds)) {
      await ns.cancel(id);
    }

    // 5. Schedule or refresh all desired ones.
    //    iOS has a hard limit of 64 pending notifications. Cap to be safe.
    final capped = upcoming.take(60).toList();
    for (final r in capped) {
      await ns.schedule(
        id: NotificationService.idForReminder(r.id),
        title: r.title,
        body: r.description?.trim().isNotEmpty == true
            ? r.description!.trim()
            : 'It\'s time.',
        when: r.remindAt.toLocal(),
        payload: r.id,
      );
    }
  }

  /// Convenience for a single reminder — called after create/update.
  Future<void> rescheduleOne(Reminder reminder) async {
    final ns = NotificationService.instance;
    final id = NotificationService.idForReminder(reminder.id);

    if (reminder.status != 'PENDING' ||
        reminder.remindAt.isBefore(DateTime.now())) {
      await ns.cancel(id);
      return;
    }

    await ns.schedule(
      id: id,
      title: reminder.title,
      body: reminder.description?.trim().isNotEmpty == true
          ? reminder.description!.trim()
          : 'It\'s time.',
      when: reminder.remindAt.toLocal(),
      payload: reminder.id,
    );
  }

  Future<void> cancelOne(String reminderId) async {
    await NotificationService.instance.cancel(
      NotificationService.idForReminder(reminderId),
    );
  }
}