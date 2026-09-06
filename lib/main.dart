import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await StorageService.open();
  final notifications = NotificationService();
  await notifications.init();

  final appState = AppState(storage, notifications);
  await appState.load();

  // Ask once at startup. If the student says no, the Settings page still
  // offers a button to ask again later.
  await notifications.requestPermissions();

  runApp(StudyBuddyApp(appState: appState));
}

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          ThemeMode mode;
          switch (state.settings.theme) {
            case 'dark':
              mode = ThemeMode.dark;
              break;
            case 'light':
              mode = ThemeMode.light;
              break;
            default:
              mode = ThemeMode.system;
          }
          return MaterialApp(
            title: 'Study Buddy',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
