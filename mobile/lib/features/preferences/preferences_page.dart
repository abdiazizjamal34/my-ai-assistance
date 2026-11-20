
import 'package:flutter/material.dart';

import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_header.dart';
import '../../models/user_preferences.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({required this.service, super.key});

  final PersonalApiService service;

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  UserPreferences? _preferences;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  final _timezone = TextEditingController();
  final _language = TextEditingController();
  String _dateFormat = 'DMY';
  String _timeFormat = 'H24';
  String _weekStart = 'MONDAY';
  String _notifications = 'ALL';
  bool _morningEnabled = true;
  String _morningTime = '07:30';
  bool _eveningEnabled = true;
  String _eveningTime = '20:00';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timezone.dispose();
    _language.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await widget.service.getPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _timezone.text = prefs.timezone;
        _language.text = prefs.preferredLanguage;
        _dateFormat = prefs.dateFormat;
        _timeFormat = prefs.timeFormat;
        _weekStart = prefs.weekStartDay;
        _notifications = prefs.notificationPreference;
        _morningEnabled = prefs.morningPlanningEnabled;
        _morningTime = prefs.morningPlanningTime;
        _eveningEnabled = prefs.eveningReviewEnabled;
        _eveningTime = prefs.eveningReviewTime;
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
      final updated = await widget.service.updatePreferences(UserPreferences(
        timezone: _timezone.text.trim(),
        preferredLanguage: _language.text.trim(),
        dateFormat: _dateFormat,
        timeFormat: _timeFormat,
        weekStartDay: _weekStart,
        notificationPreference: _notifications,
        morningPlanningEnabled: _morningEnabled,
        morningPlanningTime: _morningTime,
        eveningReviewEnabled: _eveningEnabled,
        eveningReviewTime: _eveningTime,
      ));
      if (!mounted) return;
      setState(() => _preferences = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
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

  Future<void> _pickTime(bool isMorning) async {
    final current = isMorning ? _morningTime : _eveningTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 7,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: _timeFormat == 'H24'),
        child: child!,
      ),
    );
    if (picked == null) return;
    final formatted = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isMorning) {
        _morningTime = formatted;
      } else {
        _eveningTime = formatted;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
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
          : _error != null && _preferences == null
              ? ErrorView(message: _error!, onRetry: _load)
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      const SectionHeader(
                        title: 'Region & format',
                        subtitle: 'How dates and times appear in your assistant.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _Field(controller: _timezone, label: 'Timezone',
                                hint: 'e.g. Africa/Nairobi'),
                            const SizedBox(height: 12),
                            _Field(controller: _language,
                                label: 'Preferred language',
                                hint: 'e.g. en, fr, sw'),
                            const SizedBox(height: 12),
                            _Dropdown(
                              label: 'Date format',
                              value: _dateFormat,
                              items: const ['DMY', 'MDY', 'YMD'],
                              itemLabels: const {
                                'DMY': 'Day / Month / Year',
                                'MDY': 'Month / Day / Year',
                                'YMD': 'Year / Month / Day',
                              },
                              onChanged: (v) =>
                                  setState(() => _dateFormat = v!),
                            ),
                            const SizedBox(height: 12),
                            _Dropdown(
                              label: 'Time format',
                              value: _timeFormat,
                              items: const ['H12', 'H24'],
                              itemLabels: const {
                                'H12': '12-hour (2:30 PM)',
                                'H24': '24-hour (14:30)',
                              },
                              onChanged: (v) =>
                                  setState(() => _timeFormat = v!),
                            ),
                            const SizedBox(height: 12),
                            _Dropdown(
                              label: 'Week starts on',
                              value: _weekStart,
                              items: const ['MONDAY', 'SUNDAY'],
                              itemLabels: const {
                                'MONDAY': 'Monday',
                                'SUNDAY': 'Sunday',
                              },
                              onChanged: (v) =>
                                  setState(() => _weekStart = v!),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Notifications',
                        subtitle: 'When your assistant should reach out.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              value: 'ALL',
                              groupValue: _notifications,
                              onChanged: (v) =>
                                  setState(() => _notifications = v!),
                              title: const Text('All'),
                              subtitle: const Text('Planning, reviews, and reminders'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                            ),
                            RadioListTile<String>(
                              value: 'IMPORTANT',
                              groupValue: _notifications,
                              onChanged: (v) =>
                                  setState(() => _notifications = v!),
                              title: const Text('Important only'),
                              subtitle: const Text('Deadlines and overdue items'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                            ),
                            RadioListTile<String>(
                              value: 'NONE',
                              groupValue: _notifications,
                              onChanged: (v) =>
                                  setState(() => _notifications = v!),
                              title: const Text('None'),
                              subtitle: const Text('Silence everything'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                      const SectionHeader(
                        title: 'Daily planning',
                        subtitle: 'Optional check-ins to start and close your day.',
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _morningEnabled,
                              onChanged: (v) =>
                                  setState(() => _morningEnabled = v),
                              title: const Text('Morning planning'),
                              subtitle: const Text(
                                  'Review today\'s tasks when you start.'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                            ),
                            if (_morningEnabled)
                              _TimeRow(
                                label: 'Time',
                                value: _morningTime,
                                onTap: () => _pickTime(true),
                              ),
                            const Divider(height: 1),
                            SwitchListTile(
                              value: _eveningEnabled,
                              onChanged: (v) =>
                                  setState(() => _eveningEnabled = v),
                              title: const Text('Evening review'),
                              subtitle: const Text(
                                  'Reflect on progress and plan tomorrow.'),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                            ),
                            if (_eveningEnabled)
                              _TimeRow(
                                label: 'Time',
                                value: _eveningTime,
                                onTap: () => _pickTime(false),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Saving...' : 'Save preferences'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    this.itemLabels,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final Map<String, String>? itemLabels;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(itemLabels?[item] ?? item),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
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
            const SizedBox(width: 16),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}