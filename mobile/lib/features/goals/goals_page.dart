import 'package:flutter/material.dart';

import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../models/goal.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({required this.service, super.key});

  final PersonalApiService service;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<Goal> _goals = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ACTIVE';

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
      final goals = await widget.service.getGoals();
      if (!mounted) return;
      setState(() => _goals = goals);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Goal> get _visibleGoals {
    switch (_filter) {
      case 'ACTIVE':
        return _goals.where((g) => g.status == 'ACTIVE').toList();
      case 'COMPLETED':
        return _goals
            .where((g) => g.status == 'COMPLETED' || g.status == 'CANCELLED')
            .toList();
      default:
        return _goals;
    }
  }

  Future<void> _openEditor({Goal? existing}) async {
    final result = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalEditorSheet(
        service: widget.service,
        existing: existing,
      ),
    );
    if (result != null) _load();
  }

  Future<void> _confirmCancel(Goal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel goal?'),
        content: Text('"${goal.title}" will be marked as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel goal'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.cancelGoal(goal.id);
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
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    _GoalFilterBar(
                      value: _filter,
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _visibleGoals.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState(
                                    icon: Icons.flag_outlined,
                                    title: 'No goals yet',
                                    message:
                                        'Set a goal to give your work direction.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: _visibleGoals.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final goal = _visibleGoals[index];
                                  return _GoalCard(
                                    goal: goal,
                                    onTap: () =>
                                        _openEditor(existing: goal),
                                    onCancel: goal.status == 'ACTIVE'
                                        ? () => _confirmCancel(goal)
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

class _GoalFilterBar extends StatelessWidget {
  const _GoalFilterBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _Chip(
            label: 'Active',
            selected: value == 'ACTIVE',
            onTap: () => onChanged('ACTIVE'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Completed',
            selected: value == 'COMPLETED',
            onTap: () => onChanged('COMPLETED'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'All',
            selected: value == 'ALL',
            onTap: () => onChanged('ALL'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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

// --- Goal card --------------------------------------------------------------

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onTap,
    this.onCancel,
  });

  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = goal.status == 'COMPLETED' || goal.status == 'CANCELLED';
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
                  goal.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? scheme.onSurfaceVariant : null,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'edit') onTap();
                  if (value == 'cancel' && onCancel != null) onCancel!();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  if (onCancel != null)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel goal'),
                    ),
                ],
              ),
            ],
          ),
          if ((goal.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              goal.description!.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: goal.category, tone: _BadgeTone.neutral),
              _Badge(
                label: goal.priority,
                tone: switch (goal.priority) {
                  'HIGH' => _BadgeTone.danger,
                  'MEDIUM' => _BadgeTone.warning,
                  _ => _BadgeTone.neutral,
                },
              ),
              _Badge(
                label: goal.status,
                tone: switch (goal.status) {
                  'ACTIVE' => _BadgeTone.success,
                  'COMPLETED' => _BadgeTone.primary,
                  'CANCELLED' => _BadgeTone.danger,
                  _ => _BadgeTone.neutral,
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BadgeTone { neutral, primary, success, warning, danger }

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.tone = _BadgeTone.neutral});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _BadgeTone.primary => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      _BadgeTone.success => (
          const Color(0xFFDFF3E4),
          const Color(0xFF1A6B3A)
        ),
      _BadgeTone.warning => (
          const Color(0xFFFDF2D9),
          const Color(0xFF8A5A00)
        ),
      _BadgeTone.danger => (
          const Color(0xFFFBE0DE),
          const Color(0xFF8B1F17)
        ),
      _BadgeTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// --- Goal editor sheet ------------------------------------------------------

class _GoalEditorSheet extends StatefulWidget {
  const _GoalEditorSheet({required this.service, this.existing});

  final PersonalApiService service;
  final Goal? existing;

  @override
  State<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<_GoalEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _category;
  late String _priority;
  bool _saving = false;
  String? _error;

  static const _categories = [
    'CAREER',
    'BUSINESS',
    'PERSONAL',
    'LEARNING',
    'FINANCIAL',
    'HEALTH',
    'OTHER',
  ];

  static const _priorities = ['HIGH', 'MEDIUM', 'LOW'];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
    _category = widget.existing?.category ?? 'PERSONAL';
    _priority = widget.existing?.priority ?? 'MEDIUM';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
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
      final Goal result;
      if (existing == null) {
        result = await widget.service.createGoal(Goal(
          id: '',
          title: title,
          description: _description.text.trim(),
          category: _category,
          priority: _priority,
          status: 'ACTIVE',
        ));
      } else {
        result = await widget.service.updateGoal(Goal(
          id: existing.id,
          title: title,
          description: _description.text.trim(),
          category: _category,
          priority: _priority,
          status: existing.status,
          targetDate: existing.targetDate,
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
              widget.existing == null ? 'New goal' : 'Edit goal',
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
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_pretty(c)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: _priorities
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_pretty(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: scheme.error),
              ),
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
              label: Text(_saving ? 'Saving...' : 'Save goal'),
            ),
          ],
        ),
      ),
    );
  }
}

String _pretty(String value) {
  return value
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}