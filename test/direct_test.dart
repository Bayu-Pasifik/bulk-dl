import 'package:bulk_dl/extractors/registry.dart';
import 'package:bulk_dl/models.dart';
import 'package:bulk_dl/naming.dart';
import 'package:bulk_dl/net/http.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http.dart';

void main() {
  group('naming', () {
    test('sanitize strips reserved chars and caps length', () {
      expect(sanitize('a/b:c*?"<>|d'), 'a_b_c______d');
      expect(sanitize('x' * 200).length, 80);
      expect(sanitize('   '), 'file');
      expect(sanitize('..hidden'), 'hidden');
    });

    test('extOf / stemOf', () {
      expect(extOf('a.b.MP4'), 'mp4');
      expect(extOf('noext'), '');
      expect(extOf('weird.toolongext'), '');
      expect(stemOf('a.b.mp4'), 'a.b');
    });

    test('Content-Disposition parsing', () {
      expect(nameFromDisposition('attachment; filename="A B.mp4"'), 'A B.mp4');
      expect(
        nameFromDisposition("attachment; filename*=UTF-8''A%20B.mp4"),
        'A B.mp4',
      );
      expect(
        nameFromDisposition('attachment; filename=plain.zip'),
        'plain.zip',
      );
      expect(nameFromDisposition(null), isNull);
    });

    test('numbered avoids collisions', () {
      expect(numbered('clip', 'mp4', 0), 'clip.mp4');
      expect(numbered('clip', 'mp4', 2), 'clip (2).mp4');
    });

    test('mime helpers', () {
      expect(mimeFor('MP4'), 'video/mp4');
      expect(mimeFor('xyz'), 'application/octet-stream');
      expect(extForMime('image/jpeg'), 'jpg');
      expect(isMediaType('text/html'), isFalse);
      expect(isMediaType('application/octet-stream'), isTrue);
    });

    test('stableId is deterministic', () {
      expect(stableId('https://a/b'), stableId('https://a/b'));
      expect(stableId('https://a/b'), isNot(stableId('https://a/c')));
    });
  });

  group('Registry.classify', () {
    final reg = Registry();

    test('rejects non-http links', () {
      expect(
        () => reg.classify('ftp://x/y', FakeHttp()),
        throwsA(isA<String>()),
      );
      expect(() => reg.classify('hello', FakeHttp()), throwsA(isA<String>()));
    });

    test('known extension is a file without any request', () async {
      final http = FakeHttp();
      final c = await reg.classify('https://h.test/a/clip.MP4?x=1', http);
      expect(c.kind, UrlKind.file);
      expect(c.extractor.id, 'direct');
      expect(http.calls, isEmpty);
    });

    test('octet-stream via HEAD is a file', () async {
      final http = FakeHttp(
        heads: {
          'https://h.test/dl?id=7': HeadInfo(
            url: 'https://h.test/dl?id=7',
            type: 'application/octet-stream',
          ),
        },
      );
      final c = await reg.classify('https://h.test/dl?id=7', http);
      expect(c.kind, UrlKind.file);
    });

    test('html page falls through to site extractors', () async {
      final http = FakeHttp(
        heads: {
          'https://h.test/p/': HeadInfo(
            url: 'https://h.test/p/',
            type: 'text/html',
          ),
        },
        pages: {'https://h.test/p/': '<a href="/video-a/x/">x</a>'},
      );
      final c = await reg.classify('https://h.test/p/', http);
      expect(c.kind, UrlKind.playlist);
      expect(c.extractor.id, 'eporner');
    });

    test('nothing recognisable throws', () async {
      final http = FakeHttp(
        heads: {
          'https://h.test/p/': HeadInfo(
            url: 'https://h.test/p/',
            type: 'text/html',
          ),
        },
        pages: {'https://h.test/p/': '<html>hi</html>'},
      );
      expect(
        () => reg.classify('https://h.test/p/', http),
        throwsA(isA<String>()),
      );
    });
  });

  group('DirectFileExtractor', () {
    final reg = Registry();
    test('single() builds a stable item', () async {
      final http = FakeHttp();
      final c = await reg.classify('https://h.test/a/My%20Clip.mp4', http);
      final v = reg.byId('direct').single(c.uri, http);
      expect(v.title, 'My Clip');
      expect(v.extractor, 'direct');
      expect(v.url, 'https://h.test/a/My%20Clip.mp4');
      expect(v.id, stableId(v.url));
    });

    test('resolve uses Content-Disposition and size', () async {
      final http = FakeHttp(
        heads: {
          'https://h.test/dl?id=7': HeadInfo(
            url: 'https://h.test/dl?id=7',
            type: 'application/octet-stream',
            length: 4 * 1048576,
            disposition: 'attachment; filename="Saved Name.mp4"',
            ranges: true,
          ),
        },
      );
      final ex = reg.byId('direct');
      final v = ex.single(Uri.parse('https://h.test/dl?id=7'), http);
      final l = (await ex.resolve(v, http)).single;
      expect(l.fileName, 'Saved Name.mp4');
      expect(l.ext, 'mp4');
      expect(l.mb, closeTo(4, 0.001));
      expect(l.hls, isFalse);
    });

    test('resolve rejects html and derives ext from mime', () async {
      final ex = reg.byId('direct');
      final http = FakeHttp(
        heads: {
          'https://h.test/page': HeadInfo(
            url: 'https://h.test/page',
            type: 'text/html',
          ),
          'https://h.test/blob': HeadInfo(
            url: 'https://h.test/blob',
            type: 'application/pdf',
          ),
        },
      );
      final p = ex.single(Uri.parse('https://h.test/page'), http);
      expect(() => ex.resolve(p, http), throwsA(isA<String>()));
      final b = ex.single(Uri.parse('https://h.test/blob'), http);
      expect((await ex.resolve(b, http)).single.fileName, 'blob.pdf');
    });

    test('m3u8 url resolves to an hls link', () async {
      final ex = reg.byId('direct');
      final http = FakeHttp(
        pages: {'https://h.test/s/index.m3u8': '#EXTM3U\n#EXTINF:4,\na.ts\n'},
      );
      final v = ex.single(Uri.parse('https://h.test/s/index.m3u8'), http);
      final l = (await ex.resolve(v, http)).single;
      expect(l.hls, isTrue);
    });
  });
}
