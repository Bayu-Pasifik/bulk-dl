import '../models.dart';
import '../naming.dart';
import '../net/http.dart';
import 'extractor.dart';

/// A URL that points straight at a file (media, archive, document, HLS).
class DirectFileExtractor implements Extractor {
  @override
  String get id => 'direct';

  static bool _isHlsUrl(Uri u) => u.path.toLowerCase().endsWith('.m3u8');

  @override
  Future<UrlKind?> classify(Uri u, Http http) async {
    final ext = extOf(u.path);
    if (mediaExts.contains(ext) || _isHlsUrl(u)) return UrlKind.file;
    try {
      final h = await http.head(u.toString());
      if (isMediaType(h.type)) return UrlKind.file;
    } catch (_) {}
    return null;
  }

  @override
  VideoItem single(Uri u, Http http) {
    final name = nameFromUrl(u) ?? u.host;
    return VideoItem(
      id: stableId(u.toString()),
      path: '${u.path}${u.hasQuery ? '?${u.query}' : ''}',
      origin: '${u.scheme}://${u.authority}',
      title: stemOf(name),
      extractor: id,
      url: u.toString(),
    );
  }

  @override
  Future<List<VideoItem>> listPlaylist(
    Uri u,
    Http http, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  }) async => [single(u, http)];

  @override
  Future<List<DownloadLink>> resolve(VideoItem v, Http http) async {
    final u = Uri.parse(v.url);
    if (_isHlsUrl(u)) {
      return [DownloadLink(0, v.url, false, null, true, 'ts', null)];
    }
    final h = await http.head(v.url);
    if (isHlsType(h.type)) {
      return [DownloadLink(0, h.url, false, null, true, 'ts', null)];
    }
    if (h.type != null && h.type!.contains('html')) {
      throw 'Link returned a web page, not a file';
    }
    final fu = Uri.tryParse(h.url) ?? u;
    var name = nameFromDisposition(h.disposition) ?? nameFromUrl(fu) ?? v.title;
    var ext = extOf(name);
    if (ext.isEmpty) {
      ext = extForMime(h.type) ?? 'bin';
      name = '$name.$ext';
    }
    final mb = h.length == null ? null : h.length! / 1048576;
    return [DownloadLink(0, h.url, false, mb, false, ext, name)];
  }
}
