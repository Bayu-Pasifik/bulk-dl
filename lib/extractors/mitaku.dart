import 'dart:async';

import 'package:html/parser.dart' as html;

import '../hls.dart';
import '../models.dart';
import '../naming.dart';
import '../net/http.dart';
import 'extractor.dart';

/// Opens the embedded player for [embedUrl] and returns the media URL
/// (`.m3u8`/`.mp4`) once the user has pressed play; null if dismissed.
typedef StreamSniffer = Future<String?> Function(String embedUrl, String title);

/// mitaku.net: WordPress galleries. A post page lists full-size images
/// (`data-mfp-src`) and, for video posts, an embedded third-party player.
/// Embedded videos are played by the user in a WebView and the stream URL is
/// captured (see [sniffer]); category/tag/search pages list posts.
class MitakuExtractor implements Extractor {
  @override
  String get id => 'mitaku';

  /// Set by the app; shows the player so the user can press play.
  static StreamSniffer? sniffer;

  /// Captured stream URL by embed URL (this run only).
  static final Map<String, String> streams = {};

  /// Where the player was embedded, per CDN host (needed as Referer).
  static final Map<String, String> referers = {};

  static Future<void> _lock = Future.value();

  static bool hostMatches(Uri u) =>
      u.host == 'mitaku.net' || u.host.endsWith('.mitaku.net');

  static final _pageSuffix = RegExp(r'/page/\d+/?$');

  /// Video items point at the player page, images at the file itself.
  static bool isEmbed(VideoItem v) => v.path == '/embed';

  @override
  Future<UrlKind?> classify(Uri u, Http http) async =>
      hostMatches(u) ? UrlKind.playlist : null;

  @override
  VideoItem single(Uri u, Http http) => _image(u.toString(), null);

  static String _basePath(Uri u) {
    var p = u.path.replaceFirst(_pageSuffix, '');
    if (!p.endsWith('/')) p = '$p/';
    return p;
  }

  VideoItem _image(String url, String? title) {
    final uri = Uri.parse(url);
    final name = nameFromUrl(uri) ?? uri.host;
    return VideoItem(
      id: stableId(url),
      path: uri.path,
      origin: '${uri.scheme}://${uri.authority}',
      title: title != null && title.isNotEmpty ? title : stemOf(name),
      thumb: url,
      extractor: id,
      url: url,
    );
  }

  VideoItem _video(String embed, String title, String? thumb) {
    return VideoItem(
      id: stableId(embed),
      path: '/embed',
      origin: 'https://mitaku.net',
      title: title,
      thumb: thumb,
      extractor: id,
      url: embed,
    );
  }

  /// Full-size image URLs on a post page, in order, de-duplicated.
  static List<String> parseImages(String body) {
    final doc = html.parse(body);
    final out = <String>[];
    final seen = <String>{};
    void add(String? u) {
      if (u == null || !u.startsWith('http')) return;
      if (!u.contains('/wp-content/uploads/')) return;
      if (seen.add(u)) out.add(u);
    }

    for (final a in doc.querySelectorAll('a.msacwl-img-link')) {
      add(a.attributes['data-mfp-src']);
    }
    if (out.isEmpty) {
      for (final i in doc.querySelectorAll('img.msacwl-img')) {
        add(i.attributes['data-lazy']);
      }
    }
    return out;
  }

  /// Embedded player URLs in a post's content.
  static List<String> parseEmbeds(String body) {
    final doc = html.parse(body);
    final out = <String>[];
    for (final f in doc.querySelectorAll('.entry-content iframe[src]')) {
      final s = (f.attributes['src'] ?? '').trim();
      final u = Uri.tryParse(s);
      if (u == null || !u.hasScheme || hostMatches(u)) continue;
      if (!out.contains(s)) out.add(s);
    }
    return out;
  }

  static String _postTitle(String body) {
    final doc = html.parse(body);
    final og = doc
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    var t = (og ?? doc.querySelector('title')?.text ?? '').trim();
    t = t.replaceFirst(RegExp(r'\s*[-–|]\s*Mitaku\s*$'), '');
    return t;
  }

  static String? _postThumb(String body) => html
      .parse(body)
      .querySelector('meta[property="og:image"]')
      ?.attributes['content'];

  /// Items on one post page: its videos and (if [images]) its images.
  List<VideoItem> _postItems(String body, {required bool images}) {
    final out = <VideoItem>[];
    final title = _postTitle(body);
    final thumb = _postThumb(body);
    final embeds = parseEmbeds(body);
    for (var i = 0; i < embeds.length; i++) {
      out.add(
        _video(
          embeds[i],
          embeds.length > 1 ? '$title (video ${i + 1})' : '$title (video)',
          thumb,
        ),
      );
    }
    if (images) {
      for (final u in parseImages(body)) {
        out.add(_image(u, null));
      }
    }
    return out;
  }

  static List<String> parsePosts(String body) {
    final doc = html.parse(body);
    final out = <String>[];
    final seen = <String>{};
    for (final a in doc.querySelectorAll('article .entry-title a[href]')) {
      final h = (a.attributes['href'] ?? '').split('#').first;
      if (h.startsWith('http') && seen.add(h)) out.add(h);
    }
    return out;
  }

  @override
  Future<List<VideoItem>> listPlaylist(
    Uri base,
    Http http, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  }) async {
    final first = await http.getText(base.toString());
    final basePath = _basePath(base);
    // Video categories: only the videos, the photos would drown them.
    final videosOnly = basePath.contains('online-video');

    final own = _postItems(first, images: true);
    if (own.isNotEmpty) {
      onProgress?.call(own.length);
      return own;
    }
    if (parsePosts(first).isEmpty) throw 'No media found at this link';

    final items = <String, VideoItem>{};
    final seenPosts = <String>{};
    for (var page = 1; page <= maxPages; page++) {
      String body;
      if (page == 1) {
        body = first;
      } else {
        final u = Uri(
          scheme: base.scheme.isEmpty ? 'https' : base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: '${basePath}page/$page/',
          query: base.hasQuery ? base.query : null,
        ).toString();
        try {
          body = await http.getText(u);
        } catch (_) {
          break;
        }
      }
      final posts = parsePosts(body).where(seenPosts.add).toList();
      if (posts.isEmpty) break;
      for (final p in posts) {
        try {
          final its = _postItems(await http.getText(p), images: !videosOnly);
          for (final v in its) {
            items.putIfAbsent(v.url, () => v);
          }
        } catch (_) {
          // Skip a post that fails; keep the rest.
        }
        onProgress?.call(items.length);
      }
    }
    if (items.isEmpty) throw 'No media found at this link';
    return items.values.toList();
  }

  /// Runs [sniffer] for [v] (one at a time) and remembers the stream.
  static Future<void> sniff(VideoItem v) {
    if (streams.containsKey(v.url)) return Future.value();
    final run = _lock.then((_) async {
      if (streams.containsKey(v.url)) return;
      final s = sniffer;
      if (s == null) throw 'Player not available';
      final url = await s(v.url, v.title);
      if (url == null || url.isEmpty) throw 'Video not played';
      streams[v.url] = url;
      final h = Uri.tryParse(url)?.host;
      if (h != null && h.isNotEmpty) {
        final e = Uri.parse(v.url);
        referers[h] = '${e.scheme}://${e.authority}/';
      }
    });
    _lock = run.catchError((_) {});
    return run;
  }

  /// True when [v] is a video whose stream has not been captured yet.
  static bool needsSniff(VideoItem v) =>
      v.extractor == 'mitaku' && isEmbed(v) && !streams.containsKey(v.url);

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    if (isEmbed(v)) {
      final s = streams[v.url];
      if (s == null) {
        // Placeholder: size/quality unknown until the user plays it.
        return [DownloadLink(0, v.url, false, null, false, 'mp4')];
      }
      if (Uri.parse(s).path.toLowerCase().endsWith('.m3u8')) {
        return hlsLinks(s, http);
      }
      double? mb;
      try {
        final h = await http.head(s);
        if (h.length != null) mb = h.length! / 1048576;
      } catch (_) {}
      return [DownloadLink(0, s, false, mb, false, 'mp4')];
    }
    final name = nameFromUrl(Uri.parse(v.url)) ?? v.title;
    var ext = extOf(name);
    if (ext.isEmpty) ext = 'jpg';
    double? mb;
    try {
      final h = await http.head(v.url);
      if (h.length != null) mb = h.length! / 1048576;
    } catch (_) {}
    return [DownloadLink(0, v.url, false, mb, false, ext, name)];
  }
}
