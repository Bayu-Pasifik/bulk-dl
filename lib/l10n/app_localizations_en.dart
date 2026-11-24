// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bulk DL';

  @override
  String get navHome => 'Home';

  @override
  String get navQueue => 'Queue';

  @override
  String get navSettings => 'Settings';

  @override
  String get disclaimerTitle => 'Before you start';

  @override
  String get disclaimerBody =>
      'Bulk DL is only a download tool. Download only content you have the right to keep, and follow the law and each site\'s terms. You are responsible for your use and for copyright. DRM-protected content is not supported.';

  @override
  String get disclaimerOk => 'Got it';

  @override
  String get homeIntro =>
      'Download files, videos, or whole playlists from any link.';

  @override
  String get linkLabel => 'Link';

  @override
  String get linkHint => 'https://...  (several allowed, one per line)';

  @override
  String get paste => 'Paste';

  @override
  String get modeAuto => 'Auto';

  @override
  String get modeSingle => 'Single';

  @override
  String get modePlaylist => 'Playlist';

  @override
  String get processing => 'Processing...';

  @override
  String get analyzeAndDownload => 'Analyze & download';

  @override
  String viewVideos(int count) {
    return 'View $count videos';
  }

  @override
  String get maxQuality => 'Maximum quality';

  @override
  String get recentTitle => 'Recently used';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get test => 'Test';

  @override
  String get msgPasteLink => 'Paste a link starting with http:// or https://';

  @override
  String msgAnalyzing(int count) {
    return 'Analyzing $count links...';
  }

  @override
  String msgFound(int count) {
    return '$count videos found...';
  }

  @override
  String get msgIsPlaylist =>
      'This link is a playlist — choose Auto or Playlist mode';

  @override
  String msgVideoCount(int count) {
    return '$count videos';
  }

  @override
  String msgQueued(int count) {
    return '$count added to queue';
  }

  @override
  String get msgNothingFound => 'Nothing found';

  @override
  String get sizeUnknown => 'size unknown';

  @override
  String get noLink => 'no link';

  @override
  String downloadN(int count) {
    return 'Download $count';
  }

  @override
  String downloadNSize(int count, String size) {
    return 'Download $count · $size';
  }

  @override
  String downloadNSizeUnknown(int count, String size, int unknown) {
    return 'Download $count · $size (+$unknown ?)';
  }

  @override
  String downloadNUnknown(int count, int unknown) {
    return 'Download $count (+$unknown ?)';
  }

  @override
  String bgStatus(int active, int waiting, String percent, String extra) {
    return '$active downloading, $waiting waiting · $percent%$extra';
  }

  @override
  String get pickerCalcSizes => 'Calculate size';

  @override
  String get pickerSearch => 'Search title';

  @override
  String get pickerAll => 'All';

  @override
  String get pickerNone => 'None';

  @override
  String pickerSelected(int count) {
    return '$count selected';
  }

  @override
  String get alreadyDownloaded => 'Already downloaded';

  @override
  String get queueTitle => 'Queue';

  @override
  String get queueClearFinished => 'Clear finished';

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get queueAdd => 'Add';

  @override
  String queueCounts(int active, int waiting) {
    return '$active downloading · $waiting waiting';
  }

  @override
  String get queuePausedWifi => 'Paused: waiting for Wi-Fi';

  @override
  String get taskWaiting => 'Waiting';

  @override
  String get taskPreparing => 'Preparing...';

  @override
  String get taskDone => 'Done';

  @override
  String taskFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get taskCanceled => 'Canceled';

  @override
  String get taskCancel => 'Cancel';

  @override
  String get taskRetry => 'Retry';

  @override
  String get taskOpen => 'Open';

  @override
  String get taskShare => 'Share';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDownloads => 'Downloads';

  @override
  String get settingsParallel => 'Parallel downloads';

  @override
  String get settingsMaxPages => 'Playlist pages to scan';

  @override
  String get settingsMaxPagesSub =>
      'Limits how many listing pages are read per playlist link';

  @override
  String get settingsWifiOnly => 'Wi-Fi only';

  @override
  String get settingsWifiOnlySub => 'Pause downloads on mobile data';

  @override
  String get settingsSaveLocation => 'Save location';

  @override
  String get settingsSaveLocationSub =>
      'Movies / Music / Pictures / Download → BulkDL folder';

  @override
  String get settingsNetwork => 'Network';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsCookies => 'Login cookie per site';

  @override
  String get settingsCookiesNone => 'None yet';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsDynamic => 'Dynamic color';

  @override
  String get settingsDynamicSub =>
      'Follow wallpaper colors (Android 12+). Off = default green';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get langEnglish => 'English';

  @override
  String get langIndonesian => 'Bahasa Indonesia';

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutText =>
      'Download only content you have the right to keep. You are responsible for your use and for copyright.';

  @override
  String get dnsHelp =>
      'DNS-over-HTTPS helps when your ISP blocks sites via DNS. It cannot bypass IP/SNI blocks.';

  @override
  String get dnsTesting => 'Testing...';

  @override
  String dnsOk(String provider, String ip) {
    return 'OK via $provider: $ip';
  }

  @override
  String dnsFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get cookieTitle => 'Login cookie';

  @override
  String get cookieHelp =>
      'Paste the Cookie header from a logged-in browser so HD links open. Stored only on this device and sent only to that site.';

  @override
  String get cookieHost => 'Host (e.g. www.site.com)';

  @override
  String get cookieLabel => 'Cookie';

  @override
  String get settingsProxy => 'Proxy';

  @override
  String get proxyOff => 'Off';

  @override
  String get proxyUse => 'Use proxy';

  @override
  String get proxyType => 'Type';

  @override
  String get proxyHost => 'Host';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyUser => 'Username (optional)';

  @override
  String get proxyPass => 'Password (optional)';

  @override
  String get proxyPaste => 'Or paste a link, e.g. socks5://user:pass@host:1080';

  @override
  String get proxyBadLink => 'Not a valid proxy link';

  @override
  String get proxyHelp =>
      'All downloads and page loads go through this proxy. SOCKS5 also resolves names on the proxy, which bypasses DNS blocks.';

  @override
  String get proxyTesting => 'Testing...';

  @override
  String proxyTestOk(String ip) {
    return 'Works. Exit IP: $ip';
  }

  @override
  String proxyTestFail(String error) {
    return 'Failed: $error';
  }

  @override
  String get settingsVpn => 'VPN (WireGuard)';

  @override
  String get vpnConnected => 'Connected';

  @override
  String get vpnDisconnected => 'Not connected';

  @override
  String get vpnNoConfig => 'No config imported';

  @override
  String get vpnHelp =>
      'Routes this device\'s traffic through a WireGuard server. Paste a .conf from your VPN provider or your own server. The config, including its private key, is stored only on this device.';

  @override
  String get vpnConfigLabel => 'WireGuard config';

  @override
  String get vpnConnect => 'Connect';

  @override
  String get vpnDisconnect => 'Disconnect';

  @override
  String get vpnAuto => 'Connect when the app starts';

  @override
  String vpnInvalid(String error) {
    return 'Invalid config: $error';
  }

  @override
  String vpnFailed(String error) {
    return 'VPN failed: $error';
  }

  @override
  String get vpnImport => 'Paste from clipboard';
}
