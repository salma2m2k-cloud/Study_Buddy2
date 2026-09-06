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
    final scheme = Theme.of(context).colorScheme;

    final dayCounts = List.generate(
      7,
      (d) => state.classes
          .where((c) => c.day == d)
          .length,
    );

    final list = state.classes
        .where((c) => c.day == _selectedDay)
        .toList()
      ..sort(
        (a, b) =>
            (a.startTime ?? '')
                .compareTo(b.startTime ?? ''),
      );

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showClassForm(
          context,
          defaultDay: _selectedDay,
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ====================================================
          // WEEKLY PROGRESS
          // ====================================================
          if (state.weeklyClassCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                4,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Your week',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '${state.weeklyCompletedClassCount}/${state.weeklyClassCount}',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          minHeight: 9,
                          value:
                              state.weeklyClassProgress,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        state.weeklyRemainingClassCount == 0
                            ? '🎉 All your classes are done this week!'
                            : '${state.weeklyRemainingClassCount} class${state.weeklyRemainingClassCount == 1 ? '' : 'es'} left this week',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ====================================================
          // DAYS
          // ====================================================
          SizedBox(
            height: 74,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              itemCount: 7,
              itemBuilder: (context, i) {
                final selected =
                    _selectedDay == i;

                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedDay = i,
                  ),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.onSurface
                          : Theme.of(context).cardColor,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            Theme.of(context)
                                .dividerColor,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          kDayNamesShort[i]
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                FontWeight.w700,
                            color: selected
                                ? scheme.surface
                                    .withValues(
                                        alpha: 0.7)
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayCounts[i] > 0
                              ? '${dayCounts[i]}'
                              : '·',
                          style: TextStyle(
                            fontSize: 16,
                            color: selected
                                ? scheme.surface
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Text(
                  kDayNamesFull[_selectedDay],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // CLASSES
          // ====================================================
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    icon:
                        Icons.calendar_month_rounded,
                    title:
                        'No classes on ${kDayNamesFull[_selectedDay]}',
                    message:
                        'Add your first class for this day.',
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];

                      final completed =
                          state.isClassCompletedThisWeek(
                        c,
                      );

                      return Card(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          child: ListTile(
                            onTap: () =>
                                showClassForm(
                              context,
                              existing: c,
                            ),

                            leading: SizedBox(
                              width: 54,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  if (c.startTime != null)
                                    Text(
                                      fmtTimeStr(
                                        c.startTime!,
                                      ),
                                      style:
                                          const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                      ),
                                    ),
                                  if (c.endTime != null)
                                    Text(
                                      fmtTimeStr(
                                        c.endTime!,
                                      ),
                                      style:
                                          const TextStyle(
                                        fontSize: 10.5,
                                        color:
                                            Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                      decoration:
                                          completed
                                              ? TextDecoration
                                                  .lineThrough
                                              : null,
                                      color: completed
                                          ? scheme.onSurface
                                              .withValues(
                                                  alpha:
                                                      0.55)
                                          : null,
                                    ),
                                  ),
                                ),

                                if (completed)
                                  const Icon(
                                    Icons
                                        .check_circle_rounded,
                                    size: 20,
                                  ),
                              ],
                            ),

                            subtitle: Text(
                              [
                                c.teacher,
                                c.location,
                              ]
                                      .where(
                                        (s) =>
                                            s.isNotEmpty,
                                      )
                                      .join(' · ')
                                      .isEmpty
                                  ? 'No details added'
                                  : [
                                      c.teacher,
                                      c.location,
                                    ]
                                      .where(
                                        (s) =>
                                            s.isNotEmpty,
                                      )
                                      .join(' · '),
                            ),

                            trailing: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                if (c.reminder)
                                  const Icon(
                                    Icons
                                        .notifications_active_outlined,
                                    size: 18,
                                  ),
                                const SizedBox(height: 4),

                                TextButton(
                                  onPressed: () async {
                                    if (completed) {
                                      await state
                                          .unfinishClass(c);
                                    } else {
                                      await state
                                          .finishClass(c);
                                    }
                                  },
                                  child: Text(
                                    completed
                                        ? 'Undo'
                                        : '✓ Finished',
                                    style:
                                        const TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
