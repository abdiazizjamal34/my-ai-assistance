import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/notifications/reminder_scheduler.dart';

import '../../core/auth/token_store.dart';
import '../../core/config/app_config.dart';
import '../../core/network/personal_api_service.dart';
import '../../core/network/streaming_client.dart';
import '../../models/memory_candidate.dart';
import '../voice/voice_assistant_service.dart';
import '../voice/voice_types.dart';

class AssistantChatPage extends StatefulWidget {
  const AssistantChatPage({
    required this.service,
    required this.authUserId,
    super.key,
  });

  final PersonalApiService service;
  final String authUserId;

  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _ChatMessage {
  _ChatMessage(
    this.text, {
    required this.fromAssistant,
    this.memoryUsed = false,
  });

  String text;
  final bool fromAssistant;
  bool memoryUsed;
}

class _ConversationSummary {
  const _ConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messageCount,
  });

  final String id;
  final String? title;
  final DateTime updatedAt;
  final int messageCount;

  factory _ConversationSummary.fromJson(Map<String, dynamic> json) {
    return _ConversationSummary(
      id: json['id'] as String,
      title: json['title'] as String?,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class _AssistantChatPageState extends State<AssistantChatPage>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  final _store = TokenStore();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final VoiceAssistantService _voice;
  VoiceTurn? _handledVoiceTurn;
  String? _liveVoiceTranscript;
  String? _conversationId;

  StreamSubscription<AgentStreamEvent>? _streamSub;

  List<_ConversationSummary> _conversations = const [];
  bool _loadingConversations = false;
  bool _loadingHistory = true;
  bool _sending = false;
  String? _error;
  String _toolStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = VoiceAssistantService(apiService: widget.service)
      ..addListener(_onVoiceChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _voice.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _voice.cancel();
      _streamSub?.cancel();
    }
  }

  // --- Boot ------------------------------------------------------------------

  Future<void> _bootstrap() async {
    // 1. Refresh conversation list in the background.
    _refreshConversations();

    // 2. Load the last conversation's messages, if any.
    await _loadLastConversation();
  }

  Future<void> _refreshConversations() async {
    if (widget.authUserId.isEmpty) return;
    setState(() => _loadingConversations = true);
    try {
      final rows = await widget.service.getConversations(limit: 30);
      if (!mounted) return;
      setState(() {
        _conversations =
            rows.map(_ConversationSummary.fromJson).toList(growable: false);
      });
    } catch (_) {
      // Silent — the list is a convenience, not critical.
    } finally {
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  Future<void> _loadLastConversation() async {
    if (widget.authUserId.isEmpty) {
      if (mounted) setState(() => _loadingHistory = false);
      return;
    }
    try {
      final lastId = await _store.readLastConversationId(widget.authUserId);
      if (lastId == null) {
        if (mounted) setState(() => _loadingHistory = false);
        return;
      }
      await _loadConversation(lastId, resume: true);
    } catch (_) {
      await _store.clearLastConversationId(widget.authUserId);
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadConversation(String id, {bool resume = false}) async {
    if (!resume && mounted) {
      setState(() {
        _loadingHistory = true;
        _error = null;
      });
    }
    try {
      final rows = await widget.service.getConversationMessages(id);
      if (!mounted) return;
      setState(() {
        _conversationId = id;
        _messages
          ..clear()
          ..addAll(rows.map(_messageFromRow).whereType<_ChatMessage>());
      });
      _scrollToBottom(jump: true);
      await _store.saveLastConversationId(widget.authUserId, id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not load that conversation.');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  _ChatMessage? _messageFromRow(Map<String, dynamic> row) {
    final role = row['role'] as String?;
    final content = row['content'] as String?;
    if (role == null || content == null) return null;
    final metadata = row['metadata'];
    final memoryUsed =
        metadata is Map && (metadata['memoryUsed'] == true);
    return _ChatMessage(
      content,
      fromAssistant: role == 'assistant',
      memoryUsed: memoryUsed,
    );
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _persistConversationId(String id) async {
    if (widget.authUserId.isEmpty) return;
    await _store.saveLastConversationId(widget.authUserId, id);
  }

  // --- Send ------------------------------------------------------------------

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    final assistantMessage = _ChatMessage('', fromAssistant: true);

    setState(() {
      _messages.add(_ChatMessage(text, fromAssistant: false));
      _messages.add(assistantMessage);
      _sending = true;
      _error = null;
      _toolStatus = '';
    });
    _scrollToBottom();

    _streamSub?.cancel();
    _streamSub = widget.service
        .streamAgentMessage(text, conversationId: _conversationId)
        .listen(
      (event) {
        if (!mounted) return;
        switch (event.type) {
          case 'meta':
            final id = event.conversationId;
            if (id != null && id != _conversationId) {
              setState(() => _conversationId = id);
              _persistConversationId(id);
            }
            break;
          case 'tool':
            setState(() {
              _toolStatus =
                  '${event.toolSuccess == true ? "Using" : "Tried"} ${event.toolName}...';
            });
            break;
          case 'text':
            setState(() {
              assistantMessage.text += event.delta ?? '';
              _toolStatus = '';
            });
            _scrollToBottom();
            break;
          case 'done':
            setState(() {
              if ((event.message ?? '').isNotEmpty &&
                  assistantMessage.text.trim().isEmpty) {
                assistantMessage.text = event.message!;
              }
              _toolStatus = '';
            });
            _handleMemoryCandidates(event.memoryCandidates ?? const []);
            _refreshConversations();
             unawaited(
    ReminderScheduler(service: widget.service).sync(),
  );
            break;
          case 'error':
            setState(() {
              _error = event.message ?? 'The assistant could not respond.';
              if (assistantMessage.text.trim().isEmpty) {
                _messages.remove(assistantMessage);
              }
              _toolStatus = '';
            });
            break;
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = 'The assistant could not respond right now.';
          if (assistantMessage.text.trim().isEmpty) {
            _messages.remove(assistantMessage);
          }
          _toolStatus = '';
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _sending = false);
        _scrollToBottom();
      },
      cancelOnError: true,
    );
  }

  Future<void> _handleMemoryCandidates(List<Map<String, dynamic>> raw) async {
    for (final item in raw) {
      try {
        final candidate = MemoryCandidate.fromJson(item);
        await _confirmMemory(candidate);
      } catch (_) {}
    }
  }

  Future<void> _startNewConversation() async {
    _streamSub?.cancel();
    if (widget.authUserId.isNotEmpty) {
      await _store.clearLastConversationId(widget.authUserId);
    }
    setState(() {
      _conversationId = null;
      _messages.clear();
      _error = null;
      _toolStatus = '';
      _sending = false;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState!.closeDrawer();
    }
  }

  Future<void> _selectConversation(String id) async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState!.closeDrawer();
    }
    if (id == _conversationId && _messages.isNotEmpty) return;
    await _loadConversation(id);
  }

  // --- Memory confirmation ---------------------------------------------------

  Future<void> _confirmMemory(MemoryCandidate candidate) async {
    if (!mounted) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remember this?'),
        content: Text('I can remember:\n\n${candidate.content}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remember this'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await widget.service.saveMemoryCandidate(candidate);
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'The memory could not be saved right now.');
        }
      }
    }
  }

  // --- Voice -----------------------------------------------------------------

  void _onVoiceChanged() {
    if (!mounted) return;
    final turn = _voice.lastTurn;
    if (turn != null && !identical(turn, _handledVoiceTurn)) {
      _handledVoiceTurn = turn;
      _liveVoiceTranscript = null;
      setState(() {
        if (turn.conversationId != null) {
          _conversationId = turn.conversationId;
          _persistConversationId(turn.conversationId!);
        }
        _messages.add(_ChatMessage(turn.transcript, fromAssistant: false));
        _messages.add(
          _ChatMessage(
            turn.response,
            fromAssistant: true,
            memoryUsed: turn.memoryUsed,
          ),
        );
      });
      _scrollToBottom();
      _refreshConversations();
      if (turn.memoryCandidates.isNotEmpty) {
        _voice.stopSpeaking().then((_) {
          for (final candidate in turn.memoryCandidates) {
            _confirmMemory(candidate);
          }
        });
      }
    }
    if (_voice.state == VoiceSessionState.listening ||
        _voice.state == VoiceSessionState.processing) {
      _liveVoiceTranscript = _voice.transcript;
    }
    setState(() {});
  }

  Future<void> _toggleVoice() async {
    if (_voice.state == VoiceSessionState.listening) {
      await _voice.stopListening();
      return;
    }
    await _voice.startListening(conversationId: _conversationId);
  }

  String get _voiceStatus {
    return switch (_voice.state) {
      VoiceSessionState.requestingPermission =>
        'Requesting microphone permission...',
      VoiceSessionState.ready => 'Ready',
      VoiceSessionState.listening => 'Listening...',
      VoiceSessionState.processing => 'Thinking...',
      VoiceSessionState.speaking =>
        'Speaking... Tap the microphone to interrupt.',
      VoiceSessionState.error =>
        _voice.errorMessage ?? 'Something went wrong. Tap to try again.',
      VoiceSessionState.idle => 'Tap the microphone to speak',
    };
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _ConversationDrawer(
        conversations: _conversations,
        currentId: _conversationId,
        loading: _loadingConversations,
        onRefresh: _refreshConversations,
        onSelect: (id) => _selectConversation(id),
        onNewConversation: _startNewConversation,
      ),
      appBar: AppBar(
        title: const Text('AI Chief of Staff'),
        actions: [
          IconButton(
            onPressed: _startNewConversation,
            tooltip: 'New conversation',
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const _EmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isStreaming = _sending &&
                              message.fromAssistant &&
                              index == _messages.length - 1 &&
                              message.text.isEmpty;
                          return _ChatBubble(
                            text: message.text,
                            fromAssistant: message.fromAssistant,
                            memoryUsed: message.memoryUsed,
                            showTypingIndicator: isStreaming,
                          );
                        },
                      ),
          ),
          if (_toolStatus.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 8),
                  Text(_toolStatus, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          if (_liveVoiceTranscript?.trim().isNotEmpty ?? false)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _liveVoiceTranscript!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          if (AppConfig.voiceEnabled)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_voiceStatus, style: theme.textTheme.bodySmall),
            ),
          if (_error != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          _Composer(
            controller: _controller,
            sending: _sending,
            voiceEnabled: AppConfig.voiceEnabled,
            voiceState: _voice.state,
            onToggleVoice: _toggleVoice,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// --- Drawer ------------------------------------------------------------------

class _ConversationDrawer extends StatelessWidget {
  const _ConversationDrawer({
    required this.conversations,
    required this.currentId,
    required this.loading,
    required this.onRefresh,
    required this.onSelect,
    required this.onNewConversation,
  });

  final List<_ConversationSummary> conversations;
  final String? currentId;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(String id) onSelect;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Conversations',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: loading ? null : () => onRefresh(),
                    tooltip: 'Refresh',
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNewConversation,
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('New conversation'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          loading
                              ? 'Loading...'
                              : 'No conversations yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: conversations.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final c = conversations[index];
                          final selected = c.id == currentId;
                          return _ConversationTile(
                            title: c.title?.trim().isNotEmpty == true
                                ? c.title!.trim()
                                : 'Untitled conversation',
                            subtitle: _formatTimestamp(c.updatedAt),
                            messageCount: c.messageCount,
                            selected: selected,
                            onTap: () => onSelect(c.id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (diff == 0) return 'Today · $hh:$mm';
    if (diff == 1) return 'Yesterday · $hh:$mm';
    if (diff < 7) return '$diff days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.title,
    required this.subtitle,
    required this.messageCount,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int messageCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primaryContainer : Colors.transparent;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subtitle · $messageCount message${messageCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? fg.withOpacity(0.7)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Empty / bubble / typing indicator / composer --------------------------

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  static const _suggestions = [
    'Plan my day',
    'What\'s on my plate?',
    'Add a task for tomorrow',
    'What do you remember about me?',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('Ask your Chief of Staff',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Plan, organize, and prioritize with a quick message or voice command.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions
                  .map((text) => ActionChip(
                        label: Text(text),
                        onPressed: () {},
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.fromAssistant,
    required this.memoryUsed,
    this.showTypingIndicator = false,
  });

  final String text;
  final bool fromAssistant;
  final bool memoryUsed;
  final bool showTypingIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Align(
      alignment: fromAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              fromAssistant ? scheme.surfaceContainerHighest : scheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromAssistant ? 4 : 16),
            bottomRight: Radius.circular(fromAssistant ? 16 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTypingIndicator)
              _TypingIndicator(
                color: fromAssistant
                    ? scheme.onSurfaceVariant
                    : scheme.onPrimary,
              )
            else
              SelectableText(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: fromAssistant ? scheme.onSurface : scheme.onPrimary,
                  height: 1.4,
                ),
              ),
            if (memoryUsed && text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.memory_outlined,
                    size: 12,
                    color: fromAssistant
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Personal context',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fromAssistant
                          ? scheme.onSurfaceVariant
                          : scheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.color});

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_controller.value + i * 0.2) % 1.0;
          final opacity = 0.3 + 0.7 * (1 - (phase * 2 - 1).abs()).clamp(0, 1);
          return Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.voiceEnabled,
    required this.voiceState,
    required this.onToggleVoice,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool voiceEnabled;
  final VoiceSessionState voiceState;
  final VoidCallback onToggleVoice;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Message your Chief of Staff',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (voiceEnabled)
                IconButton.filledTonal(
                  onPressed: voiceState == VoiceSessionState.processing
                      ? null
                      : onToggleVoice,
                  tooltip: voiceState == VoiceSessionState.listening
                      ? 'Stop listening'
                      : voiceState == VoiceSessionState.speaking
                          ? 'Interrupt'
                          : 'Voice input',
                  icon: Icon(
                    voiceState == VoiceSessionState.listening
                        ? Icons.stop
                        : Icons.mic_none,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : onSend,
                tooltip: 'Send',
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ),
      ),
    );
  }
}