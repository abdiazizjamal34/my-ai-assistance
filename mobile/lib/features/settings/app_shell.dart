import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/personal_api_service.dart';
import '../agent/assistant_chat_page.dart';
import '../assistant/assistant_page.dart';
import '../goals/goals_page.dart';
import '../home/home_page.dart';
import '../memory/memories_page.dart';
import '../preferences/preferences_page.dart';
import '../profile/profile_page.dart';
import '../reminders/reminders_page.dart';
import '../tasks/tasks_page.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/notifications/notification_service.dart';


class AppShell extends StatefulWidget {
  const AppShell({
    required this.apiClient,
    required this.onSignOut,
    required this.authUserId,
    super.key,
  });

  final ApiClient apiClient;
  final Future<void> Function() onSignOut;
  final String authUserId;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _moreIndex = 4;
  static const _profileIndex = 5;
  static const _preferencesIndex = 6;
  static const _assistantIndex = 7;
  static const _goalsIndex = 8;
  static const _memoryIndex = 9;
  ReminderScheduler? _scheduler;

  PersonalApiService? _service;
  List<Widget>? _pages;

  @override
  void initState() {
    super.initState();
    final service = PersonalApiService(widget.apiClient);
    _service = service;

     _scheduler = ReminderScheduler(service: service);
  

    _pages = [
  HomePage(apiClient: widget.apiClient, onOpenChat: () => setState(() => _index = 1),),
  AssistantChatPage(
    service: service,
    authUserId: widget.authUserId,
  ),
  TasksPage(service: service),
  RemindersPage(service: service),
  const _MorePlaceholderPage(),
  ProfilePage(service: service),
  PreferencesPage(service: service),
  AssistantPage(service: service),
  GoalsPage(service: service),
  MemoriesPage(service: service),
];

 WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationService.instance.requestPermission();
    await _scheduler!.sync();
  });
  }

  Future<void> _openMore() async {
    final scheme = Theme.of(context).colorScheme;
    final choice = await showModalBottomSheet<_MoreDestination>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
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
                Text('More', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _MoreTile(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  subtitle: 'Your name, timezone, and bio',
                  onTap: () =>
                      Navigator.pop(context, _MoreDestination.profile),
                ),
                _MoreTile(
                  icon: Icons.tune,
                  label: 'Preferences',
                  subtitle: 'Formats, notifications, planning',
                  onTap: () =>
                      Navigator.pop(context, _MoreDestination.preferences),
                ),
                _MoreTile(
                  icon: Icons.smart_toy_outlined,
                  label: 'Assistant',
                  subtitle: 'Personality and communication style',
                  onTap: () =>
                      Navigator.pop(context, _MoreDestination.assistant),
                ),
                _MoreTile(
                  icon: Icons.flag_outlined,
                  label: 'Goals',
                  subtitle: 'Long-term outcomes you are working toward',
                  onTap: () =>
                      Navigator.pop(context, _MoreDestination.goals),
                ),
                _MoreTile(
                  icon: Icons.memory_outlined,
                  label: 'Memory',
                  subtitle: 'What your assistant remembers about you',
                  onTap: () =>
                      Navigator.pop(context, _MoreDestination.memory),
                ),
                const Divider(height: 24),
                _MoreTile(
                  icon: Icons.logout,
                  label: 'Sign out',
                  subtitle: 'Sign out of this device',
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.onSignOut();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final targetIndex = switch (choice) {
      _MoreDestination.profile => _profileIndex,
      _MoreDestination.preferences => _preferencesIndex,
      _MoreDestination.assistant => _assistantIndex,
      _MoreDestination.goals => _goalsIndex,
      _MoreDestination.memory => _memoryIndex,
    };

    setState(() => _index = targetIndex);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // When the user is on a More sub-page (index >= 5), keep the More tab
    // highlighted. `NavigationBar.selectedIndex` in current Flutter SDKs is
    // non-nullable `int`, so we can't pass `null` or `-1`.
    final selectedIndex = _index < 5 ? _index : _moreIndex;

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          if (index == _moreIndex) {
            _openMore();
            return;
          }
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

// --- More sheet helpers -----------------------------------------------------

enum _MoreDestination { profile, preferences, assistant, goals, memory }

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// --- Placeholder for the "More" slot ---------------------------------------

class _MorePlaceholderPage extends StatelessWidget {
  const _MorePlaceholderPage();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}