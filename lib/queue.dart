import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'scraper.dart';

enum Status { waiting, resolving, downloading, done, failed, canceled }

class _Canceled implements Exception {}

class Task extends ChangeNotifier {
  Task(this.video);
  final VideoItem video;
  Status status = Status.waiting;
  double progress = 0;
  String? error;
  String? file;
  int? quality;
  CancelToken? token;

  /// True while a `_run` is in flight (guards against double runs).
  bool busy = false;

  void update({Status? s, double? p, String? e}) {
    if (s != null) status = s;
    if (p != null) progress = p;
    if (e != null) error = e;
    notifyListeners();
  }
}

class DownloadQueue extends ChangeNotifier {
  DownloadQueue(this.scraper);
  final Scraper scraper;
  final List<Task> tasks = [];
  int maxQuality = 720; // 1080p+ needs a login on the site
  int concurrency = 2;
  int _active = 0;

  Future<Directory> outDir() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/BulkDL');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Removes `.part` files left by a killed app. Call once at startup.
  Future<void> cleanupPartials() async {
    final d = await outDir();
    await for (final f in d.list()) {
      if (f is File && f.path.endsWith('.part')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  void add(Iterable<VideoItem> items) {
    for (final v in items) {
      if (tasks.any((t) => t.video.id == v.id)) continue;
      tasks.add(Task(v));
    }
    notifyListeners();
    _pump();
  }

  void cancel(Task t) {
    t.token?.cancel('canceled');
    if (t.status == Status.waiting) t.update(s: Status.canceled);
  }

  void retry(Task t) {
    // Old run still unwinding: ignore; it ends in a retryable state soon.
    if (t.busy) return;
    if (t.status != Status.failed && t.status != Status.canceled) return;
    t.update(s: Status.waiting, p: 0);
    _pump();
  }

  void clearFinished() {
    tasks.removeWhere(
      (t) =>
          !t.busy &&
          (t.status == Status.done ||
              t.status == Status.canceled ||
              t.status == Status.failed),
    );
    notifyListeners();
  }

  void _pump() {
    while (_active < concurrency) {
      final next = tasks.where((t) => t.status == Status.waiting).firstOrNull;
      if (next == null) return;
      _active++;
      next.busy = true;
      next.status = Status.resolving;
      _run(next).whenComplete(() {
        _active--;
        _pump();
      });
    }
  }

  Future<void> _run(Task t) async {
    final token = t.token = CancelToken();
    t.update(s: Status.resolving);
    var end = Status.failed;
    String? err;
    String? part;
    try {
      final links = await scraper.links(t.video);
      if (token.isCancelled) throw _Canceled();
      final cands = Scraper.candidates(links, maxQuality);
      if (cands.isEmpty) throw 'No download link';
      final dir = await outDir();

      // Already downloaded at one of the wanted qualities: skip.
      for (final c in cands) {
        final f = File('${dir.path}/${_name(t.video, c.quality)}');
        if (await f.exists() && await f.length() > 0) {
          t.quality = c.quality;
          t.file = f.path;
          t.progress = 1;
          end = Status.done;
          return;
        }
      }

      // High qualities may redirect to a login page: skip to the next one.
      ResponseBody? body;
      DownloadLink? link;
      for (final c in cands) {
        final r = await scraper.dio.get<ResponseBody>(
          c.url,
          cancelToken: token,
          options: Options(responseType: ResponseType.stream),
        );
        final type = r.headers.value('content-type') ?? '';
        if (type.contains('text/html')) {
          await r.data!.stream.listen((_) {}).cancel();
          continue;
        }
        body = r.data;
        link = c;
        break;
      }
      if (body == null || link == null) {
        throw 'Login required (no free quality available)';
      }

      t.quality = link.quality;
      final path = '${dir.path}/${_name(t.video, link.quality)}';
      part = '$path.part';
      final total = body.contentLength;
      var received = 0;
      t.update(s: Status.downloading, p: 0);
      final sink = File(part).openWrite();
      try {
        await for (final chunk in body.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) t.update(p: received / total);
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && received != total) {
        throw 'Incomplete download ($received/$total bytes)';
      }
      await File(part).rename(path);
      part = null;
      t.file = path;
      t.progress = 1;
      end = Status.done;
    } on _Canceled {
      end = Status.canceled;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        end = Status.canceled;
      } else {
        err = _dioMessage(e);
      }
    } catch (e) {
      err = '$e';
    } finally {
      if (part != null) {
        try {
          final f = File(part);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      t.busy = false;
      t.update(s: end, e: err);
    }
  }

  String _dioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out';
      case DioExceptionType.connectionError:
        return 'No connection';
      case DioExceptionType.badResponse:
        return 'Server error ${e.response?.statusCode ?? ''}'.trim();
      default:
        return e.message ?? e.type.name;
    }
  }

  /// Unicode-safe, length-capped file name; id keeps it unique.
  String _name(VideoItem v, int quality) {
    var title = v.title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .trim();
    final runes = title.runes.toList();
    if (runes.length > 80) title = String.fromCharCodes(runes.take(80));
    return '${title}_${quality}p_${v.id}.mp4';
  }
}
