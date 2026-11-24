import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'extractors/mitaku.dart';
import 'extractors/registry.dart';
import 'models.dart';
import 'net/http.dart';
import 'net/http_factory.dart';

export 'extractors/registry.dart' show Classified;
export 'models.dart';

/// CDNs that refuse media requests without the site's Referer (HTTP 410/403).
const _cdnReferers = {
  't8cdn.com': 'https://www.tube8.com/',
  'mydaddy.cc': 'https://hqporner.com/',
  'hstorage.xyz': 'https://watchhentai.net/',
};

/// Front door for all sites: classifies URLs, lists playlists and resolves
/// download links through the matching [Extractor]. Caches and throttles.
class Scraper extends ChangeNotifier {
  Scraper({Dio? dio, Registry? registry})
    : dio = dio ?? createDio(),
      registry = registry ?? Registry() {
    http = DioHttp(this.dio);
    // Session cookies (e.g. logged-in HD links), only sent to their own host.
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          final c = cookies[o.uri.host];
          if (c != null && c.isNotEmpty) o.headers['Cookie'] = c;
          for (final e in _cdnReferers.entries) {
            if (o.uri.host.endsWith(e.key) &&
                !o.headers.containsKey('Referer')) {
              o.headers['Referer'] = e.value;
            }
          }
          final ref = MitakuExtractor.referers[o.uri.host];
          if (ref != null && !o.headers.containsKey('Referer')) {
            o.headers['Referer'] = ref;
          }
          h.next(o);
        },
      ),
    );
  }

  final Dio dio;
  final Registry registry;
  late final DioHttp http;

  /// Raw `Cookie` header values by host (optional, pasted by the user).
  final Map<String, String> cookies = {};

  Future<Classified> classify(String url) => registry.classify(url, http);

  /// Single item for a file/video classification.
  VideoItem itemFor(Classified c) => c.extractor.single(c.uri, http);

  /// Walks playlist pages for [url] with the extractor that recognises it.
  Future<List<VideoItem>> fetchPlaylist(
    String url, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  }) async {
    final c = await classify(url);
    return c.extractor.listPlaylist(
      c.uri,
      http,
      onProgress: onProgress,
      maxPages: maxPages,
    );
  }

  // Link cache + throttle: size info lives on each video page.
  final Map<String, List<DownloadLink>> done = {};
  final Set<String> failed = {};
  final Map<String, Future<List<DownloadLink>>> _pending = {};
  int get pendingCount => _pending.length;
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

  Future<List<DownloadLink>> fetchLinks(VideoItem v) =>
      registry.byId(v.extractor).resolve(v, http);

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
      final c = (a.av1 ? 1 : 0).compareTo(b.av1 ? 1 : 0);
      if (c != 0) return c;
      return (b.mb ?? 0).compareTo(a.mb ?? 0); // bigger = likelier the real one
    });
    return pool;
  }
}
