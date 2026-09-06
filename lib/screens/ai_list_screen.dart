import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/empty_state.dart';
import 'ai_chat_screen.dart';

class AiListScreen extends StatelessWidget {
  const AiListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final convos = [...state.conversations]..sort((a, b) => DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt)));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final convo = await state.createConversation();
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiChatScreen(conversationId: convo.id)));
          }
        },
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: convos.isEmpty
          ? const EmptyState(
              icon: Icons.auto_awesome_rounded,
              title: 'Say hello to Sage',
              message: 'Start a chat to get a study plan, an explanation, or a quiz on anything.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: convos.length,
              itemBuilder: (context, i) {
                final c = convos[i];
                final preview = c.messages.isNotEmpty ? c.messages.last.content : 'No messages yet';
                return Dismissible(
                  key: ValueKey(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => state.deleteConversation(c.id),
                  child: ListTile(
                    leading: const CircleAvatar(child: Text('✦')),
                    title: Text(c.title.isEmpty ? 'New chat' : c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => AiChatScreen(conversationId: c.id))),
                  ),
                );
              },
            ),
    );
  }
}
