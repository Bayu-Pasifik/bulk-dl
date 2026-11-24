/// Sites with a dedicated extractor, shown on the "Supported sites" screen.
class SupportedSite {
  const SupportedSite(this.name, this.host, {this.www = true});
  final String name;
  final String host;

  /// Whether the site's canonical address uses the `www.` prefix.
  final bool www;
  String get url => 'https://${www ? 'www.' : ''}$host';
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
  SupportedSite('HQPorner', 'hqporner.com'),
  SupportedSite('SunPorno', 'sunporno.com'),
  SupportedSite('Rule34Video', 'rule34video.com', www: false),
  SupportedSite('HentaiCity', 'hentaicity.com'),
  SupportedSite('WatchHentai', 'watchhentai.net'),
  SupportedSite('Mitaku (foto)', 'mitaku.net'),
];
