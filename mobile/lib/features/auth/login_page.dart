import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.apiClient,
    required this.auth,
    super.key,
  });

  final ApiClient apiClient;
  final AuthController auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();

  bool _registering = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final path = _registering ? '/api/auth/register' : '/api/auth/login';
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        if (_registering && _displayName.text.trim().isNotEmpty)
          'displayName': _displayName.text.trim(),
      };

      final response = await widget.apiClient.postJson(path, body);
      final data = response['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final userId = data['userId'] as String;

      await widget.auth.login(token: token, userId: userId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final message = error.toString();
        _error = message.startsWith('Exception: ')
            ? message.substring('Exception: '.length)
            : message;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.support_agent,
                      size: 32,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Personal AI Chief of Staff',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _registering
                        ? 'Create an account to get started.'
                        : 'Sign in to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (_registering)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _displayName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Display name (optional)',
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autocorrect: false,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_registering
                            ? Icons.person_add_alt
                            : Icons.login),
                    label: Text(
                      _submitting
                          ? 'Please wait...'
                          : _registering
                              ? 'Create account'
                              : 'Sign in',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _registering = !_registering;
                              _error = null;
                            }),
                    child: Text(
                      _registering
                          ? 'I already have an account'
                          : 'Create a new account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}