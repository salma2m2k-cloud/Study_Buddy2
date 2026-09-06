import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_service.dart';
import '../app_state.dart';
import '../models.dart';
import '../utils.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = ApiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Conversation? _findConvo(AppState state) {
    try {
      return state.conversations.firstWhere((c) => c.id == widget.conversationId);
    } catch (_) {
      return null;
    }
  }

  String _buildSystemPrompt(AppState state) {
    final now = DateTime.now();
    final todays = state.tasks
        .where((t) => !t.done && t.dueDateTime != null && isSameDay(t.dueDateTime!, now))
        .map((t) => t.title)
        .toList();
    final overdue = state.tasks
        .where((t) => !t.done && t.dueDateTime != null && t.dueDateTime!.isBefore(now) && !isSameDay(t.dueDateTime!, now))
        .map((t) => t.title)
        .toList();
    final upcoming = state.tasks.where((t) => !t.done && t.dueDateTime != null && t.dueDateTime!.isAfter(now)).toList()
      ..sort((a, b) => a.dueDateTime!.compareTo(b.dueDateTime!));
    final classNames = state.classes.map((c) => c.subject.isNotEmpty ? c.subject : c.name).toSet().take(10).toList();
    final weekMs = state.sessions
        .where((s) => now.difference(DateTime.parse(s.endedAt)).inDays < 7)
        .fold<int>(0, (a, s) => a + s.durationMs);

    final parts = <String>['Current date/time: $now.'];
    if (classNames.isNotEmpty) parts.add("The student's classes/subjects: ${classNames.join(', ')}.");
    if (todays.isNotEmpty) parts.add('Tasks due today: ${todays.join(', ')}.');
    if (overdue.isNotEmpty) parts.add('Overdue tasks: ${overdue.join(', ')}.');
    if (upcoming.isNotEmpty) {
      parts.add('Upcoming tasks: ${upcoming.take(5).map((t) => t.title).join(', ')}.');
    }
    if (weekMs > 0) parts.add('Studied ${durationHuman(weekMs)} this week.');

    return 'You are Sage, the friendly AI study buddy inside the Study Buddy app. You help the student plan '
        'their studying, explain concepts clearly, quiz them, and keep them encouraged without being saccharine. '
        "Use the student's saved classes, tasks, and recent study activity below when it's relevant — for example, "
        'when asked what to study, prioritize overdue and today\'s tasks first. Keep replies concise and '
        'conversational unless the student clearly wants depth. ${parts.join(' ')}';
  }

  Future<void> _send(AppState state) async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();

    var convo = _findConvo(state);
    convo ??= await state.createConversation();

    final userMsg = ChatMessage(id: newId(), role: 'user', content: text, ts: DateTime.now().millisecondsSinceEpoch);
    convo.messages.add(userMsg);
    if (convo.messages.length == 1) convo.title = text.length > 40 ? text.substring(0, 40) : text;
    convo.updatedAt = DateTime.now().toIso8601String();
    await state.saveConversation(convo);
    setState(() => _sending = true);
    _scrollToBottom();

    String replyText;
    bool isError = false;
    try {
      
      final history = convo.messages
          .where((m) => !m.error)
          .toList()
          .reversed
          .take(14)
          .toList()
          .reversed
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      replyText = await _api.sendChat(system: _buildSystemPrompt(state), messages: history);
    } on ApiException catch (e) {
      replyText = e.message;
      isError = true;
    } catch (_) {
      replyText = 'Something went wrong reaching Sage. Check your connection and try again.';
      isError = true;
    }

    final replyMsg = ChatMessage(
      id: newId(),
      role: 'assistant',
      content: replyText,
      ts: DateTime.now().millisecondsSinceEpoch,
      error: isError,
    );
    convo.messages.add(replyMsg);
    convo.updatedAt = DateTime.now().toIso8601String();
    await state.saveConversation(convo);
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final convo = _findConvo(state);
    final messages = convo?.messages ?? <ChatMessage>[];

    return Scaffold(
      appBar: AppBar(title: Text(convo?.title.isNotEmpty == true ? convo!.title : 'New chat')),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Ask for a study plan, a quick explanation, or a quiz on anything.', textAlign: TextAlign.center),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= messages.length) {
                        return _bubble(context, role: 'assistant', content: '…', error: false, typing: true);
                      }
                      final m = messages[i];
                      return _bubble(context, role: m.role, content: m.content, error: m.error, typing: false);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(state),
                      decoration: const InputDecoration(
                        hintText: 'Message Sage...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(state),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, {required String role, required String content, required bool error, required bool typing}) {
    final isUser = role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.onSurface
              : error
                  ? scheme.error.withValues(alpha: 0.12)
                  : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: typing
            ? const SizedBox(
                width: 24,
                height: 14,
                child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            : Text(
                content,
                style: TextStyle(color: isUser ? scheme.surface : (error ? scheme.error : null)),
              ),
      ),
    );
  }
}
