import 'dart:typed_data';

import 'package:bulk_dl/scraper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves canned HTML by URL path; everything else is a 404.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.pages);
  final Map<String, String> pages;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    final body = pages[options.uri.path];
    if (body == null) return ResponseBody.fromString('nf', 404);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String card(String id, String slug, String title) =>
    '<div><a href="/video-$id/$slug/" title="$title"><img src="https://img/$id.jpg"></a></div>';

void main() {
  group('Scraper.fetchPlaylist', () {
    test('walks pages until no new videos and dedupes', () async {
      final adapter = FakeAdapter({
        '/playlist/': '<html>${card('a', 'one', 'One')}${card('b', 'two', 'Two')}</html>',
        '/playlist/2/': '<html>${card('b', 'two', 'Two')}${card('c', 'three', 'Three')}</html>',
        '/playlist/3/': '<html>${card('c', 'three', 'Three')}</html>',
      });
      final s = Scraper()..dio.httpClientAdapter = adapter;
      final items = await s.fetchPlaylist('https://site.test/playlist/');
      expect(items.map((e) => e.id), ['a', 'b', 'c']);
      expect(items.first.title, 'One');
      expect(items.first.origin, 'https://site.test');
      expect(items.first.thumb, 'https://img/a.jpg');
    });

    test('starting from page 2 url restarts at page 1', () async {
      final adapter = FakeAdapter({
        '/playlist/': '<html>${card('a', 'one', 'One')}</html>',
      });
      final s = Scraper()..dio.httpClientAdapter = adapter;
      final items = await s.fetchPlaylist('https://site.test/playlist/2/');
      expect(items.map((e) => e.id), ['a']);
    });

    test('empty first page throws', () async {
      final s = Scraper()
        ..dio.httpClientAdapter = FakeAdapter({'/p/': '<html></html>'});
      expect(() => s.fetchPlaylist('https://site.test/p/'), throwsA(isA<String>()));
    });
  });

  group('Scraper.fetchLinks', () {
    const page = '''
<html>
<a href="/dload/x/720/x-720p.mp4">Download MP4 (720p, 30.5 MB)</a>
<a href="/dload/x/1080/x-1080p-av1.mp4">Download AV1 (1080p, 1.5 GB)</a>
<a href="/dload/x/360/x-360p.mp4">Download MP4 (360p, 12 MB)</a>
</html>''';

    test('parses quality, codec and size', () async {
      final s = Scraper()
        ..dio.httpClientAdapter = FakeAdapter({'/video-x/slug/': page});
      final v = VideoItem(
        id: 'x',
        path: '/video-x/slug/',
        origin: 'https://site.test',
        title: 't',
      );
      final l = await s.fetchLinks(v);
      expect(l.map((e) => e.quality), [720, 1080, 360]);
      expect(l[1].av1, isTrue);
      expect(l[1].mb, closeTo(1536, 0.1));
      expect(l[0].url, 'https://site.test/dload/x/720/x-720p.mp4');
    });

    test('no links throws', () async {
      final s = Scraper()
        ..dio.httpClientAdapter = FakeAdapter({'/video-x/slug/': '<html/>'});
      final v = VideoItem(
        id: 'x',
        path: '/video-x/slug/',
        origin: 'https://site.test',
        title: 't',
      );
      expect(() => s.fetchLinks(v), throwsA(isA<String>()));
    });
  });

  group('Scraper.candidates / pick', () {
    final links = [
      DownloadLink(360, 'a', false),
      DownloadLink(720, 'b-av1', true),
      DownloadLink(720, 'b', false),
      DownloadLink(1080, 'c', false),
    ];

    test('best quality under cap, h264 before av1', () {
      expect(Scraper.candidates(links, 720).map((e) => e.url), ['b', 'b-av1', 'a']);
      expect(Scraper.pick(links, 720)!.url, 'b');
    });

    test('falls back to all links when none under cap', () {
      final only = [DownloadLink(1080, 'c', false)];
      expect(Scraper.candidates(only, 360).single.url, 'c');
    });
  });

  test('formatSize', () {
    expect(formatSize(30), '30 MB');
    expect(formatSize(2048), '2.00 GB');
  });

}
