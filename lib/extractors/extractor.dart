import '../models.dart';
import '../net/http.dart';

abstract class Extractor {
  /// Stable id persisted with each queued item.
  String get id;

  /// Decide what [u] is, or return null when this extractor does not handle it.
  Future<UrlKind?> classify(Uri u, Http http);

  /// Item for a single file/video [u] (kind `file` or `video`).
  VideoItem single(Uri u, Http http);

  /// All videos behind a playlist URL.
  Future<List<VideoItem>> listPlaylist(
    Uri u,
    Http http, {
    void Function(int count)? onProgress,
    int maxPages = 100,
  });

  /// Download options (qualities) for [v].
  Future<List<DownloadLink>> resolve(VideoItem v, Http http);
}
