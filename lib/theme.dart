import 'package:material_ui/material_ui.dart';

/// Brand seed: Material green. Every colour in the UI comes from the
/// resulting [ColorScheme] (or the dynamic one on Android 12+ when enabled).
const seedGreen = Color(0xFF2E7D32);

ColorScheme greenScheme(Brightness b) => ColorScheme.fromSeed(
  seedColor: seedGreen,
  brightness: b,
  dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
);

ThemeData buildTheme(ColorScheme s) => ThemeData(
  useMaterial3: true,
  colorScheme: s,
  scaffoldBackgroundColor: s.surface,
  visualDensity: VisualDensity.standard,
  appBarTheme: AppBarTheme(
    backgroundColor: s.surface,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    margin: EdgeInsets.zero,
    color: s.surfaceContainerHigh,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: s.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    linearMinHeight: 6,
    borderRadius: BorderRadius.all(Radius.circular(3)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: s.surfaceContainer,
    indicatorColor: s.secondaryContainer,
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
);
