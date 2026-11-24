import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../hls.dart';
import '../models.dart';
import '../naming.dart';
import '../net/http.dart';
import 'extractor.dart';

/// Shared plumbing for site-specific extractors: host matching, card-based
/// playlist paging and item creation. Subclasses supply [videoId] and
/// [resolve].
const _challengeMarker = 'function leastFactor';
const _blockedMsg =
    'Site anti-bot check blocked the request. Wait a minute and retry, '
    'or try a VPN/proxy';

abstract class SiteExtractor implements Extractor {
  /// Host suffixes handled by this extractor (e.g. `xnxx.com`).
  List<String> get hosts;

  /// Unique id of the video behind [u], or null when [u] is not a video page.
  String? videoId(Uri u);

  bool matches(Uri u) =>
      hosts.any((h) => u.host == h || u.host.endsWith('.$h'));

  @override
  Future<UrlKind?> classify(Uri u, Http http) async {
    if (!matches(u)) return null;
    return videoId(u) != null ? UrlKind.video : UrlKind.playlist;
  }

  String _slugTitle(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    final last = segs.isEmpty ? u.host : segs.last;
    final t = stemOf(last).replaceAll(RegExp(r'[-_+]+'), ' ').trim();
    return t.isEmpty || RegExp(r'^[a-z0-9.]*php$').hasMatch(t) ? u.host : t;
  }

  VideoItem _item(Uri u, {String? title, String? thumb}) {
    final id = videoId(u) ?? stableId(u.toString());
    return VideoItem(
      id: id,
      path: '${u.path}${u.hasQuery ? '?${u.query}' : ''}',
      origin: '${u.scheme}://${u.authority}',
      title: (title == null || title.isEmpty) ? _slugTitle(u) : title,
      thumb: thumb,
      extractor: this.id,
      url: u.toString(),
    );
  }

  @override
  VideoItem single(Uri u, Http http) => _item(u);

  /// Video cards on a listing page, keyed by video id.
  Map<String, VideoItem> cards(Document doc, Uri page) {
    final out = <String, VideoItem>{};
    final real = <String>{}; // ids whose title came from the page
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = (a.attributes['href'] ?? '').trim();
      if (href.isEmpty ||
          href.startsWith('#') ||
          href.startsWith('javascript:')) {
        continue;
      }
      final u = page.resolve(href).removeFragment();
      if (!matches(u) || videoId(u) == null) continue;
      final id = videoId(u)!;
      final img =
          a.querySelector('img') ??
          a.parent?.querySelector('img') ??
          a.parent?.parent?.querySelector('img');
      final rawThumb =
          img?.attributes['data-original'] ??
          img?.attributes['data-src'] ??
          img?.attributes['data-mediumthumb'] ??
          img?.attributes['src'];
      final thumb = rawThumb == null ? null : page.resolve(rawThumb).toString();
      final title = (a.attributes['title'] ?? img?.attributes['alt'] ?? a.text)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final prev = out[id];
      final goodThumb = (thumb != null && thumb.startsWith('http'))
          ? thumb
          : null;
      if (prev == null) {
        out[id] = _item(u, title: title, thumb: goodThumb);
        if (title.isNotEmpty) real.add(id);
      } else {
        // Same video linked twice (thumb + caption): keep the best of each.
        final useNew =
            title.isNotEmpty &&
            (!real.contains(id) || title.length > prev.title.length);
        if (useNew) real.add(id);
        out[id] = _item(
          Uri.parse(prev.url),
          title: useNew ? title : prev.title,
          thumb: prev.thumb ?? goodThumb,
        );
      }
    }
    return out;
  }

  Uri? _nextPage(Document doc, Uri page) {
    final n = doc.querySelector(
      'a.next, a.next-page, a.dir.next, li.page_next a, a[rel="next"], link[rel="next"]',
    );
    final href = n?.attributes['href'];
    if (href == null || href.isEmpty || href == '#') return null;
    return page.resolve(href);
  }

  @override
  Future<List<VideoItem>> listPlaylist(
    Uri u,
    Http http, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  }) async {
    final all = <String, VideoItem>{};
    final visited = <String>{};
    Uri? next = u;
    for (var page = 0; page < maxPages && next != null; page++) {
      if (!visited.add(next.toString())) break;
      String body;
      try {
        body = await http.getText(next.toString());
        // Anti-bot challenge stub (Pornhub): retry a few times.
        for (var i = 1; i < 5 && body.contains(_challengeMarker); i++) {
          await Future<void>.delayed(Duration(seconds: 2 * i));
          body = await http.getText(next.toString());
        }
      } catch (_) {
        if (page == 0) rethrow;
        break;
      }
      final doc = html.parse(body);
      final before = all.length;
      for (final e in cards(doc, next).entries) {
        all.putIfAbsent(e.key, () => e.value);
      }
      onProgress?.call(all.length);
      if (page == 0 && all.isEmpty) {
        throw body.contains(_challengeMarker)
            ? _blockedMsg
            : 'No videos found at this link';
      }
      if (all.length == before) break;
      next = _nextPage(doc, next);
    }
    return all.values.toList();
  }

  String pageTitle(String body, String fallback) {
    final doc = html.parse(body);
    final og = doc
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    final t = (og ?? doc.querySelector('title')?.text ?? '').trim();
    return sanitize(t.isEmpty ? fallback : t);
  }

  /// Fills in file sizes of plain (non-HLS) links with one HEAD each.
  Future<List<DownloadLink>> withSizes(
    List<DownloadLink> links,
    Http http,
  ) async {
    return Future.wait(
      links.map((l) async {
        if (l.hls) return l;
        try {
          final h = await http.head(l.url);
          if (h.type != null && h.type!.contains('html')) return l;
          final mb = h.length == null ? null : h.length! / 1048576;
          return DownloadLink(
            l.quality,
            h.url,
            l.av1,
            mb,
            false,
            l.ext,
            l.fileName,
          );
        } catch (_) {
          return l;
        }
      }),
    );
  }
}

/// xnxx / xvideos: the video page embeds `html5player.setVideoUrlLow(...)`,
/// `setVideoUrlHigh(...)` and `setVideoHLS(...)`.
class XvideosFamilyExtractor extends SiteExtractor {
  @override
  String get id => 'xvideos';

  @override
  List<String> get hosts => const [
    'xnxx.com',
    'xnxx.es',
    'xnxx.tv',
    'xvideos.com',
    'xvideos.es',
    'xvideos2.com',
    'xvideos3.com',
  ];

  // /video-<id>/slug (xnxx), /video.<id>/slug or /video<digits>/slug (xvideos)
  static final _path = RegExp(r'^/video(?:[.-]([a-z0-9]+)|(\d+))(?:/|$)');

  @override
  String? videoId(Uri u) {
    final m = _path.firstMatch(u.path);
    return m == null ? null : (m.group(1) ?? m.group(2));
  }

  static String? _call(String body, String name) {
    final m = RegExp("setVideo$name\\('([^']+)'").firstMatch(body);
    return m?.group(1);
  }

  static int _qualityOfUrl(String url, int fallback) {
    final p = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    final m = RegExp(r'(\d{3,4})p').firstMatch(p);
    if (m != null) return int.parse(m.group(1)!);
    if (p.contains('_hd')) return 720;
    if (p.contains('_sd')) return 480;
    return fallback;
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final body = await http.getText(v.url);
    final title = pageTitle(body, v.title);
    final links = <DownloadLink>[];
    final seen = <String>{};

    for (final entry in {'UrlHigh': 720, 'UrlLow': 360}.entries) {
      final url = _call(body, entry.key);
      if (url == null || !seen.add(url)) continue;
      links.add(
        DownloadLink(
          _qualityOfUrl(url, entry.value),
          url,
          false,
          null,
          false,
          'mp4',
          '$title.mp4',
        ),
      );
    }
    final hls = _call(body, 'HLS');
    if (hls != null) {
      try {
        for (final l in await hlsLinks(hls, http)) {
          links.add(
            DownloadLink(
              l.quality,
              l.url,
              false,
              null,
              true,
              l.ext,
              '$title.${l.ext}',
            ),
          );
        }
      } catch (_) {}
    }
    if (links.isEmpty) throw 'No download links on page';
    return withSizes(links, http);
  }
}

/// pornhub / redtube / youporn: the page embeds a `mediaDefinitions` JSON
/// array. `hls` entries point at an m3u8; `mp4` entries usually point at a
/// small JSON endpoint listing one url per quality.
class MediaDefExtractor extends SiteExtractor {
  @override
  String get id => 'mediadef';

  @override
  List<String> get hosts => const [
    'pornhub.com',
    'pornhub.org',
    'redtube.com',
    'youporn.com',
    'tube8.com',
  ];

  @override
  String? videoId(Uri u) {
    final host = u.host;
    if (host.endsWith('pornhub.com') || host.endsWith('pornhub.org')) {
      if (u.path.contains('view_video.php')) {
        final k = u.queryParameters['viewkey'];
        return (k == null || k.isEmpty) ? null : k;
      }
      return null;
    }
    if (host.endsWith('redtube.com')) {
      final m = RegExp(r'^/(\d+)/?$').firstMatch(u.path);
      return m?.group(1);
    }
    if (host.endsWith('youporn.com')) {
      final m = RegExp(r'^/watch/(\d+)').firstMatch(u.path);
      return m?.group(1);
    }
    if (host.endsWith('tube8.com')) {
      final m = RegExp(r'^/porn-video/(\d+)').firstMatch(u.path);
      return m?.group(1);
    }
    return null;
  }

  /// Returns the JSON array that follows `"mediaDefinitions?":` in [body],
  /// found with bracket matching (the array holds nested arrays/strings).
  static List<dynamic>? _mediaDefs(String body) {
    final key = RegExp(r'"mediaDefinitions?"\s*:\s*\[').firstMatch(body);
    if (key == null) return null;
    final start = key.end - 1;
    var depth = 0;
    var inStr = false;
    for (var i = start; i < body.length; i++) {
      final c = body[i];
      if (inStr) {
        if (c == r'\') {
          i++;
        } else if (c == '"') {
          inStr = false;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
      } else if (c == '[') {
        depth++;
      } else if (c == ']' && --depth == 0) {
        try {
          final v = jsonDecode(body.substring(start, i + 1));
          return v is List ? v : null;
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static int _q(dynamic q) {
    if (q is int) return q;
    if (q is String) return int.tryParse(q.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (q is List && q.isNotEmpty) {
      return q.map(_q).fold<int>(0, (a, b) => a > b ? a : b);
    }
    return 0;
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    // Pornhub intermittently answers with a JS challenge page or a 412 on
    // the HLS master: retry a few times before giving up.
    Object? last;
    for (var attempt = 0; attempt < 6; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
      try {
        return await _resolveOnce(v, http);
      } catch (e) {
        last = e;
      }
    }
    throw last ?? 'No download links on page';
  }

  Future<List<DownloadLink>> _resolveOnce(VideoItem v, Http http) async {
    final base = Uri.parse(v.url);
    final body = await http.getText(v.url);
    if (body.contains(_challengeMarker)) throw _blockedMsg;
    final defs = _mediaDefs(body);
    if (defs == null || defs.isEmpty) {
      throw 'No download links on page';
    }
    final title = pageTitle(body, v.title);
    final links = <DownloadLink>[];
    final seen = <String>{};

    Future<void> addEntry(Map e, {int fallbackQ = 0}) async {
      final raw = e['videoUrl'];
      if (raw is! String || raw.isEmpty) return;
      final url = base.resolve(raw.replaceAll(r'\/', '/')).toString();
      final format = '${e['format'] ?? ''}'.toLowerCase();
      final q = _q(e['quality']) == 0 ? fallbackQ : _q(e['quality']);
      if (format == 'hls' || Uri.parse(url).path.endsWith('.m3u8')) {
        if (!seen.add(url)) return;
        try {
          final hl = await hlsLinks(url, http);
          for (final l in hl) {
            links.add(
              DownloadLink(
                l.quality == 0 ? q : l.quality,
                l.url,
                false,
                null,
                true,
                l.ext,
                '$title.${l.ext}',
              ),
            );
          }
        } catch (_) {}
      } else if (Uri.parse(url).path.endsWith('.mp4')) {
        if (!seen.add(url)) return;
        links.add(
          DownloadLink(q, url, false, null, false, 'mp4', '$title.mp4'),
        );
      } else {
        // Indirection: the url returns a JSON list of {quality, videoUrl}.
        if (!seen.add(url)) return;
        try {
          final j = jsonDecode(await http.getText(url));
          if (j is List) {
            for (final item in j) {
              if (item is Map) await addEntry(item, fallbackQ: q);
            }
          }
        } catch (_) {}
      }
    }

    for (final e in defs) {
      if (e is Map) await addEntry(e);
    }
    if (links.isEmpty) throw 'No download links on page';
    return withSizes(links, http);
  }
}

/// KVS (Kernel Video Sharing) sites: the page defines a `flashvars` object
/// with `video_url`, `video_alt_url`, `video_alt_url2`... each paired with a
/// `<name>_text` quality label. Links are plain mp4 behind a 302.
class KvsExtractor extends SiteExtractor {
  @override
  String get id => 'kvs';

  @override
  List<String> get hosts => const [
    'thisvid.com',
    'porntrex.com',
    'sunporno.com',
  ];

  @override
  String? videoId(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (u.host.endsWith('porntrex.com')) {
      final m = RegExp(r'^/video/(\d+)(?:/|$)').firstMatch(u.path);
      return m?.group(1);
    }
    if (u.host.endsWith('sunporno.com')) {
      final m = RegExp(r'^/v/(\d+)(?:/|$)').firstMatch(u.path);
      return m?.group(1);
    }
    // thisvid: /videos/<slug>/
    if (segs.length == 2 && segs[0] == 'videos') return segs[1];
    return null;
  }

  @override
  Uri? _nextPage(Document doc, Uri page) {
    final n = doc.querySelector(
      'li.pagination-next a, li.next a, a.next, a[rel="next"], link[rel="next"]',
    );
    final href = n?.attributes['href'];
    if (href != null && href.isNotEmpty && href != '#') {
      return page.resolve(href);
    }
    // Fallback: /list/ -> /list/2/ -> /list/3/ (the loop stops on no new items).
    final m = RegExp(r'^(.*?)/(\d+)/?$').firstMatch(page.path);
    final path = m == null
        ? '${page.path.endsWith('/') ? page.path : '${page.path}/'}2/'
        : '${m.group(1)}/${int.parse(m.group(2)!) + 1}/';
    return page.replace(path: path);
  }

  static int _label(String? text, String url) {
    final t = text ?? '';
    final m =
        RegExp(r'(\d{3,4})\s*p', caseSensitive: false).firstMatch(t) ??
        RegExp(r'_(\d{3,4})p\.').firstMatch(url);
    if (m != null) return int.parse(m.group(1)!);
    return RegExp(r'hd|hq', caseSensitive: false).hasMatch(t) ? 720 : 0;
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final base = Uri.parse(v.url);
    final body = await http.getText(v.url);
    final title = pageTitle(body, v.title);
    final links = <DownloadLink>[];
    final seen = <String>{};
    for (final m in RegExp(
      r'''(video_(?:alt_)?url\d*)\s*:\s*['"]([^'"]+)['"]''',
    ).allMatches(body)) {
      final raw = m.group(2)!;
      // License-obfuscated links ("function/0/...") are not supported.
      if (raw.startsWith('function/') || !raw.contains('/get_file/')) continue;
      final url = base.resolve(raw).toString();
      if (!seen.add(url)) continue;
      final text = RegExp(
        '${m.group(1)}_text'
        r'''\s*:\s*['"]([^'"]*)['"]''',
      ).firstMatch(body)?.group(1);
      links.add(
        DownloadLink(
          _label(text, url),
          url,
          false,
          null,
          false,
          'mp4',
          '$title.mp4',
        ),
      );
    }
    if (links.isEmpty) throw 'No download links on page';
    return withSizes(links, http);
  }
}

/// xhamster: the page embeds an HLS master whose name carries the codec
/// (`_TPL_.av1.mp4.m3u8`). The same master exists for `h264`, which every
/// player/merger handles, so that one is preferred.
class XhamsterExtractor extends SiteExtractor {
  @override
  String get id => 'xhamster';

  @override
  List<String> get hosts => const [
    'xhamster.com',
    'xhamster2.com',
    'xhamster3.com',
  ];

  @override
  String? videoId(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length == 2 && segs[0] == 'videos') return segs[1];
    return null;
  }

  @override
  Uri? _nextPage(Document doc, Uri page) {
    final m = RegExp(r'^(.*?)/(\d+)/?$').firstMatch(page.path);
    final path = m == null
        ? '${page.path.endsWith('/') ? page.path.substring(0, page.path.length - 1) : page.path}/2'
        : '${m.group(1)}/${int.parse(m.group(2)!) + 1}';
    return page.replace(path: path);
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final body = await http.getText(v.url);
    final title = pageTitle(body, v.title);
    final m = RegExp(r'''https:[^"'\\\s]+\.m3u8[^"'\\\s]*''')
        .firstMatch(body.replaceAll(r'\/', '/'));
    if (m == null) throw 'No download links on page';
    final master = m.group(0)!;
    final candidates = [
      master.replaceFirst('.av1.', '.h264.'),
      if (master.contains('.av1.')) master,
    ];
    for (final url in candidates) {
      try {
        final links = [
          for (final l in await hlsLinks(url, http))
            DownloadLink(
              l.quality,
              l.url,
              false,
              null,
              true,
              l.ext,
              '$title.${l.ext}',
            ),
        ];
        if (links.isNotEmpty) return links;
      } catch (_) {}
    }
    throw 'No download links on page';
  }
}

/// tnaflix: the player lists `<source src=... size="480">` mp4 links.
class TnaflixExtractor extends SiteExtractor {
  @override
  String get id => 'tnaflix';

  @override
  List<String> get hosts => const ['tnaflix.com'];

  @override
  String? videoId(Uri u) {
    final m = RegExp(r'/video(\d+)/?$').firstMatch(u.path);
    return m?.group(1);
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final body = await http.getText(v.url);
    final title = pageTitle(body, v.title);
    final base = Uri.parse(v.url);
    final links = <DownloadLink>[];
    final seen = <String>{};
    for (final s in html.parse(body).querySelectorAll('source[src]')) {
      final src = s.attributes['src'] ?? '';
      if (src.isEmpty || src.contains('/trailer')) continue;
      final url = base.resolve(src).toString();
      if (!seen.add(url)) continue;
      final q =
          int.tryParse(s.attributes['size'] ?? '') ??
          int.tryParse(
            RegExp(r'-(\d{3,4})p\.').firstMatch(url)?.group(1) ?? '',
          ) ??
          0;
      links.add(DownloadLink(q, url, false, null, false, 'mp4', '$title.mp4'));
    }
    if (links.isEmpty) throw 'No download links on page';
    return withSizes(links, http);
  }
}

/// pornone: `<video><source src label res>` mp4 links; video pages end in a
/// numeric id (`/<cat>/<slug>/<id>/`).
class PornoneExtractor extends SiteExtractor {
  @override
  String get id => 'pornone';

  @override
  List<String> get hosts => const ['pornone.com'];

  @override
  String? videoId(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length == 3 && RegExp(r'^\d{5,}$').hasMatch(segs[2])) {
      return segs[2];
    }
    return null;
  }

  @override
  Map<String, VideoItem> cards(Document doc, Uri page) {
    final out = <String, VideoItem>{};
    for (final a in doc.querySelectorAll('a.videocard[href]')) {
      final u = page.resolve(a.attributes['href']!.trim()).removeFragment();
      final id = matches(u) ? videoId(u) : null;
      if (id == null || out.containsKey(id)) continue;
      final img = a.querySelector('img.thumbimg');
      final title =
          (a.querySelector('.videotitle')?.text ?? img?.attributes['alt'] ?? '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      final raw = img?.attributes['src'];
      out[id] = _item(
        u,
        title: title,
        thumb: raw == null ? null : page.resolve(raw).toString(),
      );
    }
    return out;
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final body = await http.getText(v.url);
    final title = pageTitle(body, v.title);
    final base = Uri.parse(v.url);
    final links = <DownloadLink>[];
    final seen = <String>{};
    for (final s in html.parse(body).querySelectorAll('video source[src]')) {
      final src = s.attributes['src'] ?? '';
      if (!src.contains('.mp4')) continue;
      final url = base.resolve(src).toString();
      if (!seen.add(url)) continue;
      // The label can lie (720x406 tagged "480p"): prefer the res attribute.
      final q =
          int.tryParse(s.attributes['res'] ?? '') ??
          int.tryParse(
            (s.attributes['label'] ?? '').replaceAll(RegExp(r'\D'), ''),
          ) ??
          0;
      links.add(DownloadLink(q, url, false, null, false, 'mp4', '$title.mp4'));
    }
    if (links.isEmpty) throw 'No download links on page';
    return withSizes(links, http);
  }
}

/// hqporner: the video page embeds an `<iframe>` player (another host) whose
/// source lists one plain mp4 per quality (`.../360.mp4`, `720.mp4`, ...).
class HqpornerExtractor extends SiteExtractor {
  @override
  String get id => 'hqporner';

  @override
  List<String> get hosts => const ['hqporner.com'];

  @override
  String? videoId(Uri u) {
    final m = RegExp(r'^/hdporn/(\d+)-').firstMatch(u.path);
    return m?.group(1);
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final body = await http.getText(v.url);
    final title = pageTitle(
      body,
      v.title,
    ).replaceAll(RegExp(r'\s*-\s*HQporner\.com\s*$', caseSensitive: false), '');
    final src = RegExp(r'''<iframe[^>]+src=["']([^"']*/video/[^"']+)["']''')
        .firstMatch(body)
        ?.group(1);
    if (src == null) throw 'No player found on page';
    final player = Uri.parse(v.url).resolve(src).toString();
    final frame = await http.getText(player);
    final links = <DownloadLink>[];
    final seen = <int>{};
    for (final m in RegExp(
      r'''(?:https?:)?//[^"'\s<>\\]+?/(\d{3,4})\.mp4''',
    ).allMatches(frame)) {
      final q = int.parse(m.group(1)!);
      if (!seen.add(q)) continue;
      final url = Uri.parse(player).resolve(m.group(0)!).toString();
      links.add(DownloadLink(q, url, false, null, false, 'mp4', '$title.mp4'));
    }
    if (links.isEmpty) throw 'No download links on page';
    return withSizes(links, http);
  }
}
