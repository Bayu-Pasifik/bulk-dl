import 'dart:io';
import 'dart:typed_data';

import 'package:bulk_dl/extractors/registry.dart';
import 'package:bulk_dl/hls.dart';
import 'package:bulk_dl/models.dart';
import 'package:bulk_dl/net/http.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

import 'fake_http.dart';

HeadInfo html(String u) => HeadInfo(url: u, type: 'text/html');

class BytesAdapter implements HttpClientAdapter {
  BytesAdapter(this.files);
  final Map<String, Uint8List> files;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final b = files[o.uri.toString()];
    if (b == null) return ResponseBody.fromString('nf', 404);
    return ResponseBody.fromBytes(b, 200);
  }

  @override
  void close({bool force = false}) {}
}

Uint8List encrypt(Uint8List data, Uint8List key, Uint8List iv) {
  final c = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
    ..init(
      true,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      ),
    );
  return c.process(data);
}

void main() {
  group('HLS parsing', () {
    test('master playlist variants', () {
      const m = '''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
/abs/hi.m3u8
''';
      final v = parseMaster(m, Uri.parse('https://h.test/a/master.m3u8'));
      expect(v.map((e) => e.height), [360, 720]);
      expect(v[0].url, 'https://h.test/a/low.m3u8');
      expect(v[1].url, 'https://h.test/abs/hi.m3u8');
      expect(
        parseMaster(
          '#EXTM3U\n#EXTINF:4,\nx.ts\n',
          Uri.parse('https://h.test/'),
        ),
        isEmpty,
      );
    });

    test('media playlist: sequence, key, iv, map', () {
      const m = '''#EXTM3U
#EXT-X-MEDIA-SEQUENCE:7
#EXT-X-MAP:URI="init.mp4"
#EXT-X-KEY:METHOD=AES-128,URI="k.bin"
#EXTINF:4,
a.m4s
#EXT-X-KEY:METHOD=NONE
#EXTINF:4,
b.m4s
''';
      final p = parseMedia(m, Uri.parse('https://h.test/v/p.m3u8'));
      expect(p.initUrl, 'https://h.test/v/init.mp4');
      expect(p.segments.length, 2);
      expect(p.segments[0].seq, 7);
      expect(p.segments[0].keyUrl, 'https://h.test/v/k.bin');
      expect(p.segments[1].keyUrl, isNull);
    });

    test('SAMPLE-AES / non-identity key is DRM and rejected', () {
      const m =
          '#EXTM3U\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI="skd://x",KEYFORMAT="com.apple.streamingkeydelivery"\n#EXTINF:4,\na.ts\n';
      expect(
        () => parseMedia(m, Uri.parse('https://h.test/p.m3u8')),
        throwsA(isA<HlsException>()),
      );
    });

    test('hlsLinks: one link per variant, or one for a media list', () async {
      final http = FakeHttp(
        pages: {
          'https://h.test/m.m3u8': '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=640x360\na.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=2,RESOLUTION=1280x720\nb.m3u8\n',
          'https://h.test/p.m3u8': '#EXTM3U\n#EXTINF:4,\na.ts\n',
        },
      );
      final l = await hlsLinks('https://h.test/m.m3u8', http);
      expect(l.map((e) => e.quality), [360, 720]);
      expect(l.every((e) => e.hls), isTrue);
      final one = await hlsLinks('https://h.test/p.m3u8', http);
      expect(one.single.quality, 0);
      expect(one.single.ext, 'ts');
    });
  });

  group('downloadHls', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('hls_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('joins clear segments in order', () async {
      final dio = Dio()
        ..httpClientAdapter = BytesAdapter({
          'https://h.test/p.m3u8': Uint8List.fromList(
            '#EXTM3U\n#EXTINF:4,\n1.ts\n#EXTINF:4,\n2.ts\n#EXTINF:4,\n3.ts\n#EXTINF:4,\n4.ts\n'
                .codeUnits,
          ),
          'https://h.test/1.ts': Uint8List.fromList([1, 1]),
          'https://h.test/2.ts': Uint8List.fromList([2, 2]),
          'https://h.test/3.ts': Uint8List.fromList([3, 3]),
          'https://h.test/4.ts': Uint8List.fromList([4, 4]),
        });
      final out = File('${tmp.path}/o.part');
      final progress = <int>[];
      final ext = await downloadHls(
        dio,
        'https://h.test/p.m3u8',
        out,
        onProgress: (d, t, b) => progress.add(d),
      );
      expect(ext, 'ts');
      expect(out.readAsBytesSync(), [1, 1, 2, 2, 3, 3, 4, 4]);
      expect(progress.last, 4);
    });

    test('decrypts AES-128 (explicit IV) and keeps init segment', () async {
      final key = Uint8List.fromList(List.generate(16, (i) => i));
      final iv = Uint8List.fromList(List.generate(16, (i) => 16 - i));
      final plain = Uint8List.fromList(List.generate(100, (i) => i));
      final ivHex = iv.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final dio = Dio()
        ..httpClientAdapter = BytesAdapter({
          'https://h.test/p.m3u8': Uint8List.fromList(
            '#EXTM3U\n#EXT-X-MAP:URI="init.mp4"\n#EXT-X-KEY:METHOD=AES-128,URI="k.bin",IV=0x$ivHex\n#EXTINF:4,\ns.m4s\n'
                .codeUnits,
          ),
          'https://h.test/init.mp4': Uint8List.fromList([9, 9]),
          'https://h.test/k.bin': key,
          'https://h.test/s.m4s': encrypt(plain, key, iv),
        });
      final out = File('${tmp.path}/o.part');
      final ext = await downloadHls(dio, 'https://h.test/p.m3u8', out);
      expect(ext, 'mp4');
      expect(out.readAsBytesSync(), [9, 9, ...plain]);
    });

    test('cancel stops the download', () async {
      final dio = Dio()
        ..httpClientAdapter = BytesAdapter({
          'https://h.test/p.m3u8': Uint8List.fromList(
            '#EXTM3U\n#EXTINF:4,\n1.ts\n'.codeUnits,
          ),
          'https://h.test/1.ts': Uint8List.fromList([1]),
        });
      final token = CancelToken()..cancel('x');
      expect(
        () => downloadHls(
          dio,
          'https://h.test/p.m3u8',
          File('${tmp.path}/o'),
          token: token,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('GenericHtmlExtractor', () {
    final reg = Registry();
    const page = '''<html><head><title>My Page</title>
<meta property="og:video" content="https://cdn.test/og.mp4"></head><body>
<video><source src="/v/720.mp4" res="720"><source src="/v/prev.mp4" label="360p"></video>
<script>var cfg = {"file":"https:\\/\\/cdn.test\\/s\\/index.m3u8"};</script>
</body></html>''';

    Map<String, HeadInfo> heads() => {
      'https://s.test/page': html('https://s.test/page'),
      'https://cdn.test/og.mp4': HeadInfo(
        url: 'https://cdn.test/og.mp4',
        type: 'video/mp4',
        length: 5 * 1048576,
      ),
      'https://s.test/v/720.mp4': HeadInfo(
        url: 'https://s.test/v/720.mp4',
        type: 'video/mp4',
        length: 40 * 1048576,
      ),
      'https://s.test/v/prev.mp4': HeadInfo(
        url: 'https://s.test/v/prev.mp4',
        type: 'video/mp4',
        length: 20 * 1024,
      ),
    };

    test('classifies a page with media as video', () async {
      final http = FakeHttp(
        pages: {'https://s.test/page': page},
        heads: heads(),
      );
      final c = await reg.classify('https://s.test/page', http);
      expect(c.kind, UrlKind.video);
      expect(c.extractor.id, 'generic');
    });

    test(
      'resolve collects sources, drops tiny previews, titles the file',
      () async {
        final http = FakeHttp(
          pages: {
            'https://s.test/page': page,
            'https://cdn.test/s/index.m3u8': '#EXTM3U\n#EXTINF:4,\na.ts\n',
          },
          heads: heads(),
        );
        final ex = reg.byId('generic');
        final v = ex.single(Uri.parse('https://s.test/page'), http);
        final l = await ex.resolve(v, http);
        final urls = l.map((e) => e.url).toList();
        expect(urls, contains('https://s.test/v/720.mp4'));
        expect(urls, contains('https://cdn.test/og.mp4'));
        expect(urls, contains('https://cdn.test/s/index.m3u8'));
        expect(urls, isNot(contains('https://s.test/v/prev.mp4')));
        final best = l.firstWhere((e) => e.url.endsWith('720.mp4'));
        expect(best.quality, 720);
        expect(best.fileName, 'My Page.mp4');
        expect(l.firstWhere((e) => e.hls).ext, 'ts');
      },
    );

    test('page without media or cards is not recognised', () async {
      final http = FakeHttp(
        pages: {'https://s.test/x': '<html><a href="/a">a</a></html>'},
        heads: {'https://s.test/x': html('https://s.test/x')},
      );
      expect(
        () => reg.classify('https://s.test/x', http),
        throwsA(isA<String>()),
      );
    });

    test('card grid is a playlist; next link is followed', () async {
      String grid(List<int> ids, String? next) =>
          '<html>${next == null ? '' : '<a rel="next" href="$next">n</a>'}${ids.map((i) => '<a href="/w/$i"><img src="/t/$i.jpg" alt="Item $i"></a>').join()}</html>';
      final http = FakeHttp(
        pages: {
          'https://s.test/list': grid([1, 2, 3], '/list2'),
          'https://s.test/list2': grid([3, 4], null),
        },
        heads: {'https://s.test/list': html('https://s.test/list')},
      );
      final c = await reg.classify('https://s.test/list', http);
      expect(c.kind, UrlKind.playlist);
      final items = await c.extractor.listPlaylist(c.uri, http);
      expect(items.map((e) => e.title), [
        'Item 1',
        'Item 2',
        'Item 3',
        'Item 4',
      ]);
      expect(items.first.url, 'https://s.test/w/1');
      expect(items.first.thumb, 'https://s.test/t/1.jpg');
      expect(items.first.extractor, 'generic');
    });
  });
}
