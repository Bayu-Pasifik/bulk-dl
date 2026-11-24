import 'package:bulk_dl/app_scope.dart';
import 'package:bulk_dl/app_state.dart';
import 'package:bulk_dl/l10n/app_localizations.dart';
import 'package:bulk_dl/queue.dart';
import 'package:bulk_dl/scraper.dart';
import 'package:bulk_dl/screens/queue_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

VideoItem vid(String id, String title) => VideoItem(
  id: id,
  path: '/$id',
  origin: 'https://x.test',
  title: title,
  extractor: 'generic',
);

final en = lookupAppLocalizations(const Locale('en'));

Future<AppState> pump(WidgetTester tester, List<Task> tasks) async {
  final app = AppState();
  app.queue.concurrency = 0; // never start real downloads
  app.queue.tasks.addAll(tasks);
  await tester.pumpWidget(
    AppScope(
      state: app,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const QueueScreen(),
      ),
    ),
  );
  await tester.pump();
  return app;
}

Task task(String id, String title, Status s, {String? error}) {
  final t = Task(vid(id, title));
  t.status = s;
  t.error = error;
  return t;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Foreground-service channel used by BgService.sync.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_foreground_task/methods'),
          (_) async => null,
        );
  });

  testWidgets('empty queue shows the empty state and no search field', (
    tester,
  ) async {
    await pump(tester, []);
    expect(find.text(en.queueEmpty), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('lists tasks and filters by search text', (tester) async {
    await pump(tester, [
      task('a', 'Alpha clip', Status.done),
      task('b', 'Beta clip', Status.done),
    ]);
    expect(find.text('Alpha clip'), findsOneWidget);
    expect(find.text('Beta clip'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alp');
    await tester.pump();
    expect(find.text('Alpha clip'), findsOneWidget);
    expect(find.text('Beta clip'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text(en.queueNoMatch), findsOneWidget);
  });

  testWidgets('status chips narrow the list', (tester) async {
    await pump(tester, [
      task('a', 'Finished one', Status.done),
      task('b', 'Broken one', Status.failed, error: 'boom'),
    ]);

    await tester.tap(find.text(en.filterFailed));
    await tester.pump();
    expect(find.text('Broken one'), findsOneWidget);
    expect(find.text('Finished one'), findsNothing);

    await tester.tap(find.text(en.filterDone));
    await tester.pump();
    expect(find.text('Finished one'), findsOneWidget);
    expect(find.text('Broken one'), findsNothing);

    await tester.tap(find.text(en.filterAll));
    await tester.pump();
    expect(find.text('Finished one'), findsOneWidget);
    expect(find.text('Broken one'), findsOneWidget);
  });

  testWidgets('failed task offers retry, waiting task offers cancel', (
    tester,
  ) async {
    await pump(tester, [
      task('a', 'Broken one', Status.failed, error: 'boom'),
      task('b', 'Queued one', Status.waiting),
    ]);
    expect(find.byTooltip(en.taskRetry), findsOneWidget);
    expect(find.byTooltip(en.taskCancel), findsOneWidget);
    expect(find.text(en.taskFailed('boom')), findsOneWidget);
  });

  testWidgets('clear finished removes done tasks from the list', (
    tester,
  ) async {
    final app = await pump(tester, [
      task('a', 'Finished one', Status.done),
      task('b', 'Queued one', Status.waiting),
    ]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.queueClearFinished));
    await tester.pumpAndSettle();
    expect(find.text('Finished one'), findsNothing);
    expect(find.text('Queued one'), findsOneWidget);
    expect(app.queue.tasks.length, 1);
  });

  testWidgets('add button switches to the home tab', (tester) async {
    final app = await pump(tester, []);
    app.tab.value = 1;
    await tester.tap(find.text(en.queueAdd));
    await tester.pump();
    expect(app.tab.value, 0);
  });
}
