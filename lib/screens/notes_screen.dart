import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/empty_state.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filtered = state.notes.where((n) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => DateTime.parse(b.updatedAt).compareTo(DateTime.parse(a.updatedAt)));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final note = Note(id: newId(), title: '', body: '', updatedAt: DateTime.now().toIso8601String());
          await state.upsertNote(note);
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: note.id)));
          }
        },
        child: const Icon(Icons.note_add_outlined),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search notes',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(icon: Icons.description_outlined, title: 'No notes found', message: 'Create a note to start writing.')
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final n = filtered[i];
                      return ListTile(
                        title: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(n.body.isEmpty ? 'No content yet' : n.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: n.id))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});
  final String noteId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _title;
  late TextEditingController _body;

  Note? _find(AppState state) {
    try {
      return state.notes.firstWhere((n) => n.id == widget.noteId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final note = _find(state);
    _title = TextEditingController(text: note?.title ?? '');
    _body = TextEditingController(text: note?.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final state = context.read<AppState>();
    final note = _find(state);
    if (note == null) return;
    note.title = _title.text;
    note.body = _body.text;
    note.updatedAt = DateTime.now().toIso8601String();
    state.upsertNote(note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await context.read<AppState>().deleteNote(widget.noteId);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(hintText: 'Untitled', border: InputBorder.none),
                onChanged: (_) => _save(),
              ),
              const Divider(height: 24),
              Expanded(
                child: TextField(
                  controller: _body,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(hintText: 'Start writing...', border: InputBorder.none),
                  onChanged: (_) => _save(),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
