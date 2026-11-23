import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'scraper.dart';

enum Status { waiting, resolving, downloading, done, failed, canceled }

class Task extends ChangeNotifier {
  Task(this.video);
  final VideoItem video;
  Status status = Status.waiting;
  double progress = 0;
  String? error;
  String? file;
  CancelToken? token;

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
  int maxQuality = 1080;
  int concurrency = 2;
  int _active = 0;

  Future<Directory> outDir() async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/BulkDL');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
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
    t.token?.cancel();
    if (t.status == Status.waiting) t.update(s: Status.canceled);
  }

  void retry(Task t) {
    t.update(s: Status.waiting, p: 0);
    _pump();
  }

  void clearFinished() {
    tasks.removeWhere((t) =>
        t.status == Status.done ||
        t.status == Status.canceled ||
        t.status == Status.failed);
    notifyListeners();
  }

  void _pump() {
    while (_active < concurrency) {
      final next = tasks.where((t) => t.status == Status.waiting).firstOrNull;
      if (next == null) return;
      _active++;
      next.status = Status.resolving;
      _run(next).whenComplete(() {
        _active--;
        _pump();
      });
    }
  }

  Future<void> _run(Task t) async {
    t.update(s: Status.resolving);
    try {
      final links = await scraper.links(t.video);
      final link = Scraper.pick(links, maxQuality);
      if (link == null) throw 'No download link';
      final dir = await outDir();
      final name = _safe('${t.video.title}_${link.quality}p_${t.video.id}.mp4');
      final path = '${dir.path}/$name';
      t.token = CancelToken();
      t.update(s: Status.downloading, p: 0);
      await scraper.dio.download(
        link.url,
        '$path.part',
        cancelToken: t.token,
        deleteOnError: true,
        onReceiveProgress: (r, total) {
          if (total > 0) t.update(p: r / total);
        },
      );
      await File('$path.part').rename(path);
      t.file = path;
      t.update(s: Status.done, p: 1);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        t.update(s: Status.canceled);
      } else {
        t.update(s: Status.failed, e: e.message ?? e.type.name);
      }
    } catch (e) {
      t.update(s: Status.failed, e: '$e');
    }
  }

  String _safe(String s) => s.replaceAll(RegExp(r'[^\w.\- ]'), '_');
}
