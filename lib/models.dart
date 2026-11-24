import 'dart:convert';

enum UrlKind { file, video, playlist }

class VideoItem {
  VideoItem({
    required this.id,
    required this.path,
    required this.origin,
    required this.title,
    this.thumb,
    this.extractor = 'eporner',
    String? url,
  }) : url = url ?? '$origin$path';
  final String id;
  final String path; // e.g. /video-xxx/slug/
  final String origin; // e.g. https://site.com (survives restarts)
  final String title;
  final String? thumb;

  /// Id of the extractor that created (and can resolve) this item.
  final String extractor;

  /// Full source URL (page or file) this item was created from.
  final String url;
}

class DownloadLink {
  DownloadLink(
    this.quality,
    this.url,
    this.av1, [
    this.mb,
    this.hls = false,
    this.ext = 'mp4',
    this.fileName,
  ]);

  /// Vertical resolution; 0 when unknown (direct files, generic pages).
  final int quality;
  final String url;
  final bool av1;
  final double? mb;

  /// HLS (`.m3u8`) playlist: downloaded segment by segment.
  final bool hls;
  final String ext;

  /// Server-suggested or URL-derived file name (with extension), if any.
  final String? fileName;
}

String formatSize(double mb) =>
    mb >= 1024 ? '${(mb / 1024).toStringAsFixed(2)} GB' : '${mb.round()} MB';

/// Stable (across runs) short id for a URL: FNV-1a 32 bit + length.
String stableId(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h = ((h ^ b) * 0x01000193) & 0xffffffff;
  }
  return '${h.toRadixString(16).padLeft(8, '0')}${s.length.toRadixString(16)}';
}
