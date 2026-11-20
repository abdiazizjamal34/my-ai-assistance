import 'package:flutter/material.dart';

import '../../core/network/personal_api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/section_header.dart';
import '../../models/user_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({required this.service, super.key});

  final PersonalApiService service;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _bio = TextEditingController();
  final _timezone = TextEditingController();
  final _language = TextEditingController();
  final _country = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _email.dispose();
    _bio.dispose();
    _timezone.dispose();
    _language.dispose();
    _country.dispose();
    super.dispose();
  }

  void _fillControllers(UserProfile profile) {
    _firstName.text = profile.firstName ?? '';
    _lastName.text = profile.lastName ?? '';
    _displayName.text = profile.displayName ?? '';
    _email.text = profile.email ?? '';
    _bio.text = profile.bio ?? '';
    _timezone.text = profile.timezone;
    _language.text = profile.preferredLanguage;
    _country.text = profile.locationCountry ?? '';
  }

  Future<void> _load() async {
    try {
      final profile = await widget.service.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _fillControllers(profile);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startEditing() {
    final profile = _profile;
    if (profile != null) _fillControllers(profile);
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    final profile = _profile;
    if (profile != null) _fillControllers(profile);
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final existing = _profile;
    if (existing == null) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.service.updateProfile(UserProfile(
        id: existing.id,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        displayName: _displayName.text.trim(),
        email: _email.text.trim(),
        bio: _bio.text.trim(),
        timezone: _timezone.text.trim(),
        preferredLanguage: _language.text.trim(),
        locationCountry: _country.text.trim(),
      ));
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _fillControllers(updated);
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
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

  // --- Derived display values ------------------------------------------------

  String get _displayNameOrFallback {
    final name = (_profile?.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final first = (_profile?.firstName ?? '').trim();
    final last = (_profile?.lastName ?? '').trim();
    final combined = '$first $last'.trim();
    return combined.isEmpty ? 'Your profile' : combined;
  }

  String get _initials {
    final first = (_profile?.firstName ?? '').trim();
    final last = (_profile?.lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) {
      final display = (_profile?.displayName ?? '').trim();
      return display.isEmpty ? '?' : display[0].toUpperCase();
    }
    return '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
        .toUpperCase();
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null && _profile == null
              ? ErrorView(message: _error!, onRetry: _load)
              : SafeArea(
                  child: _editing ? _buildEditMode() : _buildViewMode(),
                ),
      bottomNavigationBar: _editing && _profile != null
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving...' : 'Save changes'),
              ),
            )
          : null,
    );
  }

  // --- View mode -------------------------------------------------------------

  Widget _buildViewMode() {
    final profile = _profile!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _ProfileHeader(
          initials: _initials,
          displayName: _displayNameOrFallback,
          email: profile.email,
        ),
        const SizedBox(height: 28),

        if ((profile.bio ?? '').trim().isNotEmpty) ...[
          const SectionHeader(title: 'About'),
          AppCard(
            child: Text(
              profile.bio!.trim(),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 28),
        ],

        const SectionHeader(title: 'Contact'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.person_outline,
                label: 'First name',
                value: profile.firstName,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Last name',
                value: profile.lastName,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Display name',
                value: profile.displayName,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: profile.email,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        const SectionHeader(title: 'Location & language'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.public,
                label: 'Timezone',
                value: profile.timezone,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.translate,
                label: 'Language',
                value: profile.preferredLanguage,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Country',
                value: profile.locationCountry,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _startEditing,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile'),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Member since ${_formatDate(profile.id)}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  String _formatDate(String _) {
    // Placeholder — replace with real createdAt when available on UserProfile.
    return 'today';
  }

  // --- Edit mode -------------------------------------------------------------

  Widget _buildEditMode() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        _ProfileHeader(
          initials: _initials,
          displayName: _displayName.text.isEmpty
              ? 'Your name'
              : _displayName.text,
          email: _email.text,
        ),
        const SizedBox(height: 28),

        const SectionHeader(title: 'Basic info'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _Field(
                controller: _firstName,
                label: 'First name',
                textCapitalization: TextCapitalization.words,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _lastName,
                label: 'Last name',
                textCapitalization: TextCapitalization.words,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _displayName,
                label: 'Display name',
                textCapitalization: TextCapitalization.words,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _bio,
                label: 'About you',
                maxLines: 3,
                hint: 'A short bio the assistant can reference.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),
        const SectionHeader(title: 'Location & language'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _Field(
                controller: _timezone,
                label: 'Timezone',
                hint: 'e.g. Africa/Nairobi',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _language,
                label: 'Preferred language',
                hint: 'e.g. en, fr, sw',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _country,
                label: 'Country or region',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Shared widgets ----------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.displayName,
    required this.email,
  });

  final String initials;
  final String displayName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if ((email ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  email!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasValue = (value ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value!.trim() : '—',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: hasValue
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}