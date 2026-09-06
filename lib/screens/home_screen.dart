import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/task_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  ClassOccurrence? _nextClass(List<ClassItem> classes) {
    ClassOccurrence? best;
    final now = DateTime.now();
    for (final c in classes) {
      if (c.startTime == null || c.startTime!.isEmpty) continue;
      final parts = c.startTime!.split(':').map(int.parse).toList();
      final targetWeekday = c.day == 0 ? 7 : c.day;
      var candidate = DateTime(now.year, now.month, now.day, parts[0], parts[1]);
      while (candidate.weekday != targetWeekday || candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (best == null || candidate.isBefore(best.dateTime)) {
        best = ClassOccurrence(c, candidate);
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();

    final todays = state.tasks.where((t) {
      if (t.done) return false;
      final d = t.dueDateTime;
      return d != null && isSameDay(d, now);
    }).toList()
      ..sort((a, b) => a.dueDateTime!.compareTo(b.dueDateTime!));

    final overdue = state.tasks.where((t) {
      if (t.done) return false;
      final d = t.dueDateTime;
      return d != null && d.isBefore(now) && !isSameDay(d, now);
    }).toList();

    final nextClass = _nextClass(state.classes);

    final weekMs = state.sessions
        .where((s) => now.difference(DateTime.parse(s.endedAt)).inDays < 7)
        .fold<int>(0, (a, s) => a + s.durationMs);
    final recentSessions = [...state.sessions]
      ..sort((a, b) => DateTime.parse(b.endedAt).compareTo(DateTime.parse(a.endedAt)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHero(context, state, overdue, nextClass),
        const SizedBox(height: 16),
        Row(
          children: [
            _statBox(context, '${todays.length}', 'Due today'),
            _statBox(context, durationHuman(weekMs), 'Studied this week'),
            _statBox(context, '${state.sessions.length}', 'Sessions logged'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's tasks", style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (todays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nothing due today. Enjoy the breathing room.'),
                  )
                else
                  ...todays.take(5).map((t) => TaskTile(
                        task: t,
                        onToggle: () => state.toggleTask(t.id),
                        onTap: () {},
                        onDelete: () => state.deleteTask(t.id),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent study sessions', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (recentSessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No sessions yet — your history will show up here.'),
                  )
                else
                  ...recentSessions.take(3).map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(s.subject.isEmpty ? 'Focus session' : s.subject),
                            Text(durationHuman(s.durationMs), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBox(BuildContext context, String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, AppState state, List<Task> overdue, ClassOccurrence? nextClass) {
    final scheme = Theme.of(context).colorScheme;
    String eyebrow;
    String title;
    String subtitle;

    if (state.activeSession != null) {
      final s = state.activeSession!;
      eyebrow = 'Currently studying';
      title = '${s.subject.isEmpty ? 'Focus session' : s.subject} in progress';
      subtitle = 'Started at ${fmtTime(DateTime.parse(s.startedAt))}';
    } else if (overdue.isNotEmpty) {
      eyebrow = 'Needs attention';
      title = '${overdue.length} task${overdue.length > 1 ? 's' : ''} slipped past due';
      subtitle = overdue.first.title;
    } else if (nextClass != null) {
      eyebrow = 'Next class';
      title = nextClass.classItem.name;
      subtitle = '${fmtTime(nextClass.dateTime)}'
          '${nextClass.classItem.location.isNotEmpty ? ' · ${nextClass.classItem.location}' : ''}';
    } else {
      eyebrow = kDayNamesFull[DateTime.now().weekday % 7];
      title = 'Nothing urgent — good time for a focus session';
      subtitle = 'Clear schedule ahead. Make it count.';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.onSurface, scheme.onSurface.withValues(alpha: 0.85)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: TextStyle(color: scheme.surface.withValues(alpha: 0.7), fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(color: scheme.surface, fontSize: 21, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: scheme.surface.withValues(alpha: 0.75), fontSize: 13)),
        ],
      ),
    );
  }
}

class ClassOccurrence {
  final ClassItem classItem;
  final DateTime dateTime;
  ClassOccurrence(this.classItem, this.dateTime);
}
