import 'package:flutter/material.dart';

import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_header.dart';
import '../../models/assistant_profile.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({required this.service, super.key});

  final PersonalApiService service;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  AssistantProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  final _name = TextEditingController();
  String _personality = 'FRIENDLY';
  String _communication = 'BALANCED';
  String _length = 'BALANCED';
  String _proactivity = 'MEDIUM';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.service.getAssistantProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _name.text = profile.name;
        _personality = profile.personality;
        _communication = profile.communicationStyle;
        _length = profile.responseLength;
        _proactivity = profile.proactivity;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await widget.service.updateAssistantProfile(
        AssistantProfile(
          name: _name.text.trim().isEmpty ? 'Chief' : _name.text.trim(),
          personality: _personality,
          communicationStyle: _communication,
          responseLength: _length,
          proactivity: _proactivity,
        ),
      );
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _name.text = updated.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assistant settings saved')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _personalityLabels = {
    'PROFESSIONAL': 'Professional',
    'FRIENDLY': 'Friendly',
    'DIRECT': 'Direct',
    'SUPPORTIVE': 'Supportive',
    'STRATEGIC': 'Strategic',
  };

  static const _personalityHints = {
    'PROFESSIONAL': 'Businesslike, efficient tone.',
    'FRIENDLY': 'Warm and personable.',
    'DIRECT': 'Blunt, skips pleasantries.',
    'SUPPORTIVE': 'Empathetic and encouraging.',
    'STRATEGIC': 'Thinks several steps ahead.',
  };

  static const _communicationLabels = {
    'CONCISE': 'Concise',
    'BALANCED': 'Balanced',
    'DETAILED': 'Detailed',
  };

  static const _communicationHints = {
    'CONCISE': 'Short sentences, minimal preamble.',
    'BALANCED': 'Enough context to be useful.',
    'DETAILED': 'Explains reasoning and detail.',
  };

  static const _lengthLabels = {
    'SHORT': 'Short',
    'BALANCED': 'Balanced',
    'LONG': 'Long',
  };

  static const _lengthHints = {
    'SHORT': '1-3 sentences.',
    'BALANCED': 'A short paragraph.',
    'LONG': 'Multiple paragraphs when useful.',
  };

  static const _proactivityLabels = {
    'LOW': 'Low',
    'MEDIUM': 'Medium',
    'HIGH': 'High',
  };

  static const _proactivityHints = {
    'LOW': 'Answers only what was asked.',
    'MEDIUM': 'Suggests next steps when useful.',
    'HIGH': 'Proactively surfaces risks and follow-ups.',
  };

  String get _previewGreeting {
    final name = _name.text.trim().isEmpty ? 'Chief' : _name.text.trim();
    switch (_personality) {
      case 'PROFESSIONAL':
        return 'Good morning. I\'m $name. I\'ve reviewed your tasks and '
            'flagged two items that need attention today.';
      case 'DIRECT':
        return 'Morning. $name here. Two tasks overdue. Want the list?';
      case 'SUPPORTIVE':
        return 'Morning! I\'m $name. Hope you slept well. Ready to take on '
            'today - want me to walk through what\'s on your plate?';
      case 'STRATEGIC':
        return 'Morning. $name here. Before we start, I\'d like to align '
            'today\'s work with your weekly goals - two tasks are trending '
            'toward the deadline and one project needs a decision.';
      case 'FRIENDLY':
      default:
        return 'Morning! I\'m $name. You\'ve got a busy day ahead - '
            'want a quick rundown?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _loading || _error != null ? null : _save,
              tooltip: 'Save',
              icon: const Icon(Icons.check),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null && _profile == null
              ? ErrorView(message: _error!, onRetry: _load)
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      const SectionHeader(
                        title: 'Identity',
                        subtitle: 'What your assistant calls itself.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Assistant name',
                            hintText: 'e.g. Chief, Maya, Alex',
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Personality',
                        subtitle: 'The overall tone your assistant uses.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: _personalityLabels.entries.map((entry) {
                            return _OptionRow(
                              title: entry.value,
                              subtitle: _personalityHints[entry.key],
                              selected: _personality == entry.key,
                              onTap: () => setState(
                                () => _personality = entry.key,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Communication style',
                        subtitle: 'How much context your assistant gives.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: _communicationLabels.entries.map((entry) {
                            return _OptionRow(
                              title: entry.value,
                              subtitle: _communicationHints[entry.key],
                              selected: _communication == entry.key,
                              onTap: () => setState(
                                () => _communication = entry.key,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Response length',
                        subtitle: 'How long the average reply runs.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: _lengthLabels.entries.map((entry) {
                            return _OptionRow(
                              title: entry.value,
                              subtitle: _lengthHints[entry.key],
                              selected: _length == entry.key,
                              onTap: () => setState(
                                () => _length = entry.key,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Proactivity',
                        subtitle:
                            'How much your assistant volunteers vs. waits.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: _proactivityLabels.entries.map((entry) {
                            return _OptionRow(
                              title: entry.value,
                              subtitle: _proactivityHints[entry.key],
                              selected: _proactivity == entry.key,
                              onTap: () => setState(
                                () => _proactivity = entry.key,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Preview',
                        subtitle:
                            'A sample greeting with your current settings.',
                      ),
                      _PreviewCard(text: _previewGreeting),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label:
                            Text(_saving ? 'Saving...' : 'Save settings'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Assistant',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}