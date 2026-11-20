import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../models/dashboard.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.apiClient,
    this.onOpenChat,
    super.key,
  });

  final ApiClient apiClient;
  final VoidCallback? onOpenChat;


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PersonalApiService _service;
  Dashboard _dashboard = Dashboard.empty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = PersonalApiService(widget.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await _service.getDashboard();
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Greeting --------------------------------------------------------------

  String get _greetingText {
    final name = _dashboard.greetingName;
    final hour = DateTime.now().hour;
    final period = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    if (name == null || name.trim().isEmpty) return period;
    return '$period, $name';
  }

  String get _subtitleText {
    final today = _dashboard.todayTaskCount;
    final overdue = _dashboard.overdueTaskCount;

    if (today == 0 && overdue == 0) {
      return 'Your plate is clear. Enjoy the calm.';
    }
    if (overdue > 0 && today > 0) {
      return '$today to do today · $overdue overdue';
    }
    if (overdue > 0) {
      return '$overdue overdue · catch up when you can';
    }
    return '$today task${today == 1 ? '' : 's'} to do today';
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chief of Staff'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _GreetingHeader(
                        greeting: _greetingText,
                        subtitle: _subtitleText,
                      ),
                      const SizedBox(height: 24),

                      // Stat cards row
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Today',
                              value: '${_dashboard.todayTaskCount}',
                              icon: Icons.checklist_outlined,
                              tone: _StatTone.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Overdue',
                              value: '${_dashboard.overdueTaskCount}',
                              icon: Icons.warning_amber_rounded,
                              tone: _dashboard.overdueTaskCount > 0
                                  ? _StatTone.danger
                                  : _StatTone.neutral,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Reminders',
                              value:
                                  '${_dashboard.upcomingReminderCount}',
                              icon: Icons.notifications_none,
                              tone: _StatTone.neutral,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Done today',
                              value:
                                  '${_dashboard.completedTodayCount}',
                              icon: Icons.check_circle_outline,
                              tone: _dashboard.completedTodayCount > 0
                                  ? _StatTone.success
                                  : _StatTone.neutral,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Next reminder card (only if there is one)
                      if (_dashboard.nextReminderAt != null) ...[
                        Text(
                          'Next up',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _NextReminderCard(
                          title: _dashboard.nextReminderTitle ??
                              'Reminder',
                          when: _dashboard.nextReminderAt!,
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Getting started / chat CTA
                      Text(
                        'Ask your Chief of Staff',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      AppCard(
                        onTap: widget.onOpenChat,
                
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.forum_outlined,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Open chat',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Plan, organize, and prioritize with a quick message.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// --- Sub-widgets ------------------------------------------------------------

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.greeting,
    required this.subtitle,
  });

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

enum _StatTone { primary, success, danger, neutral }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final _StatTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (bg, fg) = switch (tone) {
      _StatTone.primary => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      _StatTone.success => (
          const Color(0xFFDFF3E4),
          const Color(0xFF1A6B3A),
        ),
      _StatTone.danger => (
          const Color(0xFFFBE0DE),
          const Color(0xFF8B1F17),
        ),
      _StatTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NextReminderCard extends StatelessWidget {
  const _NextReminderCard({
    required this.title,
    required this.when,
  });

  final String title;
  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.alarm,
              size: 20,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeTime(when),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime when) {
    final now = DateTime.now();
    final diff = when.difference(now);
    if (diff.isNegative) return 'Overdue';

    if (diff.inMinutes < 60) {
      return 'In ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'In ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (when.year == tomorrow.year &&
        when.month == tomorrow.month &&
        when.day == tomorrow.day) {
      return 'Tomorrow · $hh:$mm';
    }
    return '${when.day}/${when.month}/${when.year} · $hh:$mm';
  }
}