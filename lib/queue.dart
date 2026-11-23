import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library.dart';
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
  final Library lib = Library();
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

  bool _stale(File f) =>
      DateTime.now().difference(f.lastModifiedSync()).inDays >= 7;

  /// Removes `.part` files older than 7 days (fresh ones are resumable).
  Future<void> cleanupPartials() async {
    final d = await outDir();
    await for (final f in d.list()) {
      if (f is File && f.path.endsWith('.part') && _stale(f)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  static const _qKey = 'queue_v1';

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _qKey,
        jsonEncode([
          for (final t in tasks)
            {
              'id': t.video.id,
              'path': t.video.path,
              'title': t.video.title,
              'thumb': t.video.thumb,
              'status': t.status.name,
              'quality': t.quality,
              'file': t.file,
            },
        ]),
      );
    } catch (_) {}
  }

  /// Reloads the queue from the last session. Unfinished tasks come back
  /// as canceled so the user can resume them (partial files are kept).
  Future<void> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_qKey);
      if (raw == null) return;
      for (final m in jsonDecode(raw) as List) {
        final v = VideoItem(
          id: m['id'],
          path: m['path'],
          title: m['title'],
          thumb: m['thumb'],
        );
        if (tasks.any((t) => t.video.id == v.id)) continue;
        final t = Task(v)..quality = m['quality'];
        if (m['status'] == 'done' && m['file'] != null) {
          if (!await lib.exists(m['file'])) continue;
          t.file = m['file'];
          t.status = Status.done;
          t.progress = 1;
        } else {
          t.status = Status.canceled;
        }
        tasks.add(t);
      }
      notifyListeners();
    } catch (_) {}
  }

  void add(Iterable<VideoItem> items) {
    for (final v in items) {
      if (tasks.any((t) => t.video.id == v.id)) continue;
      tasks.add(Task(v));
    }
    notifyListeners();
    _persist();
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
    _persist();
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
    try {
      final links = await scraper.links(t.video);
      if (token.isCancelled) throw _Canceled();
      final cands = Scraper.candidates(links, maxQuality);
      if (cands.isEmpty) throw 'No download link';
      final dir = await outDir();

      // Already in the public library: skip.
      final known = await lib.find(t.video.id);
      if (known != null) {
        t.quality = known.quality;
        t.file = known.uri;
        t.progress = 1;
        end = Status.done;
        return;
      }

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
      // A leftover .part file is resumed with an HTTP Range request.
      ResponseBody? body;
      DownloadLink? link;
      var offset = 0;
      for (final c in cands) {
        final pf = File('${dir.path}/${_name(t.video, c.quality)}.part');
        var have = await pf.exists() ? await pf.length() : 0;
        Response<ResponseBody> r;
        while (true) {
          r = await scraper.dio.get<ResponseBody>(
            c.url,
            cancelToken: token,
            options: Options(
              responseType: ResponseType.stream,
              headers: have > 0 ? {'Range': 'bytes=$have-'} : null,
              validateStatus: (s) => s != null && (s < 300 || s == 416),
            ),
          );
          if (r.statusCode == 416) {
            // Stale/oversized partial: start over.
            await pf.delete();
            have = 0;
            continue;
          }
          break;
        }
        final type = r.headers.value('content-type') ?? '';
        if (type.contains('text/html')) {
          await r.data!.stream.listen((_) {}).cancel();
          continue;
        }
        body = r.data;
        link = c;
        offset = r.statusCode == 206 ? have : 0; // 200 = server ignored Range
        break;
      }
      if (body == null || link == null) {
        throw 'Login required (no free quality available)';
      }

      t.quality = link.quality;
      final path = '${dir.path}/${_name(t.video, link.quality)}';
      final part = '$path.part';
      final len = body.contentLength;
      final total = len > 0 ? len + offset : 0;
      var received = offset;
      t.update(s: Status.downloading, p: total > 0 ? received / total : 0);
      final sink = File(part)
          .openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
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
      t.file = path;
      // Move to public Movies/BulkDL so it shows in the gallery.
      final uri = await lib.export(path, _name(t.video, link.quality));
      if (uri != null) {
        await File(path).delete();
        await lib.add(t.video.id, uri, link.quality);
        t.file = uri;
      }
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
      t.busy = false;
      t.update(s: end, e: err);
      _persist();
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
