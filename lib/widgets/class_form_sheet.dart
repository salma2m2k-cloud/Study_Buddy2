import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';

Future<void> showClassForm(BuildContext context, {ClassItem? existing, int? defaultDay}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ClassFormSheet(existing: existing, defaultDay: defaultDay),
  );
}

class _ClassFormSheet extends StatefulWidget {
  const _ClassFormSheet({this.existing, this.defaultDay});
  final ClassItem? existing;
  final int? defaultDay;

  @override
  State<_ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends State<_ClassFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _subject;
  late final TextEditingController _teacher;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late int _day;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _reminder = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _subject = TextEditingController(text: c?.subject ?? '');
    _teacher = TextEditingController(text: c?.teacher ?? '');
    _location = TextEditingController(text: c?.location ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _day = c?.day ?? widget.defaultDay ?? DateTime.now().weekday % 7;
    _reminder = c?.reminder ?? true; // reminders matter most here — default on
    if (c?.startTime != null && c!.startTime!.isNotEmpty) {
      final p = c.startTime!.split(':').map(int.parse).toList();
      _start = TimeOfDay(hour: p[0], minute: p[1]);
    }
    if (c?.endTime != null && c!.endTime!.isNotEmpty) {
      final p = c.endTime!.split(':').map(int.parse).toList();
      _end = TimeOfDay(hour: p[0], minute: p[1]);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _teacher.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _fmt(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start ?? const TimeOfDay(hour: 9, minute: 0));
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _end ?? const TimeOfDay(hour: 10, minute: 0));
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the class a name first')));
      return;
    }
    if (_reminder && _start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a start time so the reminder knows when to fire')),
      );
      return;
    }
    final state = context.read<AppState>();

    if (widget.existing != null) {
      final c = widget.existing!;
      c.name = name;
      c.subject = _subject.text.trim();
      c.teacher = _teacher.text.trim();
      c.day = _day;
      c.startTime = _fmt(_start);
      c.endTime = _fmt(_end);
      c.location = _location.text.trim();
      c.notes = _notes.text.trim();
      c.reminder = _reminder;
      c.reminderLead = state.settings.reminderLead;
      await state.updateClass(c);
    } else {
      await state.addClass(ClassItem(
        id: newId(),
        name: name,
        subject: _subject.text.trim(),
        teacher: _teacher.text.trim(),
        day: _day,
        startTime: _fmt(_start),
        endTime: _fmt(_end),
        location: _location.text.trim(),
        notes: _notes.text.trim(),
        reminder: _reminder,
        reminderLead: state.settings.reminderLead,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await context.read<AppState>().deleteClass(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final leadMin = context.watch<AppState>().settings.reminderLead;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(isEdit ? 'Edit class' : 'New class', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: !isEdit,
              decoration: const InputDecoration(labelText: 'Class name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _teacher,
                    decoration: const InputDecoration(labelText: 'Teacher', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
              items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(kDayNamesFull[i]))),
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(_start == null ? 'Start time' : _start!.format(context)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(_end == null ? 'End time' : _end!.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location / link', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me before it starts'),
              subtitle: Text('$leadMin min before, every week — change the default in Settings'),
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isEdit)
                  TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    child: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: Text(isEdit ? 'Save changes' : 'Add class')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
