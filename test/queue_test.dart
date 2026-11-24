import 'dart:io';

import 'package:bulk_dl/net/multi.dart';
import 'package:bulk_dl/queue.dart';
import 'package:bulk_dl/scraper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

VideoItem vid(String id, {String extractor = 'generic', String title = 'T'}) =>
    VideoItem(
      id: id,
      path: '/$id',
      origin: 'https://x.test',
      title: title,
      extractor: extractor,
    );

/// Queue that never starts a download: concurrency 0 keeps tasks `waiting`.
DownloadQueue newQueue() {
  final q = DownloadQueue(Scraper());
  q.concurrency = 0;
  return q;
}

/// Lets the fire-and-forget `_persist` finish.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final existing = <String>{};
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    existing.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('bulk_dl/files'), (
          call,
        ) async {
          if (call.method == 'exists') {
            return existing.contains(call.arguments['uri']);
          }
          return null;
        });
  });

  group('formatting', () {
    test('formatSpeed', () => expect(formatSpeed(1048576 * 2.5), '2.5 MB/s'));
    test('formatEta', () {
      expect(formatEta(59), '00:59');
      expect(formatEta(61), '01:01');
      expect(formatEta(3661), '1:01:01');
    });
  });

  group('Task', () {
    test('update sets fields and notifies', () {
      final t = Task(vid('a'));
      var n = 0;
      t.addListener(() => n++);
      t.update(s: Status.failed, p: 0.5, e: 'boom');
      expect(t.status, Status.failed);
      expect(t.progress, 0.5);
      expect(t.error, 'boom');
      expect(n, 1);
    });

    test('meter: no speed before 1 s, then positive', () async {
      final t = Task(vid('a'))..startMeter(100, 1000);
      expect(t.received, 100);
      expect(t.total, 1000);
      t.sample(200);
      expect(t.received, 200);
      expect(t.speed, 0);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      t.sample(1200);
      expect(t.speed, greaterThan(0));
    });
  });

  group('queue state', () {
    test('add dedupes by id and notifies', () {
      final q = newQueue();
      var n = 0;
      q.addListener(() => n++);
      q.add([vid('a'), vid('b'), vid('a')]);
      q.add([vid('b')]);
      expect(q.tasks.map((t) => t.video.id), ['a', 'b']);
      expect(n, greaterThan(0));
      expect(q.tasks.every((t) => t.status == Status.waiting), true);
    });

    test('cancel flips a waiting task to canceled', () {
      final q = newQueue()..add([vid('a')]);
      q.cancel(q.tasks.first);
      expect(q.tasks.first.status, Status.canceled);
    });

    test('retry resets failed/canceled, ignores others and busy', () {
      final q = newQueue()..add([vid('a'), vid('b'), vid('c')]);
      final a = q.tasks[0]..attempts = 2;
      a.update(s: Status.failed);
      q.retry(a);
      expect(a.status, Status.waiting);
      expect(a.attempts, 0);
      expect(a.progress, 0);

      final b = q.tasks[1]..update(s: Status.done);
      q.retry(b);
      expect(b.status, Status.done);

      final c = q.tasks[2]
        ..update(s: Status.failed)
        ..busy = true;
      q.retry(c);
      expect(c.status, Status.failed);
    });

    test('clearFinished keeps waiting and busy tasks', () {
      final q = newQueue()
        ..add([vid('w'), vid('d'), vid('f'), vid('c'), vid('r')]);
      q.tasks[1].update(s: Status.done);
      q.tasks[2].update(s: Status.failed);
      q.tasks[3].update(s: Status.canceled);
      q.tasks[4]
        ..update(s: Status.failed)
        ..busy = true;
      q.clearFinished();
      expect(q.tasks.map((t) => t.video.id), ['w', 'r']);
    });

    test('connections is clamped to 1..kMaxConnections', () {
      final q = newQueue();
      q.connections = 100000;
      expect(q.connections, kMaxConnections);
      q.connections = 0;
      expect(q.connections, 1);
    });
  });

  group('stats', () {
    test('counts active/waiting, aggregates speed and eta', () {
      final q = newQueue()..add([vid('a'), vid('b'), vid('c')]);
      q.tasks[0]
        ..busy = true
        ..status = Status.downloading
        ..startMeter(500, 1000)
        ..speed = 100;
      final s = q.stats();
      expect(s.active, 1);
      expect(s.waiting, 2);
      expect(s.speed, 100);
      expect(s.fraction, closeTo(0.5, 1e-9));
      expect(s.eta, 5);
    });

    test('idle queue has no eta and zero fraction', () {
      final s = newQueue().stats();
      expect(s.active, 0);
      expect(s.eta, null);
      expect(s.fraction, 0);
    });
  });

  group('persist/restore', () {
    test('unfinished -> canceled; done kept only if file exists', () async {
      final q1 = newQueue()..add([vid('a'), vid('b'), vid('c')]);
      q1.tasks[1]
        ..file = 'content://ok'
        ..quality = 720
        ..update(s: Status.done, p: 1);
      q1.tasks[2]
        ..file = 'content://gone'
        ..update(s: Status.done, p: 1);
      q1.add([vid('z')]); // persists the current states
      await settle();

      existing.add('content://ok');
      final q2 = newQueue();
      await q2.restore();
      final byId = {for (final t in q2.tasks) t.video.id: t};
      expect(byId['a']!.status, Status.canceled);
      expect(byId['z']!.status, Status.canceled);
      expect(byId['b']!.status, Status.done);
      expect(byId['b']!.file, 'content://ok');
      expect(byId['b']!.quality, 720);
      expect(byId.containsKey('c'), false);
    });

    test('restore twice does not duplicate', () async {
      newQueue().add([vid('a')]);
      await settle();
      final q2 = newQueue();
      await q2.restore();
      await q2.restore();
      expect(q2.tasks.length, 1);
    });
  });

  group('isTransient', () {
    final q = newQueue();
    DioException de(DioExceptionType t, [int? code]) {
      final ro = RequestOptions(path: '/');
      return DioException(
        requestOptions: ro,
        type: t,
        response: code == null
            ? null
            : Response(requestOptions: ro, statusCode: code),
      );
    }

    test('network errors retry', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(q.isTransient(de(t)), true, reason: '$t');
      }
    });

    test('5xx and 429 retry, other statuses do not', () {
      expect(q.isTransient(de(DioExceptionType.badResponse, 503)), true);
      expect(q.isTransient(de(DioExceptionType.badResponse, 429)), true);
      expect(q.isTransient(de(DioExceptionType.badResponse, 404)), false);
      expect(q.isTransient(de(DioExceptionType.badResponse, 403)), false);
      expect(q.isTransient(de(DioExceptionType.cancel)), false);
    });
  });

  group('targetName', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('bulkdl_q'));
    tearDown(() => dir.deleteSync(recursive: true));
    final q = newQueue();

    test('eporner uses fixed name with quality and id', () async {
      final n = await q.targetName(
        dir,
        vid('abc', extractor: 'eporner', title: 'My Vid'),
        DownloadLink(720, 'u', false),
      );
      expect(n, 'My Vid_720p_abc.mp4');
    });

    test('others: title.ext, numbered when taken, reuse .part', () async {
      final v = vid('a', title: 'Clip');
      final l = DownloadLink(0, 'u', false);
      expect(await q.targetName(dir, v, l), 'Clip.mp4');
      File('${dir.path}/Clip.mp4').writeAsStringSync('x');
      expect(await q.targetName(dir, v, l), 'Clip (1).mp4');
      File('${dir.path}/Clip (1).mp4.part').writeAsStringSync('x');
      expect(await q.targetName(dir, v, l), 'Clip (1).mp4');
    });

    test('server file name wins over title', () async {
      final n = await q.targetName(
        dir,
        vid('a', title: 'Ignored'),
        DownloadLink(0, 'u', false, null, false, 'mp4', 'real.mkv'),
      );
      expect(n, 'real.mkv');
    });
  });
}
