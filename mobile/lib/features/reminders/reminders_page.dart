import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../models/reminder.dart';
import '../../core/notifications/reminder_scheduler.dart';


class RemindersPage extends StatefulWidget {
  const RemindersPage({required this.service, super.key});
  

  final PersonalApiService service;
  

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Reminder> _reminders = [];
  bool _loading = true;
  String? _error;
  String _filter = 'PENDING';

  late final ReminderScheduler _scheduler;

  @override
  void initState() {
    super.initState();
    _scheduler = ReminderScheduler(service: widget.service);
    _load();
  }

  // Future<void> _load() async {
  //   setState(() {
  //     _loading = true;
  //     _error = null;
  //   });
  //   try {
  //     final reminders = await widget.service.getReminders(
  //       status: _filter == 'ALL' ? null : _filter,
  //     );
  //     if (!mounted) return;
  //     setState(() => _reminders = reminders);
  //   } catch (error) {
  //     if (mounted) setState(() => _error = error.toString());
  //   } finally {
  //     if (mounted) setState(() => _loading = false);
  //   }
  // }


  Future<void> _load() async {
  setState(() {
    _loading = true;
    _error = null;
  });
  try {
    final reminders = await widget.service.getReminders(
      status: _filter == 'ALL' ? null : _filter,
    );
    if (!mounted) return;
    setState(() => _reminders = reminders);
    // Fire-and-forget: keep notifications in sync
    unawaited(_scheduler.sync());
  } catch (error) {
    if (mounted) setState(() => _error = error.toString());
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  Future<void> _openEditor({Reminder? existing}) async {
    final result = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderEditorSheet(
        service: widget.service,
        existing: existing,
      ),
    );
    if (result != null) _load();
  }

  Future<void> _complete(Reminder reminder) async {
    try {
      await widget.service.updateReminderStatus(reminder.id, 'COMPLETED');
       await _scheduler.cancelOne(reminder.id);
      if (mounted) _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete: $error')),
      );
    }
  }

  Future<void> _cancel(Reminder reminder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel reminder?'),
        content: Text('"${reminder.title}" will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel reminder'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.cancelReminder(reminder.id);
       await _scheduler.cancelOne(reminder.id);
      if (mounted) _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('New reminder'),
      ),
      body: Column(
        children: [
          _RemindersFilterBar(
            value: _filter,
            onChanged: (v) {
              setState(() => _filter = v);
              _load();
            },
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _reminders.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState(
                                    icon: Icons.notifications_none,
                                    title: 'No reminders',
                                    message:
                                        'Schedule one to get nudged at the right time.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: _reminders.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final reminder = _reminders[index];
                                  return _ReminderCard(
                                    reminder: reminder,
                                    onTap: () =>
                                        _openEditor(existing: reminder),
                                    onComplete: reminder.status == 'PENDING'
                                        ? () => _complete(reminder)
                                        : null,
                                    onCancel: reminder.status == 'PENDING'
                                        ? () => _cancel(reminder)
                                        : null,
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

// --- Filter bar -------------------------------------------------------------

class _RemindersFilterBar extends StatelessWidget {
  const _RemindersFilterBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _RChip(
            label: 'Pending',
            selected: value == 'PENDING',
            onTap: () => onChanged('PENDING'),
          ),
          const SizedBox(width: 8),
          _RChip(
            label: 'Completed',
            selected: value == 'COMPLETED',
            onTap: () => onChanged('COMPLETED'),
          ),
          const SizedBox(width: 8),
          _RChip(
            label: 'All',
            selected: value == 'ALL',
            onTap: () => onChanged('ALL'),
          ),
        ],
      ),
    );
  }
}

class _RChip extends StatelessWidget {
  const _RChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// --- Reminder card ----------------------------------------------------------

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onTap,
    this.onComplete,
    this.onCancel,
  });

  final Reminder reminder;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = reminder.status == 'COMPLETED';
    final isCancelled = reminder.status == 'CANCELLED';
    final isOverdue = reminder.status == 'PENDING' &&
        reminder.remindAt.isBefore(DateTime.now());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reminder.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    decoration: isDone || isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                    color: isDone || isCancelled
                        ? scheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'edit') onTap();
                  if (value == 'complete' && onComplete != null) onComplete!();
                  if (value == 'cancel' && onCancel != null) onCancel!();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (onComplete != null)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark complete'),
                    ),
                  if (onCancel != null)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
          if ((reminder.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reminder.description!.trim(),
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isOverdue ? Icons.alarm : Icons.schedule,
                size: 14,
                color: isOverdue ? scheme.error : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDateTime(reminder.remindAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOverdue ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: isOverdue ? FontWeight.w600 : null,
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(status: reminder.status),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(local.year, local.month, local.day);
    final diff = d.difference(today).inDays;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (diff == 0) return 'Today · $hh:$mm';
    if (diff == 1) return 'Tomorrow · $hh:$mm';
    if (diff == -1) return 'Yesterday · $hh:$mm';
    return '${local.day}/${local.month}/${local.year} · $hh:$mm';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      'PENDING' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'COMPLETED' => (const Color(0xFFDFF3E4), const Color(0xFF1A6B3A)),
      'CANCELLED' => (const Color(0xFFFBE0DE), const Color(0xFF8B1F17)),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// --- Reminder editor sheet --------------------------------------------------

class _ReminderEditorSheet extends StatefulWidget {
  const _ReminderEditorSheet({required this.service, this.existing});

  final PersonalApiService service;
  final Reminder? existing;

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  DateTime? _remindAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
    _remindAt = widget.existing?.remindAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _remindAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _remindAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_remindAt == null) {
      setState(() => _error = 'Please choose a reminder time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final Reminder result;
      if (existing == null) {
        result = await widget.service.createReminder(Reminder(
          id: '',
          title: title,
          description: _description.text.trim(),
          remindAt: _remindAt!,
          status: 'PENDING',
        ));
      } else {
        result = await widget.service.updateReminder(Reminder(
          id: existing.id,
          title: title,
          description: _description.text.trim(),
          remindAt: _remindAt!,
          status: existing.status,
          taskId: existing.taskId,
          completedAt: existing.completedAt,
          cancelledAt: existing.cancelledAt,
        ));
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? 'New reminder' : 'Edit reminder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alarm,
                        size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remind at',
                              style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 2),
                          Text(
                            _remindAt == null
                                ? 'Choose a date and time'
                                : _ReminderEditorSheetState._format(_remindAt!),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: _remindAt == null
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving...' : 'Save reminder'),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hh:$mm';
  }
}