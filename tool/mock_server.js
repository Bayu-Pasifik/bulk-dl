// Local mock of the video site for emulator tests: node tool/mock_server.js
// Playlist: http://10.0.2.2:8080/playlist/   (emulator -> host machine)
const http = require('http');
const extra = require('./mock_extra');
const N = 8;
const SIZE = 30 * 1024 * 1024; // 30 MB per file
const CHUNK = 64 * 1024;
const DELAY = 40; // ms per chunk -> ~1.6 MB/s

const vids = [...Array(N)].map((_, i) => ({ id: 'id' + i, slug: 'mock-video-' + i }));
http.createServer((req, res) => {
  const u = req.url;
  if (extra(req, res)) return;
  if (u.startsWith('/playlist/')) {
    const page = parseInt(u.split('/')[2]) || 1;
    const items = page === 1 ? vids : [];
    res.setHeader('content-type', 'text/html');
    return res.end('<html><body>' + items.map(v =>
      `<div><a href="/video-${v.id}/${v.slug}/"><img src="http://placehold/${v.id}.jpg" alt="Mock Video ${v.id}"></a></div>`).join('') + '</body></html>');
  }
  const m = u.match(/^\/video-([^/]+)\//);
  if (m) {
    res.setHeader('content-type', 'text/html');
    return res.end(`<html><a href="/dload/${m[1]}/720/${m[1]}-720p.mp4">Download MP4 (720p, 30 MB)</a>
<a href="/dload/${m[1]}/1080/${m[1]}-1080p.mp4">Download MP4 (1080p, 60 MB)</a>
<a href="/dload/${m[1]}/360/${m[1]}-360p.mp4">Download MP4 (360p, 12 MB)</a></html>`);
  }
  // --- direct files (single download tests) ---
  const direct = {
    '/files/clip.mp4': { size: 10 * 1024 * 1024, type: 'video/mp4' },
    '/files/preview.mp4': { size: 20 * 1024, type: 'video/mp4' },
    '/files/report.pdf': { size: 2 * 1024 * 1024, type: 'application/pdf' },
    '/files/nohead.bin': { size: 3 * 1024 * 1024, type: 'application/octet-stream', noHead: true },
    '/dl?id=7': { size: 4 * 1024 * 1024, type: 'application/octet-stream', name: 'Saved Name.mp4' },
  };
  const d = direct[u];
  if (d) {
    if (req.method === 'HEAD' && d.noHead) { res.statusCode = 405; return res.end(); }
    console.log(req.method, u, 'range=' + (req.headers.range || '-'));
    let start = 0;
    const rr = req.headers.range && req.headers.range.match(/bytes=(d+)-/);
    if (rr) start = parseInt(rr[1]);
    res.statusCode = rr ? 206 : 200;
    res.setHeader('content-type', d.type);
    res.setHeader('accept-ranges', 'bytes');
    res.setHeader('content-length', d.size - start);
    if (rr) res.setHeader('content-range', `bytes ${start}-${d.size - 1}/${d.size}`);
    if (d.name) res.setHeader('content-disposition', `attachment; filename="${d.name}"`);
    if (req.method === 'HEAD') return res.end();
    let sent = start;
    const b2 = Buffer.alloc(CHUNK, 2);
    const t2 = setInterval(() => {
      if (sent >= d.size) { clearInterval(t2); return res.end(); }
      const n = Math.min(CHUNK, d.size - sent); sent += n; res.write(b2.subarray(0, n));
    }, 10);
    req.on('close', () => clearInterval(t2));
    return;
  }
  if (u.startsWith('/dload/')) {
    if (u.includes('/1080/') && !(req.headers.cookie || '').includes('sess=ok')) {
      console.log('1080 denied (no cookie)');
      res.setHeader('content-type', 'text/html');
      return res.end('<html>please log in</html>');
    }
    if (u.includes('/1080/')) console.log('1080 allowed, cookie=' + req.headers.cookie);
    console.log(req.method, u, 'range=' + (req.headers.range || '-'));
    let start = 0;
    const r = req.headers.range && req.headers.range.match(/bytes=(\d+)-/);
    if (r) start = parseInt(r[1]);
    res.statusCode = r ? 206 : 200;
    res.setHeader('content-type', 'video/mp4');
    res.setHeader('accept-ranges', 'bytes');
    res.setHeader('content-length', SIZE - start);
    if (r) res.setHeader('content-range', `bytes ${start}-${SIZE - 1}/${SIZE}`);
    let sent = start;
    const buf = Buffer.alloc(CHUNK, 1);
    const t = setInterval(() => {
      if (sent >= SIZE) { clearInterval(t); return res.end(); }
      const n = Math.min(CHUNK, SIZE - sent); sent += n; res.write(buf.subarray(0, n));
    }, DELAY);
    req.on('close', () => clearInterval(t));
    return;
  }
  res.statusCode = 404; res.end('nf');
}).listen(8080, () => console.log('mock on :8080'));
