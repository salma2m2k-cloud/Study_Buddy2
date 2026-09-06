import 'package:flutter/material.dart';

/// Study Buddy's palette: warm paper background, deep ink text, honey
/// accent, sage for success/done states, coral for overdue/destructive.
class StudyColors {
  static const honey = Color(0xFFDB9A3C);
  static const honeyDark = Color(0xFFE4AE5E);
  static const sage = Color(0xFF5F8768);
  static const sageDark = Color(0xFF7FAE87);
  static const coral = Color(0xFFD2604A);
  static const coralDark = Color(0xFFE17E68);
  static const sky = Color(0xFF4C7A96);
}

ThemeData buildLightTheme() {
  const paper = Color(0xFFF4F5EF);
  const ink = Color(0xFF20262E);
  final scheme = ColorScheme.light(
    primary: StudyColors.honey,
    onPrimary: const Color(0xFF241A05),
    secondary: StudyColors.sage,
    onSecondary: Colors.white,
    error: StudyColors.coral,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9EBE2)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ink,
      foregroundColor: paper,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFECEEE4),
      indicatorColor: StudyColors.honey.withValues(alpha: 0.25),
    ),
  );
}

ThemeData buildDarkTheme() {
  const bg = Color(0xFF171A1F);
  const surface = Color(0xFF1F242B);
  const ink = Color(0xFFEAEBE6);
  final scheme = ColorScheme.dark(
    primary: StudyColors.honeyDark,
    onPrimary: const Color(0xFF1B1608),
    secondary: StudyColors.sageDark,
    onSecondary: const Color(0xFF0E1A11),
    error: StudyColors.coralDark,
    onError: Colors.black,
    surface: surface,
    onSurface: ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2C313A)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: StudyColors.honeyDark,
      foregroundColor: const Color(0xFF1B1608),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1D2127),
      indicatorColor: StudyColors.honeyDark.withValues(alpha: 0.25),
    ),
  );
}
