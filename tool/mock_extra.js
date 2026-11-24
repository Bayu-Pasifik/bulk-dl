// Extra mock routes: generic html pages and HLS streams.
// Returns true when the request was handled.
const crypto = require('crypto');

const KEY = Buffer.from('00112233445566778899aabbccddeeff', 'hex');
const IV = Buffer.from('0102030405060708090a0b0c0d0e0f10', 'hex');
const HOST = 'http://10.0.2.2:8080';

module.exports = function handle(req, res) {
  const u = req.url;

  // --- fake DoH server: every *.blocked.test name resolves to the host ---
  if (u.startsWith('/dns-query')) {
    const q = new URL(u, HOST).searchParams;
    const name = q.get('name') || '';
    console.log('DoH', q.get('type'), name);
    res.setHeader('content-type', 'application/dns-json');
    const ans = name.endsWith('blocked.test') && q.get('type') === 'A'
      ? { Status: 0, Answer: [{ name, type: 1, TTL: 60, data: '10.0.2.2' }] }
      : { Status: 3 };
    res.end(JSON.stringify(ans));
    return true;
  }

  // --- generic html pages ---
  const pg = u.match(/^\/page\/v(\d)$/);
  if (pg) {
    res.setHeader('content-type', 'text/html');
    res.end(`<html><head><title>Generic Video ${pg[1]}</title>
<meta property="og:title" content="Generic Video ${pg[1]}"></head><body>
<video controls><source src="/files/preview.mp4" res="360" type="video/mp4"><source src="/files/clip.mp4" res="720" type="video/mp4"></video></body></html>`);
    return true;
  }
  if (u === '/page/list') {
    res.setHeader('content-type', 'text/html');
    res.end('<html><body>' + [1, 2, 3, 4].map(i =>
      `<div><a href="/page/v${i}"><img src="http://placehold/${i}.jpg" alt="Card ${i}"></a></div>`).join('') + '</body></html>');
    return true;
  }
  if (u === '/page/hls') {
    res.setHeader('content-type', 'text/html');
    // Escaped slashes, like a JS player config.
    const esc = (HOST + '/hls/master.m3u8').split('/').join('\\/');
    res.end(`<html><head><title>HLS Page</title></head><body><script>var player = {src: "${esc}"};</script></body></html>`);
    return true;
  }

  // --- HLS ---
  if (u === '/hls/master.m3u8') {
    res.setHeader('content-type', 'application/vnd.apple.mpegurl');
    res.end('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360\nv360.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720\nv720.m3u8\n');
    return true;
  }
  if (u === '/hls/v360.m3u8' || u === '/hls/v720.m3u8') {
    const enc = u.includes('720');
    let t = '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:4\n#EXT-X-MEDIA-SEQUENCE:0\n';
    if (enc) t += '#EXT-X-KEY:METHOD=AES-128,URI="key.bin",IV=0x0102030405060708090a0b0c0d0e0f10\n';
    for (let i = 0; i < 12; i++) t += '#EXTINF:4.0,\nseg/' + (enc ? 'e' : 'c') + i + '.ts\n';
    res.setHeader('content-type', 'application/vnd.apple.mpegurl');
    res.end(t + '#EXT-X-ENDLIST\n');
    return true;
  }
  if (u === '/hls/key.bin') { res.end(KEY); return true; }
  const sg = u.match(/^\/hls\/seg\/([ec])(\d+)\.ts$/);
  if (sg) {
    const plain = Buffer.alloc(200 * 1024, parseInt(sg[2]) + 1);
    res.setHeader('content-type', 'video/mp2t');
    if (sg[1] === 'c') { res.end(plain); return true; }
    const c = crypto.createCipheriv('aes-128-cbc', KEY, IV);
    res.end(Buffer.concat([c.update(plain), c.final()]));
    return true;
  }
  if (u === '/hls/drm.m3u8') {
    res.setHeader('content-type', 'application/vnd.apple.mpegurl');
    res.end('#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXT-X-KEY:METHOD=SAMPLE-AES,URI="skd://abc",KEYFORMAT="com.apple.streamingkeydelivery"\n#EXTINF:4.0,\nseg/c0.ts\n#EXT-X-ENDLIST\n');
    return true;
  }
  return false;
};
