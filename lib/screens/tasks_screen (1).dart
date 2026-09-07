import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/task_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_form_sheet.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = 'today';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();

    final today = <Task>[], upcoming = <Task>[], overdue = <Task>[], completed = <Task>[], noDate = <Task>[];
    for (final t in state.tasks) {
      if (t.done) {
        completed.add(t);
        continue;
      }
      final d = t.dueDateTime;
      if (d == null) {
        noDate.add(t);
      } else if (isSameDay(d, now)) {
        today.add(t);
      } else if (d.isBefore(now)) {
        overdue.add(t);
      } else {
        upcoming.add(t);
      }
    }
    for (final list in [today, upcoming, overdue, completed]) {
      list.sort((a, b) {
        final da = a.dueDateTime, db = b.dueDateTime;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

    List<Task> list;
    switch (_filter) {
      case 'today':
        // Tasks with no due date have nowhere else to live, so they show
        // up in "Today" too — otherwise a task created without a date
        // (the simplest possible task) never appears anywhere the user
        // is actually looking.
        list = [...today, ...noDate];
        break;
      case 'upcoming':
        list = upcoming;
        break;
      case 'overdue':
        list = overdue;
        break;
      case 'completed':
        list = completed;
        break;
      default:
        list = [...overdue, ...today, ...upcoming, ...noDate, ...completed];
    }

    final tabs = [
      ('today', 'Today', today.length + noDate.length),
      ('upcoming', 'Upcoming', upcoming.length),
      ('overdue', 'Overdue', overdue.length),
      ('completed', 'Completed', completed.length),
      ('all', 'All', state.tasks.length),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTaskForm(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: tabs.map((tab) {
                final selected = _filter == tab.$1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${tab.$2}${tab.$3 > 0 ? ' · ${tab.$3}' : ''}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = tab.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: _filter == 'completed'
                        ? 'Nothing completed yet'
                        : _filter == 'overdue'
                            ? 'Nothing overdue — nice'
                            : 'All clear here',
                    message: _filter == 'completed' ? 'Finish a task and it will show up here.' : 'Add a task to get started.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final t = list[i];
                      return TaskTile(
                        task: t,
                        onToggle: () => state.toggleTask(t.id),
                        onTap: () => showTaskForm(context, existing: t),
                        onDelete: () => state.deleteTask(t.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
