import 'models.dart';

/// Extensions the app treats as downloadable files.
const mediaExts = <String>{
  'mp4', 'mkv', 'webm', 'mov', 'm4v', 'avi', 'flv', 'wmv', '3gp', 'ts', //
  'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac', //
  'jpg', 'jpeg', 'png', 'gif', 'webp', //
  'pdf', 'zip', 'rar', '7z', 'apk',
};

const _mimes = <String, String>{
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'flv': 'video/x-flv',
  'wmv': 'video/x-ms-wmv',
  '3gp': 'video/3gpp',
  'ts': 'video/mp2t',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'opus': 'audio/opus',
  'wav': 'audio/wav',
  'flac': 'audio/flac',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
  'zip': 'application/zip',
  'rar': 'application/vnd.rar',
  '7z': 'application/x-7z-compressed',
  'apk': 'application/vnd.android.package-archive',
};

String mimeFor(String ext) =>
    _mimes[ext.toLowerCase()] ?? 'application/octet-stream';

/// Extension for a response `Content-Type`, or null if unknown.
String? extForMime(String? type) {
  if (type == null) return null;
  final t = type.toLowerCase();
  if (t == 'audio/mpeg') return 'mp3';
  if (t == 'image/jpeg') return 'jpg';
  if (t == 'video/mp4') return 'mp4';
  for (final e in _mimes.entries) {
    if (e.value == t) return e.key;
  }
  return null;
}

bool isMediaType(String? type) {
  if (type == null) return false;
  final t = type.toLowerCase();
  return t.startsWith('video/') ||
      t.startsWith('audio/') ||
      t.startsWith('image/') ||
      t == 'application/octet-stream' ||
      t == 'binary/octet-stream' ||
      t == 'application/pdf' ||
      t == 'application/zip' ||
      t == 'application/x-mpegurl' ||
      t == 'application/vnd.apple.mpegurl' ||
      _mimes.containsValue(t);
}

bool isHlsType(String? type) {
  final t = type?.toLowerCase() ?? '';
  return t == 'application/vnd.apple.mpegurl' ||
      t == 'application/x-mpegurl' ||
      t == 'audio/mpegurl' ||
      t == 'audio/x-mpegurl';
}

/// Unicode-safe, length-capped name part with no path/reserved characters.
String sanitize(String s, {int max = 80}) {
  var t = s.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  t = t.replaceAll(RegExp(r'^\.+'), '');
  final runes = t.runes.toList();
  if (runes.length > max) t = String.fromCharCodes(runes.take(max));
  return t.isEmpty ? 'file' : t;
}

/// Extension (lower-case, no dot) of [name], or '' if none.
String extOf(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0 || i == name.length - 1) return '';
  final e = name.substring(i + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(e) ? e : '';
}

String stemOf(String name) {
  final e = extOf(name);
  return e.isEmpty ? name : name.substring(0, name.length - e.length - 1);
}

/// File name from a `Content-Disposition` header, if present.
String? nameFromDisposition(String? cd) {
  if (cd == null) return null;
  final star = RegExp(
    r"filename\*\s*=\s*[^']*'[^']*'([^;]+)",
    caseSensitive: false,
  ).firstMatch(cd);
  if (star != null) {
    try {
      return Uri.decodeComponent(star.group(1)!.trim());
    } catch (_) {}
  }
  final q = RegExp(
    r'filename\s*=\s*"([^"]+)"',
    caseSensitive: false,
  ).firstMatch(cd);
  if (q != null) return q.group(1)!.trim();
  final p = RegExp(
    r'filename\s*=\s*([^;]+)',
    caseSensitive: false,
  ).firstMatch(cd);
  return p?.group(1)!.trim();
}

/// Last path segment of [u], percent-decoded (null when empty).
String? nameFromUrl(Uri u) {
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return null;
  try {
    return Uri.decodeComponent(segs.last);
  } catch (_) {
    return segs.last;
  }
}

/// Legacy (Eporner) name: `title_720p_id.mp4`; the id keeps it unique.
String legacyName(VideoItem v, int quality) =>
    '${sanitize(v.title)}_${quality}p_${v.id}.mp4';

/// `name.ext`, or `name (n).ext` for n > 0.
String numbered(String stem, String ext, int n) =>
    '${n == 0 ? stem : '$stem ($n)'}${ext.isEmpty ? '' : '.$ext'}';
