// Keep in sync with lib/sites.dart in the app.
// Third value false = the site is not served under www.
export const SITES = [
  ['XVideos', 'xvideos.com'],
  ['XNXX', 'xnxx.com'],
  ['Pornhub', 'pornhub.com'],
  ['RedTube', 'redtube.com'],
  ['YouPorn', 'youporn.com'],
  ['Tube8', 'tube8.com'],
  ['xHamster', 'xhamster.com'],
  ['TNAFlix', 'tnaflix.com'],
  ['PornOne', 'pornone.com'],
  ['Eporner', 'eporner.com'],
  ['ThisVid', 'thisvid.com'],
  ['PornTrex', 'porntrex.com'],
  ['HQPorner', 'hqporner.com'],
  ['SunPorno', 'sunporno.com'],
  ['Rule34Video', 'rule34video.com', false],
  ['HentaiCity', 'hentaicity.com'],
  ['WatchHentai', 'watchhentai.net'],
].map(([name, host, www = true]) => ({
  name,
  host,
  url: `https://${www ? 'www.' : ''}${host}`,
}));
