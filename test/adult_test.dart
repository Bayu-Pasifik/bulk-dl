import 'package:bulk_dl/extractors/registry.dart';
import 'package:bulk_dl/models.dart';
import 'package:bulk_dl/net/http.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http.dart';

const _master = '''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
hls-360.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
hls-720.m3u8
''';

HeadInfo _mp4(String u, int bytes) =>
    HeadInfo(url: u, length: bytes, type: 'video/mp4');

void main() {
  final reg = Registry();

  test('xnxx video page is classified as video, not eporner', () async {
    final k = await reg.classify(
      'https://www.xnxx.com/video-1ivubg28/some_title',
      FakeHttp(),
    );
    expect(k.extractor.id, 'xvideos');
    expect(k.kind, UrlKind.video);
  });

  test('xvideos listing is a playlist; video paths are recognised', () async {
    final k = await reg.classify('https://www.xvideos.com/best', FakeHttp());
    expect(k.kind, UrlKind.playlist);
    final v = await reg.classify(
      'https://www.xvideos.com/video.omfipke155e/slug',
      FakeHttp(),
    );
    expect(v.kind, UrlKind.video);
    final n = await reg.classify(
      'https://www.xvideos.com/video12345/slug',
      FakeHttp(),
    );
    expect(n.kind, UrlKind.video);
    // "/videos/..." must not be mistaken for a video page.
    final l = await reg.classify(
      'https://www.xvideos.com/videos/x',
      FakeHttp(),
    );
    expect(l.kind, UrlKind.playlist);
  });

  test('xvideos resolve: mp4 + HLS variants, sizes, title', () async {
    const page = '''
<html><head><meta property="og:title" content="Nice Title"></head><body><script>
html5player.setVideoTitle('Nice Title');
html5player.setVideoUrlLow('https://cdn.x/a/mp4_sd.mp4?secure=1');
html5player.setVideoUrlHigh('https://cdn.x/a/mp4_hd.mp4?secure=2');
html5player.setVideoHLS('https://cdn.x/a/hls.m3u8');
</script></body></html>''';
    final http = FakeHttp(
      pages: {
        'https://www.xvideos.com/video.abc/nice': page,
        'https://cdn.x/a/hls.m3u8': _master,
      },
      heads: {
        'https://cdn.x/a/mp4_sd.mp4?secure=1': _mp4(
          'https://cdn.x/a/mp4_sd.mp4?secure=1',
          10485760,
        ),
        'https://cdn.x/a/mp4_hd.mp4?secure=2': _mp4(
          'https://cdn.x/a/mp4_hd.mp4?secure=2',
          20971520,
        ),
      },
    );
    final k = await reg.classify(
      'https://www.xvideos.com/video.abc/nice',
      http,
    );
    final item = k.extractor.single(k.uri, http);
    expect(item.id, 'abc');
    final links = await k.extractor.resolve(item, http);
    final plain = links.where((l) => !l.hls).toList();
    expect(plain.map((l) => l.quality), containsAll([720, 480]));
    expect(plain.firstWhere((l) => l.quality == 720).mb, 20);
    expect(plain.first.fileName, 'Nice Title.mp4');
    expect(links.where((l) => l.hls).map((l) => l.quality), [360, 720]);
  });

  test('xnxx listing: cards, best title, next page', () async {
    const p1 = '''
<div class="thumb-block"><div class="thumb"><a href="/video-aa1/first_one"><img data-src="https://t/1.jpg"></a></div>
<div class="thumb-under"><p><a href="/video-aa1/first_one" title="First One">First</a></p></div></div>
<div class="thumb-block"><a href="/video-bb2/second"><img src="https://t/2.jpg"></a></div>
<a href="/best/2" class="dir next">Next</a>''';
    const p2 = '''
<div class="thumb-block"><a href="/video-cc3/third"><img src="https://t/3.jpg"></a></div>''';
    final http = FakeHttp(
      pages: {
        'https://www.xnxx.com/best': p1,
        'https://www.xnxx.com/best/2': p2,
      },
    );
    final k = await reg.classify('https://www.xnxx.com/best', http);
    final items = await k.extractor.listPlaylist(k.uri, http);
    expect(items.map((i) => i.id), ['aa1', 'bb2', 'cc3']);
    expect(items.first.title, 'First One');
    expect(items.first.thumb, 'https://t/1.jpg');
    expect(items.every((i) => i.extractor == 'xvideos'), isTrue);
  });

  test('pornhub family: viewkey detection', () async {
    final v = await reg.classify(
      'https://www.pornhub.com/view_video.php?viewkey=ph123',
      FakeHttp(),
    );
    expect(v.extractor.id, 'mediadef');
    expect(v.kind, UrlKind.video);
    final l = await reg.classify('https://www.pornhub.com/video', FakeHttp());
    expect(l.kind, UrlKind.playlist);
    final r = await reg.classify('https://www.redtube.com/123456', FakeHttp());
    expect(r.kind, UrlKind.video);
    final y = await reg.classify(
      'https://www.youporn.com/watch/99/slug/',
      FakeHttp(),
    );
    expect(y.kind, UrlKind.video);
  });

  test('mediaDefinitions: hls + mp4 indirection json', () async {
    const page = r'''
<html><head><title>PH Title</title></head><script>
var flashvars_1 = {"video_title":"x","mediaDefinitions":[
{"defaultQuality":false,"format":"hls","videoUrl":"https:\/\/cdn.p\/master.m3u8?a=1","quality":"720"},
{"defaultQuality":[1080,720],"format":"mp4","videoUrl":"https:\/\/www.pornhub.com\/video\/get_media?s=zz","quality":"","note":"has ] and [ in \"str\""}
],"other":1};
</script></html>''';
    const media = r'''[
{"defaultQuality":true,"format":"mp4","videoUrl":"https://cdn.p/v720.mp4?t=1","quality":"720"},
{"defaultQuality":false,"format":"mp4","videoUrl":"https://cdn.p/v480.mp4?t=1","quality":"480"}]''';
    final http = FakeHttp(
      pages: {
        'https://www.pornhub.com/view_video.php?viewkey=ph1': page,
        'https://cdn.p/master.m3u8?a=1': _master,
        'https://www.pornhub.com/video/get_media?s=zz': media,
      },
      heads: {
        'https://cdn.p/v720.mp4?t=1': _mp4(
          'https://cdn.p/v720.mp4?t=1',
          5242880,
        ),
      },
    );
    final k = await reg.classify(
      'https://www.pornhub.com/view_video.php?viewkey=ph1',
      http,
    );
    final item = k.extractor.single(k.uri, http);
    expect(item.id, 'ph1');
    final links = await k.extractor.resolve(item, http);
    expect(links.where((l) => !l.hls).map((l) => l.quality).toSet(), {
      720,
      480,
    });
    expect(links.where((l) => l.hls).map((l) => l.quality), [360, 720]);
    expect(links.firstWhere((l) => l.quality == 720 && !l.hls).mb, 5);
  });

  test('kvs sites: ids, flashvars links with labels, next page', () async {
    final pt = await reg.classify(
      'https://www.porntrex.com/video/3415902/slug',
      FakeHttp(),
    );
    expect(pt.extractor.id, 'kvs');
    expect(pt.kind, UrlKind.video);
    final tv = await reg.classify(
      'https://thisvid.com/videos/some-slug/',
      FakeHttp(),
    );
    expect(tv.kind, UrlKind.video);
    final list = await reg.classify(
      'https://thisvid.com/latest-updates/',
      FakeHttp(),
    );
    expect(list.kind, UrlKind.playlist);

    const page = '''
<html><head><title>Kvs Vid</title></head><body><script>
var flashvars = {
 video_url: 'https://www.porntrex.com/get_file/4/aa/1/2/2.mp4/',
 video_url_text: '480p',
 video_alt_url: 'https://www.porntrex.com/get_file/4/bb/1/2/2_720p.mp4/',
 video_alt_url_text: '720p HD',
 video_alt_url2: 'function/0/https://www.porntrex.com/get_file/4/cc/x.mp4/',
 preview_url: 'https://www.porntrex.com/contents/x.jpg'
};
</script></body></html>''';
    final http = FakeHttp(
      pages: {pt.uri.toString(): page},
      heads: {
        'https://www.porntrex.com/get_file/4/aa/1/2/2.mp4/': _mp4(
          'https://cdn.x/2.mp4',
          2097152,
        ),
        'https://www.porntrex.com/get_file/4/bb/1/2/2_720p.mp4/': _mp4(
          'https://cdn.x/2_720.mp4',
          4194304,
        ),
      },
    );
    final links = await pt.extractor.resolve(
      pt.extractor.single(pt.uri, http),
      http,
    );
    expect(links.map((l) => l.quality), [480, 720]);
    expect(links.last.mb, 4);
  });

  test('xhamster: id, h264 master preferred over av1', () async {
    final k = await reg.classify(
      'https://xhamster.com/videos/some-title-xh7dwqd',
      FakeHttp(),
    );
    expect(k.extractor.id, 'xhamster');
    expect(k.kind, UrlKind.video);
    final l = await reg.classify('https://xhamster.com/newest', FakeHttp());
    expect(l.kind, UrlKind.playlist);

    const av1 = 'https://v.cdn/key=1/media=hls4/_TPL_.av1.mp4.m3u8';
    const h264 = 'https://v.cdn/key=1/media=hls4/_TPL_.h264.mp4.m3u8';
    final http = FakeHttp(
      pages: {
        k.uri.toString():
            '<html><head><title>Xh Vid</title></head><body>'
            '<script>{"hls":{"url":"${av1.replaceAll('/', r'\/')}"}}</script>'
            '</body></html>',
        h264: _master,
      },
    );
    final links = await k.extractor.resolve(
      k.extractor.single(k.uri, http),
      http,
    );
    expect(links.map((x) => x.quality), [360, 720]);
    expect(links.every((x) => x.hls), isTrue);
  });

  test('tnaflix: id, source sizes, trailer skipped', () async {
    final k = await reg.classify(
      'https://www.tnaflix.com/amateur-porn/Black-Bred/video12217379',
      FakeHttp(),
    );
    expect(k.extractor.id, 'tnaflix');
    expect(k.kind, UrlKind.video);
    final l = await reg.classify('https://www.tnaflix.com/new/', FakeHttp());
    expect(l.kind, UrlKind.playlist);
    final http = FakeHttp(
      pages: {
        k.uri.toString():
            '<html><title>Tna Vid</title><video>'
            '<source src="https://s.x/a-480p.mp4?s=1" type="video/mp4" size="480">'
            '<source src="https://s.x/a-360p.mp4?s=2" type="video/mp4" size="360">'
            '<source src="https://c.x/trailer.mp4" type="video/mp4">'
            '</video></html>',
      },
      heads: {
        'https://s.x/a-480p.mp4?s=1': _mp4(
          'https://s.x/a-480p.mp4?s=1',
          3145728,
        ),
        'https://s.x/a-360p.mp4?s=2': _mp4(
          'https://s.x/a-360p.mp4?s=2',
          1048576,
        ),
      },
    );
    final links = await k.extractor.resolve(
      k.extractor.single(k.uri, http),
      http,
    );
    expect(links.map((x) => x.quality), [480, 360]);
    expect(links.first.mb, 3);
  });

  test(
    'generic: preview-only page errors instead of saving the trailer',
    () async {
      final http = FakeHttp(
        pages: {
          'https://example.org/v':
              '<video src="https://cdn.x/preview/abc/preview.mp4"></video>',
        },
      );
      final k = await reg.classify('https://example.org/v', http);
      await expectLater(
        k.extractor.resolve(k.extractor.single(k.uri, http), http),
        throwsA(contains('preview')),
      );
    },
  );

  test('generic: image-only ld+json contentUrl is not a video', () async {
    final http = FakeHttp(
      pages: {
        'https://example.org/w':
            '<script type="application/ld+json">'
            '{"@type":"ImageObject","contentUrl":"https://x.y/a/poster.jpg"}'
            '</script>',
      },
    );
    await expectLater(
      reg.classify('https://example.org/w', http),
      throwsA(contains('No downloadable media')),
    );
  });

  test('unrelated host still falls through to generic', () async {
    final http = FakeHttp(
      pages: {'https://example.org/p': '<video src="/a.mp4"></video>'},
    );
    final k = await reg.classify('https://example.org/p', http);
    expect(k.extractor.id, isNot('xvideos'));
    expect(k.extractor.id, isNot('mediadef'));
  });
}
