// Keep in sync with lib/sites.dart in the app.
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
].map(([name, host]) => ({ name, host, url: `https://www.${host}` }));
