import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';

Future<void> showClassForm(
  BuildContext context, {
  ClassItem? existing,
  int? defaultDay,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _ClassFormSheet(
      existing: existing,
      defaultDay: defaultDay,
    ),
  );
}

class _ClassFormSheet extends StatefulWidget {
  const _ClassFormSheet({
    this.existing,
    this.defaultDay,
  });

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
  bool _saving = false;
  bool _deleting = false;

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

    _reminder = c?.reminder ?? true;

    if (c?.startTime != null && c!.startTime!.isNotEmpty) {
      final parts = c.startTime!.split(':').map(int.parse).toList();
      _start = TimeOfDay(
        hour: parts[0],
        minute: parts[1],
      );
    }

    if (c?.endTime != null && c!.endTime!.isNotEmpty) {
      final parts = c.endTime!.split(':').map(int.parse).toList();
      _end = TimeOfDay(
        hour: parts[0],
        minute: parts[1],
      );
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

  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;

    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null && mounted) {
      setState(() {
        _start = picked;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _end ?? const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null && mounted) {
      setState(() {
        _end = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _deleting) return;

    final name = _name.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give the class a name first'),
        ),
      );
      return;
    }

    if (_reminder && _start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set a start time so the reminder knows when to fire',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final state = context.read<AppState>();

    try {
      if (widget.existing != null) {
        final c = widget.existing!;

        c.name = name;
        c.subject = _subject.text.trim();
        c.teacher = _teacher.text.trim();
        c.day = _day;
        c.startTime = _formatTime(_start);
        c.endTime = _formatTime(_end);
        c.location = _location.text.trim();
        c.notes = _notes.text.trim();
        c.reminder = _reminder;
        c.reminderLead = state.settings.reminderLead;

        debugPrint(
          '📝 Study Buddy: SAVING (update) class id=${c.id} '
          'name="${c.name}" day=${c.day} startTime=${c.startTime} '
          'reminder=$_reminder reminderLead=${c.reminderLead}',
        );

        await state.updateClass(c);
      } else {
        final newClass = ClassItem(
          id: newId(),
          name: name,
          subject: _subject.text.trim(),
          teacher: _teacher.text.trim(),
          day: _day,
          startTime: _formatTime(_start),
          endTime: _formatTime(_end),
          location: _location.text.trim(),
          notes: _notes.text.trim(),
          reminder: _reminder,
          reminderLead: state.settings.reminderLead,
        );

        debugPrint(
          '📝 Study Buddy: SAVING (new) class id=${newClass.id} '
          'name="${newClass.name}" day=${newClass.day} '
          'startTime=${newClass.startTime} reminder=$_reminder '
          'reminderLead=${newClass.reminderLead}',
        );

        await state.addClass(newClass);
      }

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The class could not be saved. Please try again.'),
        ),
      );
    }
  }

  Future<void> _delete() async {
    if (_saving || _deleting || widget.existing == null) return;

    setState(() {
      _deleting = true;
    });

    try {
      await context.read<AppState>().deleteClass(
        widget.existing!.id,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The class could not be deleted. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final leadMin = context.watch<AppState>().settings.reminderLead;

    final busy = _saving || _deleting;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  isEdit ? 'Edit class' : 'New class',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _name,
              autofocus: !isEdit,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Class name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subject,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _teacher,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Teacher',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(
                labelText: 'Day',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                7,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(kDayNamesFull[i]),
                ),
              ),
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _day = value;
                        });
                      }
                    },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickStart,
                    icon: const Icon(
                      Icons.access_time,
                      size: 16,
                    ),
                    label: Text(
                      _start == null
                          ? 'Start time'
                          : _start!.format(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickEnd,
                    icon: const Icon(
                      Icons.access_time,
                      size: 16,
                    ),
                    label: Text(
                      _end == null
                          ? 'End time'
                          : _end!.format(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _location,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Location / link',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _notes,
              enabled: !busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 4),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Remind me before it starts',
              ),
              subtitle: Text(
                '$leadMin min before, every week — '
                'change the default in Settings',
              ),
              value: _reminder,
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() {
                        _reminder = value;
                      });
                    },
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                if (isEdit)
                  TextButton(
                    onPressed: busy ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Delete'),
                  ),

                const Spacer(),

                FilledButton(
                  onPressed: busy ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit
                              ? 'Save changes'
                              : 'Add class',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
