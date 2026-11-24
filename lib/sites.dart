/// Sites with a dedicated extractor, shown on the "Supported sites" screen.
class SupportedSite {
  const SupportedSite(this.name, this.host);
  final String name;
  final String host;
  String get url => 'https://www.$host';
}

const supportedSites = <SupportedSite>[
  SupportedSite('XVideos', 'xvideos.com'),
  SupportedSite('XNXX', 'xnxx.com'),
  SupportedSite('Pornhub', 'pornhub.com'),
  SupportedSite('RedTube', 'redtube.com'),
  SupportedSite('YouPorn', 'youporn.com'),
  SupportedSite('Tube8', 'tube8.com'),
  SupportedSite('xHamster', 'xhamster.com'),
  SupportedSite('TNAFlix', 'tnaflix.com'),
  SupportedSite('PornOne', 'pornone.com'),
  SupportedSite('Eporner', 'eporner.com'),
  SupportedSite('ThisVid', 'thisvid.com'),
  SupportedSite('PornTrex', 'porntrex.com'),
];
