import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';

Future<void> showTaskForm(
  BuildContext context, {
  Task? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _TaskFormSheet(
      existing: existing,
    ),
  );
}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({
    this.existing,
  });

  final Task? existing;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _desc;

  DateTime? _date;
  TimeOfDay? _time;

  bool _reminder = false;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();

    final t = widget.existing;

    _title = TextEditingController(
      text: t?.title ?? '',
    );

    _desc = TextEditingController(
      text: t?.description ?? '',
    );

    _reminder = t?.reminder ?? false;

    if (t?.date != null && t!.date!.isNotEmpty) {
      final parts = t.date!.split('-').map(int.parse).toList();

      _date = DateTime(
        parts[0],
        parts[1],
        parts[2],
      );
    }

    if (t?.time != null && t!.time!.isNotEmpty) {
      final parts = t.time!.split(':').map(int.parse).toList();

      _time = TimeOfDay(
        hour: parts[0],
        minute: parts[1],
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(
        const Duration(days: 365),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 365 * 3),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _time = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _deleting) return;

    final title = _title.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give the task a title first'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final state = context.read<AppState>();

    final dateStr = _date == null
        ? null
        : DateFormat('yyyy-MM-dd').format(_date!);

    final timeStr = _time == null
        ? null
        : '${_time!.hour.toString().padLeft(2, '0')}:'
            '${_time!.minute.toString().padLeft(2, '0')}';

    try {
      if (widget.existing != null) {
        final task = widget.existing!;

        task.title = title;
        task.description = _desc.text.trim();
        task.date = dateStr;
        task.time = timeStr;
        task.reminder = _reminder;
        task.reminderLead = state.settings.reminderLead;

        debugPrint(
          '📝 Study Buddy: SAVING (update) task id=${task.id} '
          'title="${task.title}" date=$dateStr time=$timeStr '
          'reminder=$_reminder reminderLead=${task.reminderLead}',
        );

        await state.updateTask(task);
      } else {
        final task = Task(
          id: newId(),
          title: title,
          description: _desc.text.trim(),
          date: dateStr,
          time: timeStr,
          reminder: _reminder,
          reminderLead: state.settings.reminderLead,
          createdAt: DateTime.now().toIso8601String(),
        );

        debugPrint(
          '📝 Study Buddy: SAVING (new) task id=${task.id} '
          'title="${task.title}" date=$dateStr time=$timeStr '
          'reminder=$_reminder reminderLead=${task.reminderLead}',
        );

        await state.addTask(task);
      }

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The task could not be saved. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _delete() async {
    if (_saving || _deleting || widget.existing == null) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      await context.read<AppState>().deleteTask(
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
          content: Text(
            'The task could not be deleted. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
                  isEdit ? 'Edit task' : 'New task',
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
              controller: _title,
              autofocus: !isEdit,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickDate,
                    icon: const Icon(
                      Icons.calendar_today,
                      size: 16,
                    ),
                    label: Text(
                      _date == null
                          ? 'Date'
                          : DateFormat.yMMMd().format(_date!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickTime,
                    icon: const Icon(
                      Icons.access_time,
                      size: 16,
                    ),
                    label: Text(
                      _time == null
                          ? 'Time'
                          : _time!.format(context),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _desc,
              enabled: !busy,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 4),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set a reminder'),
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
                              : 'Add task',
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
