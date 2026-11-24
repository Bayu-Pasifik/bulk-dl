import 'package:material_ui/material_ui.dart';

import 'app_state.dart';

/// Gives widgets below it the shared [AppState] and rebuilds them on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (for event handlers).
  static AppState read(BuildContext context) =>
      (context.getInheritedWidgetOfExactType<AppScope>()!).notifier!;
}
