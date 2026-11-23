import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;

const _ua =
    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0 Mobile Safari/537.36';

class VideoItem {
  VideoItem({
    required this.id,
    required this.path,
    required this.origin,
    required this.title,
    this.thumb,
  });
  final String id;
  final String path; // e.g. /video-xxx/slug/
  final String origin; // e.g. https://site.com (survives restarts)
  final String title;
  final String? thumb;
}

class DownloadLink {
  DownloadLink(this.quality, this.url, this.av1, [this.mb]);
  final int quality;
  final String url;
  final bool av1;
  final double? mb;
}

String formatSize(double mb) =>
    mb >= 1024 ? '${(mb / 1024).toStringAsFixed(2)} GB' : '${mb.round()} MB';

class Scraper extends ChangeNotifier {
  Scraper()
    : dio = Dio(
        BaseOptions(
          headers: {'User-Agent': _ua},
          followRedirects: true,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio dio;

  /// Origin of the playlist link; set by [fetchPlaylist].
  String host = 'https://www.eporner.com';

  Future<String> _get(String url) async {
    final r = await dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return r.data ?? '';
  }

  /// Walks playlist pages (/, /2/, /3/ ...) until no new videos appear.
  Future<List<VideoItem>> fetchPlaylist(
    String url, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  }) async {
    final base = Uri.parse(url.trim());
    var basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    basePath = basePath.replaceFirst(RegExp(r'\d+/$'), '');
    if (!basePath.endsWith('/')) basePath += '/';
    host = '${base.scheme}://${base.authority}';
    final seen = <String, VideoItem>{};
    for (var page = 1; page <= maxPages; page++) {
      final u = Uri(
        scheme: base.scheme.isEmpty ? 'https' : base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: page == 1 ? basePath : '$basePath$page/',
        query: base.hasQuery ? base.query : null,
      ).toString();
      String body;
      try {
        body = await _get(u);
      } on DioException {
        if (page == 1) rethrow;
        break;
      }
      final found = _parseVideos(body);
      final before = seen.length;
      for (final v in found) {
        seen.putIfAbsent(v.id, () => v);
      }
      if (page == 1 && found.isEmpty) throw 'No videos found at this link';
      onProgress?.call(seen.length);
      if (seen.length == before) break;
    }
    return seen.values.toList();
  }

  List<VideoItem> _parseVideos(String body) {
    final doc = html.parse(body);
    final out = <VideoItem>[];
    final re = RegExp(r'^/video-([^/]+)/([^/]*)/?');
    final ids = <String>{};
    for (final a in doc.querySelectorAll('a[href^="/video-"]')) {
      final m = re.firstMatch(a.attributes['href'] ?? '');
      if (m == null || !ids.add(m.group(1)!)) continue;
      // Thumbnail lives in the same card; climb up to find an <img>.
      String? thumb;
      var node = a.parent;
      for (var i = 0; i < 3 && node != null && thumb == null; i++) {
        final img = node.querySelector('img');
        thumb = img?.attributes['data-src'] ?? img?.attributes['src'];
        node = node.parent;
      }
      final slug = m.group(2) ?? '';
      final real =
          (a.attributes['title'] ??
                  a.querySelector('img')?.attributes['alt'] ??
                  '')
              .trim();
      out.add(
        VideoItem(
          id: m.group(1)!,
          path: m.group(0)!,
          origin: host,
          title: real.isNotEmpty
              ? real
              : (slug.isEmpty ? m.group(1)! : slug.replaceAll('-', ' ')),
          thumb: (thumb != null && thumb.startsWith('http')) ? thumb : null,
        ),
      );
    }
    return out;
  }

  // Link cache + throttle: size info lives on each video page.
  final Map<String, List<DownloadLink>> done = {};
  final Set<String> failed = {};
  final Map<String, Future<List<DownloadLink>>> _pending = {};
  static const _maxParallel = 3;
  int _running = 0;
  final _waiters = <Completer<void>>[];

  Future<void> _acquire() async {
    if (_running < _maxParallel) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _running--;
    }
  }

  /// Fire-and-forget: loads links (and sizes) so the UI can show them.
  void ensure(VideoItem v) {
    if (done.containsKey(v.id) || failed.contains(v.id)) return;
    links(v).ignore();
  }

  Future<List<DownloadLink>> links(VideoItem v) {
    final d = done[v.id];
    if (d != null) return Future.value(d);
    return _pending[v.id] ??= _load(v);
  }

  Future<List<DownloadLink>> _load(VideoItem v) async {
    await _acquire();
    try {
      final l = await fetchLinks(v);
      done[v.id] = l;
      failed.remove(v.id);
      return l;
    } catch (_) {
      failed.add(v.id);
      rethrow;
    } finally {
      _release();
      _pending.remove(v.id);
      notifyListeners();
    }
  }

  Future<List<DownloadLink>> fetchLinks(VideoItem v) async {
    final body = await _get('${v.origin}${v.path}');
    final re = RegExp(r'href="(/dload/[^"]+?/(\d+)/[^"]+?\.mp4)"[^>]*>([^<]*)');
    final sizeRe = RegExp(r'([\d.]+)\s*(MB|GB)', caseSensitive: false);
    final links = <DownloadLink>[];
    for (final m in re.allMatches(body)) {
      final path = m.group(1)!;
      final s = sizeRe.firstMatch(m.group(3) ?? '');
      double? mb;
      if (s != null) {
        mb = double.tryParse(s.group(1)!);
        if (mb != null && s.group(2)!.toUpperCase() == 'GB') mb *= 1024;
      }
      links.add(
        DownloadLink(
          int.parse(m.group(2)!),
          '${v.origin}$path',
          path.contains('-av1'),
          mb,
        ),
      );
    }
    if (links.isEmpty) throw 'No download links on page';
    return links;
  }

  /// Re-allows size loading for videos that failed before.
  void retryFailed(Iterable<VideoItem> items) {
    for (final v in items) {
      failed.remove(v.id);
    }
    notifyListeners();
  }

  /// Best link with quality <= [maxQuality]; prefers h264 over av1.
  static DownloadLink? pick(List<DownloadLink> links, int maxQuality) =>
      candidates(links, maxQuality).firstOrNull;

  /// Links with quality <= [maxQuality], best first (h264 before av1).
  /// Falls back to all links if none qualify.
  static List<DownloadLink> candidates(
    List<DownloadLink> links,
    int maxQuality,
  ) {
    final ok = links.where((l) => l.quality <= maxQuality).toList();
    final pool = ok.isEmpty ? [...links] : ok;
    pool.sort((a, b) {
      final q = b.quality.compareTo(a.quality);
      if (q != 0) return q;
      return (a.av1 ? 1 : 0).compareTo(b.av1 ? 1 : 0);
    });
    return pool;
  }
}
