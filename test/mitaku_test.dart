import 'package:bulk_dl/extractors/registry.dart';
import 'package:bulk_dl/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http.dart';

String _post(List<String> imgs) =>
    '<div class="entry-content">${imgs.map((u) => '<a class="msacwl-img-link" href="javascript:void(0);" data-mfp-src="$u"></a>').join()}</div>';

String _list(List<String> posts) =>
    '<main>${posts.map((p) => '<article><h2 class="entry-title"><a href="$p">t</a></h2></article>').join()}</main>';

void main() {
  embedTests();
  final reg = Registry();
  const up = 'https://mitaku.net/wp-content/uploads/2026/11';

  test('post page lists its images', () async {
    final http = FakeHttp(
      pages: {
        'https://mitaku.net/ero-cosplay/a/': _post([
          '$up/A-1.jpg',
          '$up/A-2.jpg',
        ]),
      },
    );
    final k = await reg.classify('https://mitaku.net/ero-cosplay/a/', http);
    expect(k.extractor.id, 'mitaku');
    expect(k.kind, UrlKind.playlist);
    final items = await k.extractor.listPlaylist(k.uri, http);
    expect(items.map((e) => e.url), ['$up/A-1.jpg', '$up/A-2.jpg']);
    expect(items.first.title, 'A-1');
  });

  test('listing walks pages and flattens post images', () async {
    final http = FakeHttp(
      pages: {
        'https://mitaku.net/': _list(['https://mitaku.net/x/a/']),
        'https://mitaku.net/page/2/': _list(['https://mitaku.net/x/b/']),
        'https://mitaku.net/x/a/': _post(['$up/A-1.jpg']),
        'https://mitaku.net/x/b/': _post(['$up/B-1.jpg']),
      },
    );
    final k = await reg.classify('https://mitaku.net/', http);
    final items = await k.extractor.listPlaylist(k.uri, http);
    expect(items.map((e) => e.title), ['A-1', 'B-1']);
    final l = await k.extractor.resolve(items.first, http);
    expect(l.single.ext, 'jpg');
    expect(l.single.fileName, 'A-1.jpg');
  });
}

void embedTests() {
  final reg = Registry();
  test('video post yields an embed item; online-video lists videos only', () async {
    const post =
        '<html><head><meta property="og:title" content="Chel - Mitaku"></head>'
        '<div class="entry-content"><iframe src="https://byse.example/e/abc"></iframe>'
        '<a class="msacwl-img-link" data-mfp-src="https://mitaku.net/wp-content/uploads/2026/11/C-1.jpg"></a></div>';
    final http = FakeHttp(
      pages: {
        'https://mitaku.net/category/online-video/': _list([
          'https://mitaku.net/x/c/',
        ]),
        'https://mitaku.net/x/c/': post,
      },
    );
    final k = await reg.classify(
      'https://mitaku.net/category/online-video/',
      http,
    );
    final items = await k.extractor.listPlaylist(k.uri, http, maxPages: 1);
    expect(items.length, 1);
    expect(items.single.url, 'https://byse.example/e/abc');
    expect(items.single.title, 'Chel (video)');
    final l = await k.extractor.resolve(items.single, http);
    expect(
      l.single.url,
      'https://byse.example/e/abc',
    ); // placeholder until played
  });
}
