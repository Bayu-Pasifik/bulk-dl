import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

import 'models.dart';
import 'net/http.dart';

class HlsVariant {
  HlsVariant(this.url, this.bandwidth, this.height);
  final String url;
  final int bandwidth;
  final int height;
}

class HlsSegment {
  HlsSegment(this.url, this.seq, {this.keyUrl, this.iv});
  final String url;
  final int seq;

  /// AES-128 key url (null = clear) and explicit IV bytes (null = from [seq]).
  final String? keyUrl;
  final Uint8List? iv;
}

class HlsMedia {
  HlsMedia(this.segments, this.initUrl);
  final List<HlsSegment> segments;

  /// fMP4 init segment (`EXT-X-MAP`), null for MPEG-TS.
  final String? initUrl;
}

class HlsException implements Exception {
  HlsException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _abs(Uri base, String ref) => base.resolve(ref.trim()).toString();

Map<String, String> _attrs(String line) {
  final out = <String, String>{};
  final i = line.indexOf(':');
  final s = i < 0 ? '' : line.substring(i + 1);
  for (final m in RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(s)) {
    var v = m.group(2)!;
    if (v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
    out[m.group(1)!] = v;
  }
  return out;
}

/// Variants of a master playlist; empty when [text] is a media playlist.
List<HlsVariant> parseMaster(String text, Uri base) {
  final lines = text.split(RegExp(r'\r?\n'));
  final out = <HlsVariant>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trim();
    if (!l.startsWith('#EXT-X-STREAM-INF')) continue;
    final a = _attrs(l);
    var j = i + 1;
    while (j < lines.length &&
        (lines[j].trim().isEmpty || lines[j].trim().startsWith('#'))) {
      j++;
    }
    if (j >= lines.length) break;
    final res = a['RESOLUTION'] ?? '';
    final h = int.tryParse(res.split('x').last) ?? 0;
    out.add(
      HlsVariant(
        _abs(base, lines[j]),
        int.tryParse(a['BANDWIDTH'] ?? '') ?? 0,
        h,
      ),
    );
  }
  return out;
}

Uint8List _ivFromHex(String hex) {
  var h = hex.toLowerCase().replaceFirst('0x', '');
  h = h.padLeft(32, '0');
  return Uint8List.fromList([
    for (var i = 0; i < 32; i += 2) int.parse(h.substring(i, i + 2), radix: 16),
  ]);
}

Uint8List _ivFromSeq(int seq) {
  final b = Uint8List(16);
  for (var i = 0; i < 8; i++) {
    b[15 - i] = (seq >> (8 * i)) & 0xff;
  }
  return b;
}

/// Parses a media playlist. Throws [HlsException] for DRM-protected streams.
HlsMedia parseMedia(String text, Uri base) {
  final segs = <HlsSegment>[];
  String? init;
  String? keyUrl;
  Uint8List? iv;
  var seq = 0;
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final l = raw.trim();
    if (l.isEmpty) continue;
    if (l.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
      seq = int.tryParse(l.substring(22)) ?? 0;
    } else if (l.startsWith('#EXT-X-MAP:')) {
      final u = _attrs(l)['URI'];
      if (u != null) init = _abs(base, u);
    } else if (l.startsWith('#EXT-X-KEY:')) {
      final a = _attrs(l);
      final m = (a['METHOD'] ?? 'NONE').toUpperCase();
      final fmt = (a['KEYFORMAT'] ?? 'identity').toLowerCase();
      if (m == 'NONE') {
        keyUrl = null;
        iv = null;
      } else if (m == 'AES-128' && fmt == 'identity' && a['URI'] != null) {
        keyUrl = _abs(base, a['URI']!);
        iv = a['IV'] == null ? null : _ivFromHex(a['IV']!);
      } else {
        throw HlsException('Stream is DRM-protected (cannot be downloaded)');
      }
    } else if (!l.startsWith('#')) {
      segs.add(HlsSegment(_abs(base, l), seq, keyUrl: keyUrl, iv: iv));
      seq++;
    }
  }
  if (segs.isEmpty) throw HlsException('Empty HLS playlist');
  return HlsMedia(segs, init);
}

/// Download options for an `.m3u8` url: one link per variant of a master
/// playlist, or a single link for a media playlist.
Future<List<DownloadLink>> hlsLinks(String url, Http http) async {
  final text = await http.getText(url);
  if (!text.trimLeft().startsWith('#EXTM3U')) {
    throw 'Not a valid HLS playlist';
  }
  final base = Uri.parse(url);
  final variants = parseMaster(text, base);
  if (variants.isEmpty) {
    final m = parseMedia(text, base); // validates / detects DRM
    return [
      DownloadLink(0, url, false, null, true, m.initUrl == null ? 'ts' : 'mp4'),
    ];
  }
  return [
    for (final v in variants)
      DownloadLink(v.height, v.url, false, null, true, 'ts'),
  ];
}

Uint8List _decrypt(Uint8List data, Uint8List key, Uint8List iv) {
  final c = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
    ..init(
      false,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      ),
    );
  return c.process(data);
}

/// Downloads a media playlist's segments into [out] (concatenated).
/// Returns the container extension (`mp4` with init segment, else `ts`).
Future<String> downloadHls(
  Dio dio,
  String playlistUrl,
  File out, {
  CancelToken? token,
  void Function(int done, int total, int bytes)? onProgress,
  int parallel = 16,
}) async {
  final text =
      (await dio.get<String>(
        playlistUrl,
        cancelToken: token,
        options: Options(responseType: ResponseType.plain),
      )).data ??
      '';
  final media = parseMedia(text, Uri.parse(playlistUrl));
  final keys = <String, Uint8List>{};

  Future<Uint8List> fetch(String url) async {
    Object? last;
    for (var i = 0; i < 6; i++) {
      try {
        final r = await dio.get<List<int>>(
          url,
          cancelToken: token,
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(r.data!);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        last = e;
        final busy = e.response?.statusCode == 429;
        await Future<void>.delayed(
          Duration(milliseconds: (busy ? 2000 : 400) * (i + 1)),
        );
      }
    }
    throw last!;
  }

  Future<Uint8List> segment(HlsSegment s) async {
    var data = await fetch(s.url);
    if (s.keyUrl != null) {
      final key = keys[s.keyUrl!] ??= await fetch(s.keyUrl!);
      data = _decrypt(data, key, s.iv ?? _ivFromSeq(s.seq));
    }
    return data;
  }

  if (await out.exists()) await out.delete();
  final sink = out.openWrite();
  var bytes = 0;
  try {
    if (media.initUrl != null) {
      final d = await fetch(media.initUrl!);
      sink.add(d);
      bytes += d.length;
    }
    final total = media.segments.length;
    // Sliding window: keep [parallel] segments in flight, write in order.
    final inflight = <Future<Uint8List>>[];
    var started = 0;
    void fill() {
      while (started < total && inflight.length < parallel) {
        final f = segment(media.segments[started++]);
        f.ignore(); // errors surface when awaited in order
        inflight.add(f);
      }
    }

    fill();
    for (var i = 0; i < total; i++) {
      final p = await inflight.removeAt(0);
      fill();
      sink.add(p);
      bytes += p.length;
      onProgress?.call(i + 1, total, bytes);
    }
  } finally {
    await sink.close();
  }
  return media.initUrl == null ? 'ts' : 'mp4';
}
