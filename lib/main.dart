import 'package/material.dart';
import 'package/provider.dart';

import 'app_state.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();

final storage = await StorageService.open();
final notifications = NotificationService();

// Notification setup should never prevent Study Buddy from opening.
try {
await notifications.init();
} catch (_) {
// The app can still work without notifications.
}

final appState = AppState(storage, notifications);

// Load saved data before showing the app.
// AppState.load() itself is designed so reminder scheduling
// cannot block the UI from appearing.
try {
await appState.load();
} catch (_) {
// If something unexpected exists in saved data, keep the app usable
// instead of leaving the user stuck on the splash screen.
}

// Permission requests should also never prevent the app from opening.
try {
await notifications.requestPermissions();
} catch (_) {
// The user can request permissions again from Settings.
}

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
