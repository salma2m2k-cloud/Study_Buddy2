import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../screens/home_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/classes_screen.dart';
import '../screens/study_screen.dart';
import '../screens/ai_list_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = [
    'Home',
    'Tasks',
    'Class Planner',
    'Study Sessions',
    'AI Buddy',
    'Notes',
    'Settings',
  ];

  static const _icons = [
    Icons.home_rounded,
    Icons.check_circle_outline_rounded,
    Icons.calendar_month_rounded,
    Icons.timer_outlined,
    Icons.auto_awesome_rounded,
    Icons.description_outlined,
    Icons.settings_outlined,
  ];

  static final _screens = [
    const HomeScreen(),
    const TasksScreen(),
    const ClassesScreen(),
    const StudyScreen(),
    const AiListScreen(),
    const NotesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [Theme.of(context).colorScheme.primary, Colors.deepOrange.shade300],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    const Text('Study Buddy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _titles.length,
                  itemBuilder: (context, i) {
                    final selected = i == _index;
                    return ListTile(
                      leading: Icon(_icons[i]),
                      title: Text(_titles[i], style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      selected: selected,
                      selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
    );
  }
}
