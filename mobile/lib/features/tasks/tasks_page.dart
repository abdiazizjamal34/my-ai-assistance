import 'package:flutter/material.dart';

import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../models/task.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({required this.service, super.key});

  final PersonalApiService service;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  static const _views = ['Today', 'Upcoming', 'Overdue', 'Completed'];

  int _view = 0;
  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = switch (_view) {
        0 => await widget.service.getTodayTasks(),
        1 => await widget.service.getUpcomingTasks(),
        2 => await widget.service.getOverdueTasks(),
        _ => await widget.service.getCompletedTasks(),
      };
      if (!mounted) return;
      setState(() => _tasks = tasks);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({Task? existing}) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskEditorSheet(
        service: widget.service,
        existing: existing,
      ),
    );
    if (result != null) _load();
  }

  Future<void> _toggleComplete(Task task) async {
    final next = task.status == 'COMPLETED' ? 'TODO' : 'COMPLETED';
    try {
      await widget.service.updateTaskStatus(task.id, next);
      if (mounted) _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $error')),
      );
    }
  }

  Future<void> _cancel(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel task?'),
        content: Text('"${task.title}" will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel task'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.cancelTask(task.id);
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
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: Column(
        children: [
          _TasksSegmentedBar(
            views: _views,
            index: _view,
            onChanged: (i) {
              setState(() => _view = i);
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
                        child: _tasks.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState(
                                    icon: Icons.checklist_outlined,
                                    title: 'Nothing here',
                                    message:
                                        'Tasks you add will show up in this view.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: _tasks.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final task = _tasks[index];
                                  return _TaskCard(
                                    task: task,
                                    onTap: () =>
                                        _openEditor(existing: task),
                                    onToggleComplete: () =>
                                        _toggleComplete(task),
                                    onCancel: task.status != 'CANCELLED'
                                        ? () => _cancel(task)
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

// --- Segmented filter -------------------------------------------------------

class _TasksSegmentedBar extends StatelessWidget {
  const _TasksSegmentedBar({
    required this.views,
    required this.index,
    required this.onChanged,
  });

  final List<String> views;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(views.length, (i) {
          final selected = i == index;
          return Padding(
            padding: EdgeInsets.only(right: i == views.length - 1 ? 0 : 8),
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  views[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// --- Task card --------------------------------------------------------------

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggleComplete,
    this.onCancel,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = task.status == 'COMPLETED';
    final isOverdue = task.dueDate != null &&
        task.status != 'COMPLETED' &&
        task.status != 'CANCELLED' &&
        task.dueDate!.isBefore(DateTime.now());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleComplete,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 26,
                color: isDone ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color:
                        isDone ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
                if ((task.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!.trim(),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _TaskBadge(
                      label: task.priority,
                      tone: switch (task.priority) {
                        'URGENT' => _TaskBadgeTone.danger,
                        'HIGH' => _TaskBadgeTone.warning,
                        _ => _TaskBadgeTone.neutral,
                      },
                    ),
                    if (task.dueDate != null)
                      _TaskBadge(
                        label: _relativeDate(task.dueDate!),
                        tone: isOverdue
                            ? _TaskBadgeTone.danger
                            : _TaskBadgeTone.neutral,
                        icon: Icons.schedule,
                      ),
                    if (task.status == 'IN_PROGRESS')
                      const _TaskBadge(
                        label: 'In progress',
                        tone: _TaskBadgeTone.primary,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'edit') onTap();
              if (value == 'cancel' && onCancel != null) onCancel!();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (onCancel != null)
                const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff < 7) return 'In $diff days';
    if (diff < -1 && diff > -7) return '${-diff} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

enum _TaskBadgeTone { neutral, primary, success, warning, danger }

class _TaskBadge extends StatelessWidget {
  const _TaskBadge({
    required this.label,
    this.tone = _TaskBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final _TaskBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _TaskBadgeTone.primary => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      _TaskBadgeTone.success => (
          const Color(0xFFDFF3E4),
          const Color(0xFF1A6B3A)
        ),
      _TaskBadgeTone.warning => (
          const Color(0xFFFDF2D9),
          const Color(0xFF8A5A00)
        ),
      _TaskBadgeTone.danger => (
          const Color(0xFFFBE0DE),
          const Color(0xFF8B1F17)
        ),
      _TaskBadgeTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Task editor sheet ------------------------------------------------------

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({required this.service, this.existing});

  final PersonalApiService service;
  final Task? existing;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _priority;
  DateTime? _dueDate;
  bool _saving = false;
  String? _error;

  static const _priorities = ['URGENT', 'HIGH', 'MEDIUM', 'LOW'];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
    _priority = widget.existing?.priority ?? 'MEDIUM';
    _dueDate = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate ?? now),
    );
    if (time == null) return;
    setState(() {
      _dueDate =
          DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final Task result;
      if (existing == null) {
        result = await widget.service.createTask(Task(
          id: '',
          title: title,
          description: _description.text.trim(),
          priority: _priority,
          status: 'TODO',
          dueDate: _dueDate,
          source: 'USER',
        ));
      } else {
        result = await widget.service.updateTask(Task(
          id: existing.id,
          title: title,
          description: _description.text.trim(),
          priority: _priority,
          status: existing.status,
          dueDate: _dueDate,
          source: existing.source,
          projectId: existing.projectId,
          reminderAt: existing.reminderAt,
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
              widget.existing == null ? 'New task' : 'Edit task',
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
            DropdownButtonFormField<String>(
              initialValue: _priority,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: _priorities
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_taskPretty(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 12),
            _DateRow(
              value: _dueDate,
              onTap: _pickDueDate,
              onClear: () => setState(() => _dueDate = null),
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
              label: Text(_saving ? 'Saving...' : 'Save task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due date', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? 'No due date' : _format(value!),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: value == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear',
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
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }
}

String _taskPretty(String value) {
  return value
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}