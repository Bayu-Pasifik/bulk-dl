import { useEffect, useMemo, useState } from 'react';
import { SEEDS, applySeed } from './theme.js';
import { SITES } from './sites.js';

const REPO = 'Bayu-Pasifik/bulk-dl';
const ABIS = [
  { key: 'arm64-v8a', label: 'arm64-v8a', note: 'Most phones (64-bit)' },
  { key: 'armeabi-v7a', label: 'armeabi-v7a', note: 'Older 32-bit phones' },
  { key: 'x86_64', label: 'x86_64', note: 'Emulators' },
];

const FEATURES = [
  ['playlist_add', 'Playlists & single links', 'Paste a video page, a listing or a direct file link. Pages are scanned and queued for you.'],
  ['hd', 'Best quality, capped by you', 'Picks the highest source quality up to the limit you set, from 240p to 4K.'],
  ['pause_circle', 'Queue, retry & resume', 'Parallel downloads, automatic retry and resume of partial files after a drop.'],
  ['notifications_active', 'Runs in background', 'A foreground service keeps downloads going with the screen off.'],
  ['shield', 'DNS-over-HTTPS, proxy, VPN', 'Built-in DNS-over-HTTPS, HTTP/SOCKS5 proxy and WireGuard for blocked networks.'],
  ['palette', 'Material You', 'Follows your wallpaper colors on Android 12+, with light and dark themes.'],
];

function Icon({ name }) {
  return <span className="material-symbols" aria-hidden="true">{name}</span>;
}

function useRelease() {
  const [rel, setRel] = useState(null);
  useEffect(() => {
    fetch(`https://api.github.com/repos/${REPO}/releases/latest`)
      .then((r) => (r.ok ? r.json() : null))
      .then(setRel)
      .catch(() => {});
  }, []);
  return rel;
}

function SiteLogo({ site }) {
  const [ok, setOk] = useState(true);
  return (
    <span className="logo">
      {ok ? (
        <img
          src={`https://www.${site.host}/favicon.ico`}
          alt=""
          loading="lazy"
          referrerPolicy="no-referrer"
          onError={() => setOk(false)}
        />
      ) : (
        site.name[0]
      )}
    </span>
  );
}

export default function App() {
  const [seed, setSeed] = useState(() => localStorage.getItem('seed') || SEEDS[0].hex);
  const [mode, setMode] = useState(() => localStorage.getItem('mode') || 'system');
  const [copied, setCopied] = useState('');
  const rel = useRelease();

  const dark = useMemo(
    () => mode === 'dark' || (mode === 'system' && matchMedia('(prefers-color-scheme: dark)').matches),
    [mode],
  );
  useEffect(() => {
    applySeed(seed, dark);
    localStorage.setItem('seed', seed);
    localStorage.setItem('mode', mode);
  }, [seed, dark, mode]);

  const asset = (abi) => rel?.assets?.find((a) => a.name.includes(abi));
  const releaseUrl = rel?.html_url || `https://github.com/${REPO}/releases/latest`;
  const mainUrl = asset('arm64-v8a')?.browser_download_url || releaseUrl;

  const copy = async (url) => {
    await navigator.clipboard.writeText(url);
    setCopied(url);
    setTimeout(() => setCopied(''), 1500);
  };

  return (
    <>
      <header className="bar">
        <a className="brand" href="#top"><Icon name="download" /> BulkDL</a>
        <nav>
          <a href="#features">Features</a>
          <a href="#sites">Sites</a>
          <a href="#download">Download</a>
        </nav>
        <button className="icon-btn" title="Theme" onClick={() => setMode(dark ? 'light' : 'dark')}>
          <Icon name={dark ? 'light_mode' : 'dark_mode'} />
        </button>
      </header>

      <main id="top">
        <section className="hero">
          <p className="chip">Android · open source</p>
          <h1>Download videos in bulk.</h1>
          <p className="lead">
            Playlists, single pages and direct links in one queue, with resume,
            retry and background downloads.
          </p>
          <div className="actions">
            <a className="btn filled" href={mainUrl}>
              <Icon name="download" /> Download {rel?.tag_name || 'latest'}
            </a>
            <a className="btn tonal" href={`https://github.com/${REPO}`}>
              <Icon name="code" /> GitHub
            </a>
          </div>
          <div className="seeds" role="group" aria-label="Accent color">
            {SEEDS.map((s) => (
              <button
                key={s.hex}
                className={'seed' + (s.hex === seed ? ' on' : '')}
                style={{ background: s.hex }}
                title={s.name}
                aria-label={s.name}
                onClick={() => setSeed(s.hex)}
              />
            ))}
          </div>
        </section>

        <section id="features">
          <h2>Features</h2>
          <div className="grid">
            {FEATURES.map(([icon, title, text]) => (
              <article className="card" key={title}>
                <span className="badge"><Icon name={icon} /></span>
                <h3>{title}</h3>
                <p>{text}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="sites">
          <h2>Supported sites</h2>
          <p className="muted">Tap a site to copy its address. Other pages with direct video links may also work.</p>
          <ul className="sites">
            {SITES.map((s) => (
              <li key={s.host}>
                <button className="site" onClick={() => copy(s.url)}>
                  <SiteLogo site={s} />
                  <span className="txt">
                    <strong>{s.name}</strong>
                    <small>{copied === s.url ? 'Copied' : s.url}</small>
                  </span>
                  <Icon name={copied === s.url ? 'check' : 'content_copy'} />
                </button>
              </li>
            ))}
          </ul>
        </section>

        <section id="download">
          <h2>Download</h2>
          <p className="muted">Pick the APK for your device. Not sure? Use arm64-v8a. Allow "install unknown apps" when prompted.</p>
          <div className="grid">
            {ABIS.map((a) => {
              const f = asset(a.key);
              return (
                <a className="card dl" key={a.key} href={f?.browser_download_url || releaseUrl}>
                  <Icon name="android" />
                  <h3>{a.label}</h3>
                  <p>{a.note}</p>
                  <small>{f ? `${(f.size / 1048576).toFixed(1)} MB` : 'See releases'}</small>
                </a>
              );
            })}
          </div>
        </section>
      </main>

      <footer>
        Download only content you have the right to keep. You are responsible for your use and for copyright.
        <br />
        Not affiliated with any listed site.
      </footer>
    </>
  );
}
