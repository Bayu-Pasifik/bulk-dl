import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

import 'app_scope.dart';
import 'app_state.dart';
import 'bg.dart';
import 'queue.dart';
import 'screens/home_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BgService.init();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    state.init();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => DynamicColorBuilder(
          builder: (lightDyn, darkDyn) {
            ColorScheme pick(Brightness b, ColorScheme? dyn) =>
                state.dynamicColor && dyn != null
                ? dyn.harmonized()
                : greenScheme(b);
            return MaterialApp(
              title: 'Bulk DL',
              debugShowCheckedModeBanner: false,
              navigatorKey: state.navKey,
              scaffoldMessengerKey: state.messengerKey,
              themeMode: state.themeMode,
              theme: buildTheme(pick(Brightness.light, lightDyn)),
              darkTheme: buildTheme(pick(Brightness.dark, darkDyn)),
              home: const Shell(),
            );
          },
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  bool _asked = false;

  Future<void> _maybeDisclaimer(AppState app) async {
    if (_asked || app.disclaimerSeen) return;
    _asked = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.gavel_outlined),
        title: const Text('Sebelum mulai'),
        content: const Text(
          'Bulk DL hanya alat pengunduh. Unduh hanya konten yang kamu berhak simpan, dan patuhi hukum serta ketentuan situs. Kamu bertanggung jawab atas penggunaan dan hak cipta. Konten berDRM tidak didukung.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              app.acceptDisclaimer();
              Navigator.pop(ctx);
            },
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeDisclaimer(app);
    });
    return ValueListenableBuilder<int>(
      valueListenable: app.tab,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(
          index: i,
          children: const [HomeScreen(), QueueScreen(), SettingsScreen()],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: app.queue,
          builder: (context, _) {
            final active = app.queue.tasks
                .where(
                  (t) =>
                      t.status == Status.downloading ||
                      t.status == Status.resolving ||
                      t.status == Status.waiting,
                )
                .length;
            return NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => app.tab.value = v,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Beranda',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: active > 0,
                    label: Text('$active'),
                    child: const Icon(Icons.download_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: active > 0,
                    label: Text('$active'),
                    child: const Icon(Icons.download),
                  ),
                  label: 'Antrean',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Pengaturan',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
