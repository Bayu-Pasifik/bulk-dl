import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
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

  int attempts = 0; // auto-retries used
  bool transient = false; // last failure worth retrying
  bool pausedByNet = false; // paused because Wi-Fi-only is on

  int received = 0;
  int total = 0;
  double speed = 0; // bytes/s, smoothed
  DateTime _t = DateTime.now();
  int _b = 0;

  void startMeter(int rec, int tot) {
    received = rec;
    total = tot;
    speed = 0;
    _t = DateTime.now();
    _b = rec;
  }

  void sample(int rec) {
    received = rec;
    final now = DateTime.now();
    final dt = now.difference(_t).inMilliseconds;
    if (dt < 1000) return;
    final inst = (rec - _b) * 1000 / dt;
    speed = speed == 0 ? inst : speed * 0.6 + inst * 0.4;
    _t = now;
    _b = rec;
  }

  void update({Status? s, double? p, String? e}) {
    if (s != null) status = s;
    if (p != null) progress = p;
    if (e != null) error = e;
    notifyListeners();
  }
}

String formatSpeed(double bps) => '${(bps / 1048576).toStringAsFixed(1)} MB/S';

String formatEta(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class QueueStats {
  QueueStats(this.active, this.waiting, this.speed, this.fraction, this.eta);
  final int active;
  final int waiting;
  final double speed; // bytes/s
  final double fraction; // 0..1 over unfinished work
  final int? eta; // seconds, null when unknown
}

class DownloadQueue extends ChangeNotifier {
  DownloadQueue(this.scraper);
  final Scraper scraper;
  final Library lib = Library();
  final List<Task> tasks = [];
  int _maxQuality = 720; // 1080p+ needs a login on the site
  int _concurrency = 2;

  int get maxQuality => _maxQuality;
  set maxQuality(int v) {
    _maxQuality = v;
    _saveSettings();
  }

  int get concurrency => _concurrency;
  set concurrency(int v) {
    _concurrency = v;
    _saveSettings();
    _pump();
  }

  String lastUrl = '';

  Future<void> loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      _maxQuality = p.getInt('s_quality') ?? _maxQuality;
      _concurrency = p.getInt('s_parallel') ?? _concurrency;
      _wifiOnly = p.getBool('s_wifi') ?? _wifiOnly;
      lastUrl = p.getString('s_url') ?? '';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('s_quality', _maxQuality);
      await p.setInt('s_parallel', _concurrency);
      await p.setBool('s_wifi', _wifiOnly);
      await p.setString('s_url', lastUrl);
    } catch (_) {}
  }

  void rememberUrl(String url) {
    lastUrl = url;
    _saveSettings();
  }

  int _active = 0;

  // --- network policy -------------------------------------------------
  static const maxAttempts = 3;
  bool _wifiOnly = false;
  bool _onWifi = true;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  bool get wifiOnly => _wifiOnly;
  bool get blocked => _wifiOnly && !_onWifi;

  set wifiOnly(bool v) {
    _wifiOnly = v;
    _saveSettings();
    _enforceNet();
  }

  bool _isWifi(List<ConnectivityResult> r) =>
      r.contains(ConnectivityResult.wifi) ||
      r.contains(ConnectivityResult.ethernet);

  Future<void> initNet() async {
    _onWifi = _isWifi(await Connectivity().checkConnectivity());
    _netSub = Connectivity().onConnectivityChanged.listen((r) {
      _onWifi = _isWifi(r);
      _enforceNet();
    });
    _enforceNet();
  }

  /// Pause running downloads when blocked, resume waiting ones otherwise.
  void _enforceNet() {
    if (blocked) {
      for (final t in tasks.where((t) => t.busy)) {
        t.pausedByNet = true;
        t.token?.cancel('nowifi');
      }
    } else {
      _pump();
    }
    notifyListeners();
  }

  QueueStats stats() {
    var active = 0, waiting = 0;
    var speed = 0.0, got = 0.0, all = 0.0;
    for (final t in tasks) {
      if (t.busy && t.status == Status.downloading) {
        active++;
        speed += t.speed;
        got += t.received;
        all += t.total;
      } else if (t.status == Status.waiting || t.status == Status.resolving) {
        waiting++;
        final l = scraper.done[t.video.id];
        final mb = l == null ? null : Scraper.pick(l, maxQuality)?.mb;
        if (mb != null) all += mb * 1048576;
      }
    }
    final eta = speed > 0 && all > got ? ((all - got) / speed).ceil() : null;
    return QueueStats(active, waiting, speed, all > 0 ? got / all : 0, eta);
  }

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
              'origin': t.video.origin,
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
          origin: m['origin'] ?? 'https://www.eporner.com',
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
    t.attempts = 0;
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

  @override
  void dispose() {
    _netSub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Timer? _tick;

  /// 1 Hz refresh of aggregate stats/notification while anything runs.
  void _syncTicker() {
    if (_active > 0) {
      _tick ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _pump() {
    if (blocked) return;
    while (_active < concurrency) {
      final next = tasks.where((t) => t.status == Status.waiting).firstOrNull;
      if (next == null) return;
      _active++;
      next.busy = true;
      next.status = Status.resolving;
      _run(next).whenComplete(() {
        _active--;
        _pump();
        _syncTicker();
      });
    }
    _syncTicker();
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
      t.startMeter(received, total);
      t.update(s: Status.downloading, p: total > 0 ? received / total : 0);
      final sink = File(part)
          .openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in body.stream) {
          sink.add(chunk);
          received += chunk.length;
          t.sample(received);
          if (total > 0) t.update(p: received / total);
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && received != total) {
        t.transient = true;
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
        t.transient = _isTransient(e);
      }
    } on Object catch (e) {
      if (e is HttpException ||
          e is SocketException ||
          e is TimeoutException ||
          e is HandshakeException) {
        err = 'Connection lost';
        t.transient = true;
      } else {
        err = '$e';
      }
    } finally {
      t.busy = false;
      t.speed = 0;
      if (end == Status.canceled && t.pausedByNet) {
        end = Status.waiting; // resumes (Range) once Wi-Fi is back
      }
      t.pausedByNet = false;
      if (end == Status.done) t.attempts = 0;
      if (end == Status.failed && t.transient && t.attempts < maxAttempts) {
        t.attempts++;
        final wait = [2, 6, 15][t.attempts - 1];
        err = '$err — retry ${t.attempts}/$maxAttempts in ${wait}s';
        Future.delayed(Duration(seconds: wait), () {
          if (t.status == Status.failed && !t.busy) {
            t.update(s: Status.waiting);
            _pump();
          }
        });
      }
      t.transient = false;
      t.update(s: end, e: err);
      notifyListeners();
      _persist();
    }
  }

  bool _isTransient(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        return (e.response?.statusCode ?? 0) >= 500;
      default:
        return false;
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
