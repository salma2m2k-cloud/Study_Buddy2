import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/class_form_sheet.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late int _selectedDay = DateTime.now().weekday % 7;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayCounts = List.generate(7, (d) => state.classes.where((c) => c.day == d).length);
    final list = state.classes.where((c) => c.day == _selectedDay).toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showClassForm(context, defaultDay: _selectedDay),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 74,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: 7,
              itemBuilder: (context, i) {
                final selected = _selectedDay == i;
                final scheme = Theme.of(context).colorScheme;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected ? scheme.onSurface : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(kDayNamesShort[i].toUpperCase(),
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: selected ? scheme.surface.withValues(alpha: 0.7) : Colors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          dayCounts[i] > 0 ? '${dayCounts[i]}' : '·',
                          style: TextStyle(fontSize: 16, color: selected ? scheme.surface : null),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(kDayNamesFull[_selectedDay], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.calendar_month_rounded,
                    title: 'No classes on ${kDayNamesFull[_selectedDay]}',
                    message: 'Add your first class for this day.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return Card(
                        child: ListTile(
                          onTap: () => showClassForm(context, existing: c),
                          leading: SizedBox(
                            width: 54,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (c.startTime != null) Text(fmtTimeStr(c.startTime!), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                if (c.endTime != null) Text(fmtTimeStr(c.endTime!), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            [c.teacher, c.location].where((s) => s.isNotEmpty).join(' · ').isEmpty
                                ? 'No details added'
                                : [c.teacher, c.location].where((s) => s.isNotEmpty).join(' · '),
                          ),
                          trailing: c.reminder ? const Icon(Icons.notifications_active_outlined, size: 18) : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
