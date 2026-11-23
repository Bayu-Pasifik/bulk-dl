import 'package:dio/dio.dart';import 'package:html/parser.dart' as html;

const _ua =
    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0 Mobile Safari/537.36';

class VideoItem {
  VideoItem({required this.id, required this.path, required this.title, this.thumb});
  final String id;
  final String path; // e.g. /video-xxx/slug/
  final String title;
  final String? thumb;
}

class DownloadLink {
  DownloadLink(this.quality, this.url, this.av1);
  final int quality;
  final String url;
  final bool av1;
}

class Scraper {
  Scraper()
      : dio = Dio(BaseOptions(
          headers: {'User-Agent': _ua},
          followRedirects: true,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ));

  final Dio dio;
  static const host = 'https://www.eporner.com';

  Future<String> _get(String url) async {
    final r = await dio.get<String>(url,
        options: Options(responseType: ResponseType.plain));
    return r.data ?? '';
  }

  /// Walks playlist pages (/, /2/, /3/ ...) until no new videos appear.
  Future<List<VideoItem>> fetchPlaylist(String url,
      {void Function(int count)? onProgress, int maxPages = 100}) async {
    final base = Uri.parse(url.trim());
    var basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    basePath = basePath.replaceFirst(RegExp(r'\d+/$'), '');
    if (!basePath.endsWith('/')) basePath += '/';
    final seen = <String, VideoItem>{};
    for (var page = 1; page <= maxPages; page++) {
      final u = Uri(
        scheme: 'https',
        host: base.host,
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
      final found = _parseVideos(body);      final before = seen.length;
      for (final v in found) {
        seen.putIfAbsent(v.id, () => v);
      }
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
      out.add(VideoItem(
        id: m.group(1)!,
        path: m.group(0)!,
        title: slug.isEmpty ? m.group(1)! : slug.replaceAll('-', ' '),
        thumb: (thumb != null && thumb.startsWith('http')) ? thumb : null,
      ));
    }
    return out;
  }

  Future<List<DownloadLink>> fetchLinks(VideoItem v) async {
    final body = await _get('$host${v.path}');
    final re = RegExp(r'href="(/dload/[^"]+?/(\d+)/[^"]+?\.mp4)"');
    final links = <DownloadLink>[];
    for (final m in re.allMatches(body)) {
      final path = m.group(1)!;
      links.add(DownloadLink(
          int.parse(m.group(2)!), '$host$path', path.contains('-av1')));
    }
    return links;
  }

  /// Best link with quality <= [maxQuality]; prefers h264 over av1.
  static DownloadLink? pick(List<DownloadLink> links, int maxQuality) {
    if (links.isEmpty) return null;
    final ok = links.where((l) => l.quality <= maxQuality).toList();
    final pool = ok.isEmpty ? links : ok;
    pool.sort((a, b) {
      final q = b.quality.compareTo(a.quality);
      if (q != 0) return q;
      return (a.av1 ? 1 : 0).compareTo(b.av1 ? 1 : 0);
    });
    return pool.first;
  }
}
