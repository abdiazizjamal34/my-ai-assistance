import 'package:flutter/material.dart';

import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../models/memory.dart';

class MemoriesPage extends StatefulWidget {
  const MemoriesPage({required this.service, super.key});

  final PersonalApiService service;

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> {
  final _searchController = TextEditingController();
  List<Memory> _memories = [];
  String? _category;
  bool _loading = true;
  String? _error;

  static const _categories = <(String?, String)>[
    (null, 'All'),
    ('PERSONAL', 'Personal'),
    ('GOAL', 'Goals'),
    ('PROJECT', 'Projects'),
    ('PEOPLE', 'People'),
    ('PREFERENCE', 'Preferences'),
    ('DECISION', 'Decisions'),
    ('IMPORTANT_CONTEXT', 'Context'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchController.text.trim();
      final result = query.isEmpty
          ? await widget.service.getMemories(category: _category)
          : await widget.service.searchMemories(query);
      if (!mounted) return;
      setState(() => _memories = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({Memory? existing}) async {
    final result = await showModalBottomSheet<Memory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemoryEditorSheet(
        service: widget.service,
        existing: existing,
      ),
    );
    if (result != null) _load();
  }

  Future<void> _confirmArchive(Memory memory) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive memory?'),
        content: Text(
          '"${memory.title}" will be hidden from retrieval but kept in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.archiveMemory(memory.id);
      if (mounted) _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not archive: $error')),
      );
    }
  }

  Future<void> _confirmDelete(Memory memory) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this?'),
        content: Text(
          '"${memory.title}" will be permanently forgotten. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.deleteMemory(memory.id);
      if (mounted) _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not forget: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New memory'),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onSubmit: _load,
            onClear: () {
              _searchController.clear();
              _load();
            },
          ),
          _CategoryChips(
            categories: _categories,
            selected: _category,
            onChanged: (value) {
              setState(() => _category = value);
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
                        child: _memories.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState(
                                    icon: Icons.memory_outlined,
                                    title: 'No memories yet',
                                    message:
                                        'Things you tell your Chief of Staff will show up here.',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: _memories.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final memory = _memories[index];
                                  return _MemoryCard(
                                    memory: memory,
                                    onTap: () =>
                                        _openEditor(existing: memory),
                                    onArchive:
                                        memory.status == 'ACTIVE'
                                            ? () => _confirmArchive(memory)
                                            : null,
                                    onDelete: () => _confirmDelete(memory),
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

// --- Search bar -------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: 'Search memories',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: onClear,
                tooltip: 'Clear',
                icon: const Icon(Icons.close, size: 18),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- Category chips ---------------------------------------------------------

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<(String?, String)> categories;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = categories[index];
          final isSelected = value == selected;
          return _MemChip(
            label: label,
            selected: isSelected,
            onTap: () => onChanged(value),
          );
        },
      ),
    );
  }
}

class _MemChip extends StatelessWidget {
  const _MemChip({
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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

// --- Memory card ------------------------------------------------------------

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.onTap,
    this.onArchive,
    this.onDelete,
  });

  final Memory memory;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isArchived = memory.status == 'ARCHIVED';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  memory.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isArchived ? scheme.onSurfaceVariant : null,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'edit') onTap();
                  if (value == 'archive' && onArchive != null) onArchive!();
                  if (value == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (onArchive != null)
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Forget',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            memory.content,
            style: theme.textTheme.bodyMedium,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MemBadge(
                label: _prettyEnum(memory.category),
                tone: _MemBadgeTone.neutral,
              ),
              _MemBadge(
                label: _prettyEnum(memory.importance),
                tone: switch (memory.importance) {
                  'HIGH' => _MemBadgeTone.danger,
                  'MEDIUM' => _MemBadgeTone.warning,
                  _ => _MemBadgeTone.neutral,
                },
              ),
              if (isArchived)
                const _MemBadge(
                  label: 'Archived',
                  tone: _MemBadgeTone.neutral,
                ),
              if (memory.accessCount > 0)
                _MemBadge(
                  label: 'Used ${memory.accessCount}×',
                  tone: _MemBadgeTone.primary,
                  icon: Icons.refresh,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _prettyEnum(String value) {
    return value
        .toLowerCase()
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

enum _MemBadgeTone { neutral, primary, warning, danger }

class _MemBadge extends StatelessWidget {
  const _MemBadge({
    required this.label,
    this.tone = _MemBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final _MemBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _MemBadgeTone.primary => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      _MemBadgeTone.warning => (
          const Color(0xFFFDF2D9),
          const Color(0xFF8A5A00)
        ),
      _MemBadgeTone.danger => (
          const Color(0xFFFBE0DE),
          const Color(0xFF8B1F17)
        ),
      _MemBadgeTone.neutral => (
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

// --- Memory editor sheet ----------------------------------------------------

class _MemoryEditorSheet extends StatefulWidget {
  const _MemoryEditorSheet({required this.service, this.existing});

  final PersonalApiService service;
  final Memory? existing;

  @override
  State<_MemoryEditorSheet> createState() => _MemoryEditorSheetState();
}

class _MemoryEditorSheetState extends State<_MemoryEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late String _category;
  late String _importance;
  bool _saving = false;
  String? _error;

  static const _categories = [
    'PERSONAL',
    'GOAL',
    'PROJECT',
    'PEOPLE',
    'PREFERENCE',
    'DECISION',
    'IMPORTANT_CONTEXT',
  ];

  static const _importances = ['HIGH', 'MEDIUM', 'LOW'];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _content = TextEditingController(text: widget.existing?.content ?? '');
    _category = widget.existing?.category ?? 'IMPORTANT_CONTEXT';
    _importance = widget.existing?.importance ?? 'MEDIUM';
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (content.isEmpty) {
      setState(() => _error = 'Content is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final Memory result;
      if (existing == null) {
        result = await widget.service.createMemory(Memory(
          id: '',
          category: _category,
          title: title,
          content: content,
          importance: _importance,
          status: 'ACTIVE',
          source: 'USER',
          confidence: 1,
          accessCount: 0,
        ));
      } else {
        result = await widget.service.updateMemory(Memory(
          id: existing.id,
          category: _category,
          title: title,
          content: content,
          importance: _importance,
          status: existing.status,
          source: existing.source,
          confidence: existing.confidence,
          accessCount: existing.accessCount,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
          lastAccessedAt: existing.lastAccessedAt,
          expiresAt: existing.expiresAt,
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
              widget.existing == null ? 'New memory' : 'Edit memory',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'A short label for this memory',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'What should your assistant remember?',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_memPretty(c)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _importance,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Importance'),
              items: _importances
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(_memPretty(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _importance = v!),
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
              label: Text(_saving ? 'Saving...' : 'Save memory'),
            ),
          ],
        ),
      ),
    );
  }
}

String _memPretty(String value) {
  return value
      .toLowerCase()
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}