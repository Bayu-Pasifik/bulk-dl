import 'package:html/parser.dart' as html;

import '../models.dart';
import '../net/http.dart';
import 'extractor.dart';

/// Eporner-style sites: `/video-<id>/<slug>/` pages with `/dload/` links.
class EpornerExtractor implements Extractor {
  @override
  String get id => 'eporner';

  static final _videoPath = RegExp(r'^/video-([^/]+)/([^/]*)/?');

  bool _hostMatches(Uri u) => u.host.endsWith('eporner.com');

  @override
  Future<UrlKind?> classify(Uri u, Http http) async {
    if (_hostMatches(u)) {
      return _videoPath.hasMatch(u.path) ? UrlKind.video : UrlKind.playlist;
    }
    // Unknown host: sniff the page for this site's markup.
    if (_videoPath.hasMatch(u.path)) return UrlKind.video;
    try {
      // A trailing page number (/x/2/) means "page 2 of /x/": sniff page 1.
      final target = RegExp(r'/\d+/?$').hasMatch(u.path)
          ? u.replace(path: _basePath(u))
          : u;
      final body = await http.getText(target.toString());
      if (RegExp(r'/dload/[^"]+\.mp4').hasMatch(body)) return UrlKind.video;
      if (html.parse(body).querySelector('a[href^="/video-"]') != null) {
        return UrlKind.playlist;
      }
    } catch (_) {}
    return null;
  }

  /// Playlist path without a trailing page number (/x/2/ -> /x/).
  static String _basePath(Uri u) {
    var p = u.path.endsWith('/') ? u.path : '${u.path}/';
    p = p.replaceFirst(RegExp(r'\d+/$'), '');
    return p.endsWith('/') ? p : '$p/';
  }

  @override
  VideoItem single(Uri u, Http http) {
    final m = _videoPath.firstMatch(u.path)!;
    final slug = m.group(2) ?? '';
    return VideoItem(
      id: m.group(1)!,
      path: m.group(0)!,
      origin: '${u.scheme}://${u.authority}',
      title: slug.isEmpty ? m.group(1)! : slug.replaceAll('-', ' '),
    );
  }

  /// Walks playlist pages (/, /2/, /3/ ...) until no new videos appear.
  @override
  Future<List<VideoItem>> listPlaylist(
    Uri base,
    Http http, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  }) async {
    final basePath = _basePath(base);
    final origin = '${base.scheme}://${base.authority}';
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
        body = await http.getText(u);
      } catch (_) {
        if (page == 1) rethrow;
        break;
      }
      final found = _parseVideos(body, origin);
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

  List<VideoItem> _parseVideos(String body, String origin) {
    final doc = html.parse(body);
    final out = <VideoItem>[];
    final ids = <String>{};
    for (final a in doc.querySelectorAll('a[href^="/video-"]')) {
      final m = _videoPath.firstMatch(a.attributes['href'] ?? '');
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
          origin: origin,
          title: real.isNotEmpty
              ? real
              : (slug.isEmpty ? m.group(1)! : slug.replaceAll('-', ' ')),
          thumb: (thumb != null && thumb.startsWith('http')) ? thumb : null,
        ),
      );
    }
    return out;
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final body = await http.getText('${v.origin}${v.path}');
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
}
