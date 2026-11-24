import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../hls.dart';
import '../models.dart';
import '../naming.dart';
import '../net/http.dart';
import 'extractor.dart';

const _videoExts = {'mp4', 'webm', 'mkv', 'mov', 'm4v'};

class _Src {
  _Src(this.url, this.quality);
  final String url;
  final int quality;
  bool get hls => Uri.tryParse(url)?.path.toLowerCase().endsWith('.m3u8') ?? false;
}

int _qualityOf(String s) {
  final m = RegExp(r'(\d{3,4})\s*p\b', caseSensitive: false).firstMatch(s) ??
      RegExp(r'^\s*(\d{3,4})\s*$').firstMatch(s);
  return m == null ? 0 : int.parse(m.group(1)!);
}

/// Fallback for arbitrary sites: finds media in the page markup.
class GenericHtmlExtractor implements Extractor {
  @override
  String get id => 'generic';

  @override
  Future<UrlKind?> classify(Uri u, Http http) async {
    final body = await http.getText(u.toString());
    final doc = html.parse(body);
    if (_sources(doc, body, u).isNotEmpty) return UrlKind.video;
    if (_cards(doc, u).length >= 3) return UrlKind.playlist;
    return null;
  }

  @override
  VideoItem single(Uri u, Http http) {
    final name = nameFromUrl(u) ?? u.host;
    return VideoItem(
      id: stableId(u.toString()),
      path: '${u.path}${u.hasQuery ? '?${u.query}' : ''}',
      origin: '${u.scheme}://${u.authority}',
      title: stemOf(name).replaceAll(RegExp(r'[-_]+'), ' '),
      extractor: id,
      url: u.toString(),
    );
  }

  String _title(Document doc, String fallback) {
    final og = doc.querySelector('meta[property="og:title"]')?.attributes['content'];
    final t = (og ?? doc.querySelector('title')?.text ?? '').trim();
    return t.isEmpty ? fallback : t;
  }

  // --- single video page ------------------------------------------------

  List<_Src> _sources(Document doc, String body, Uri base) {
    final out = <String, _Src>{};
    void add(String? raw, [int q = 0]) {
      if (raw == null) return;
      raw = raw.trim().replaceAll(r'\/', '/').replaceAll('&amp;', '&');
      if (raw.isEmpty || raw.startsWith('blob:') || raw.startsWith('data:')) return;
      final u = base.resolve(raw);
      if (u.scheme != 'http' && u.scheme != 'https') return;
      final s = u.toString();
      out.putIfAbsent(s, () => _Src(s, q != 0 ? q : _qualityOf(u.path)));
    }

    bool known(String s) {
      final p = (Uri.tryParse(s)?.path ?? '').toLowerCase();
      return _videoExts.contains(extOf(p)) || p.endsWith('.m3u8');
    }

    for (final sel in [
      'meta[property="og:video"]',
      'meta[property="og:video:url"]',
      'meta[property="og:video:secure_url"]',
      'meta[name="twitter:player:stream"]',
    ]) {
      for (final m in doc.querySelectorAll(sel)) {
        final c = m.attributes['content'];
        if (c != null && known(c)) add(c);
      }
    }
    for (final v in doc.querySelectorAll('video')) {
      add(v.attributes['src']);
      for (final s in v.querySelectorAll('source')) {
        final label = [
          s.attributes['res'],
          s.attributes['label'],
          s.attributes['size'],
          s.attributes['data-res'],
          s.attributes['title'],
        ].whereType<String>().join(' ');
        add(s.attributes['src'], _qualityOf(label));
      }
    }
    for (final s in doc.querySelectorAll('script[type="application/ld+json"]')) {
      try {
        _walkLd(jsonDecode(s.text), (u) => add(u));
      } catch (_) {}
    }
    for (final a in doc.querySelectorAll('a[href]')) {
      final h = a.attributes['href']!;
      if (known(h)) add(h);
    }
    final text = body.replaceAll(r'\/', '/');
    for (final m in RegExp(
      r'''https?://[^"'\s<>\\)]+?\.(?:mp4|m3u8|webm|mkv)(?:\?[^"'\s<>\\)]*)?''',
      caseSensitive: false,
    ).allMatches(text)) {
      add(m.group(0));
    }
    return out.values.toList();
  }

  void _walkLd(dynamic n, void Function(String) add) {
    if (n is List) {
      for (final e in n) {
        _walkLd(e, add);
      }
    } else if (n is Map) {
      final c = n['contentUrl'];
      if (c is String) add(c);
      for (final v in n.values) {
        if (v is Map || v is List) _walkLd(v, add);
      }
    }
  }

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final base = Uri.parse(v.url);
    final body = await http.getText(v.url);
    final doc = html.parse(body);
    final srcs = _sources(doc, body, base);
    if (srcs.isEmpty) {
      throw 'No downloadable media found on this page';
    }
    final title = sanitize(_title(doc, v.title));
    final links = <DownloadLink>[];
    final plain = <_Src>[];
    for (final s in srcs) {
      if (s.hls) {
        try {
          for (final l in await hlsLinks(s.url, http)) {
            links.add(
              DownloadLink(l.quality, l.url, false, null, true, l.ext, '$title.${l.ext}'),
            );
          }
        } catch (_) {}
      } else {
        plain.add(s);
      }
    }
    // Size/type of each plain source (drops previews, error pages).
    final heads = await Future.wait(
      plain.map((s) async {
        try {
          return await http.head(s.url);
        } catch (_) {
          return null;
        }
      }),
    );
    final found = <DownloadLink>[];
    for (var i = 0; i < plain.length; i++) {
      final h = heads[i];
      if (h != null && h.type != null && h.type!.contains('html')) continue;
      final path = Uri.tryParse(h?.url ?? plain[i].url)?.path ?? '';
      var ext = extOf(path);
      if (ext.isEmpty) ext = extForMime(h?.type) ?? 'mp4';
      final mb = h?.length == null ? null : h!.length! / 1048576;
      found.add(
        DownloadLink(plain[i].quality, h?.url ?? plain[i].url, false, mb, false, ext, '$title.$ext'),
      );
    }
    final big = found.where((l) => (l.mb ?? 1) >= 0.1).toList();
    links.addAll(big.isEmpty ? found : big);
    if (links.isEmpty) throw 'No downloadable media found on this page';
    return links;
  }

  // --- playlist pages -----------------------------------------------------

  List<VideoItem> _cards(Document doc, Uri page) {
    final seen = <String>{};
    final out = <VideoItem>[];
    for (final a in doc.querySelectorAll('a[href]')) {
      final img = a.querySelector('img');
      if (img == null) continue;
      final h = a.attributes['href']!.trim();
      if (h.isEmpty || h.startsWith('#') || h.startsWith('javascript:')) continue;
      final u = page.resolve(h).removeFragment();
      if (u.scheme != 'http' && u.scheme != 'https') continue;
      if (u.path == '/' || u.path.isEmpty) continue;
      if (u.toString() == page.removeFragment().toString()) continue;
      if (!seen.add(u.toString())) continue;
      final isFile = mediaExts.contains(extOf(u.path));
      final raw = (a.attributes['title'] ?? img.attributes['alt'] ?? a.text).trim();
      final slug = (nameFromUrl(u) ?? u.host);
      final thumbSrc = img.attributes['data-src'] ?? img.attributes['src'];
      final thumb = thumbSrc == null ? null : page.resolve(thumbSrc).toString();
      out.add(
        VideoItem(
          id: stableId(u.toString()),
          path: '${u.path}${u.hasQuery ? '?${u.query}' : ''}',
          origin: '${u.scheme}://${u.authority}',
          title: raw.isNotEmpty
              ? raw.replaceAll(RegExp(r'\s+'), ' ')
              : stemOf(slug).replaceAll(RegExp(r'[-_]+'), ' '),
          thumb: (thumb != null && thumb.startsWith('http')) ? thumb : null,
          extractor: isFile ? 'direct' : id,
          url: u.toString(),
        ),
      );
    }
    return out;
  }

  @override
  Future<List<VideoItem>> listPlaylist(
    Uri u,
    Http http, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  }) async {
    final all = <String, VideoItem>{};
    Uri? next = u;
    final visited = <String>{};
    for (var page = 0; page < maxPages && next != null; page++) {
      if (!visited.add(next.toString())) break;
      String body;
      try {
        body = await http.getText(next.toString());
      } catch (_) {
        if (page == 0) rethrow;
        break;
      }
      final doc = html.parse(body);
      final before = all.length;
      for (final c in _cards(doc, next)) {
        all.putIfAbsent(c.id, () => c);
      }
      onProgress?.call(all.length);
      if (page == 0 && all.isEmpty) throw 'No videos found at this link';
      if (all.length == before) break;
      final rel = doc.querySelector('a[rel="next"], link[rel="next"]');
      final href = rel?.attributes['href'];
      next = href == null ? null : next.resolve(href);
    }
    return all.values.toList();
  }
}
