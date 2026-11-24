// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Bulk DL';

  @override
  String get navHome => 'Beranda';

  @override
  String get navQueue => 'Antrean';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String get disclaimerTitle => 'Sebelum mulai';

  @override
  String get disclaimerBody =>
      'Bulk DL hanya alat pengunduh. Unduh hanya konten yang kamu berhak simpan, dan patuhi hukum serta ketentuan situs. Kamu bertanggung jawab atas penggunaan dan hak cipta. Konten berDRM tidak didukung.';

  @override
  String get disclaimerOk => 'Mengerti';

  @override
  String get homeIntro =>
      'Unduh file, video, atau seluruh playlist dari link mana pun.';

  @override
  String get linkLabel => 'Link';

  @override
  String get linkHint => 'https://...  (boleh banyak, satu per baris)';

  @override
  String get paste => 'Tempel';

  @override
  String get modeAuto => 'Otomatis';

  @override
  String get modeSingle => 'Single';

  @override
  String get modePlaylist => 'Playlist';

  @override
  String get processing => 'Memproses...';

  @override
  String get analyzeAndDownload => 'Analisis & unduh';

  @override
  String viewVideos(int count) {
    return 'Lihat $count video';
  }

  @override
  String get maxQuality => 'Kualitas maksimum';

  @override
  String get recentTitle => 'Terakhir dipakai';

  @override
  String get delete => 'Hapus';

  @override
  String get cancel => 'Batal';

  @override
  String get save => 'Simpan';

  @override
  String get test => 'Tes';

  @override
  String get msgPasteLink => 'Tempel link yang diawali http:// atau https://';

  @override
  String msgAnalyzing(int count) {
    return 'Menganalisis $count link...';
  }

  @override
  String msgFound(int count) {
    return '$count video ditemukan...';
  }

  @override
  String get msgIsPlaylist =>
      'Link ini playlist — pilih mode Otomatis atau Playlist';

  @override
  String msgVideoCount(int count) {
    return '$count video';
  }

  @override
  String msgQueued(int count) {
    return '$count masuk antrean';
  }

  @override
  String get msgNothingFound => 'Tidak ada yang ditemukan';

  @override
  String get sizeUnknown => 'ukuran tidak diketahui';

  @override
  String get noLink => 'tidak ada link';

  @override
  String downloadN(int count) {
    return 'Unduh $count';
  }

  @override
  String downloadNSize(int count, String size) {
    return 'Unduh $count · $size';
  }

  @override
  String downloadNSizeUnknown(int count, String size, int unknown) {
    return 'Unduh $count · $size (+$unknown ?)';
  }

  @override
  String downloadNUnknown(int count, int unknown) {
    return 'Unduh $count (+$unknown ?)';
  }

  @override
  String bgStatus(int active, int waiting, String percent, String extra) {
    return '$active mengunduh, $waiting menunggu · $percent%$extra';
  }

  @override
  String get pickerCalcSizes => 'Hitung ukuran';

  @override
  String get pickerSearch => 'Cari judul';

  @override
  String get pickerAll => 'Semua';

  @override
  String get pickerNone => 'Tidak ada';

  @override
  String pickerSelected(int count) {
    return '$count dipilih';
  }

  @override
  String get alreadyDownloaded => 'Sudah diunduh';

  @override
  String get queueTitle => 'Antrean';

  @override
  String get queueClearFinished => 'Bersihkan yang selesai';

  @override
  String get queueEmpty => 'Antrean kosong';

  @override
  String get queueAdd => 'Tambah';

  @override
  String queueCounts(int active, int waiting) {
    return '$active mengunduh · $waiting menunggu';
  }

  @override
  String get queuePausedWifi => 'Dijeda: menunggu Wi-Fi';

  @override
  String get taskWaiting => 'Menunggu';

  @override
  String get taskPreparing => 'Menyiapkan...';

  @override
  String get taskDone => 'Selesai';

  @override
  String taskFailed(String error) {
    return 'Gagal: $error';
  }

  @override
  String get taskCanceled => 'Dibatalkan';

  @override
  String get taskCancel => 'Batalkan';

  @override
  String get taskRetry => 'Coba lagi';

  @override
  String get taskOpen => 'Buka';

  @override
  String get taskShare => 'Bagikan';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsDownloads => 'Unduhan';

  @override
  String get settingsParallel => 'Unduhan paralel';

  @override
  String get settingsMaxPages => 'Halaman playlist yang dipindai';

  @override
  String get settingsMaxPagesSub =>
      'Batasi jumlah halaman daftar yang dibaca per link playlist';

  @override
  String get settingsWifiOnly => 'Hanya lewat Wi-Fi';

  @override
  String get settingsWifiOnlySub => 'Jeda unduhan saat memakai data seluler';

  @override
  String get settingsSaveLocation => 'Lokasi simpan';

  @override
  String get settingsSaveLocationSub =>
      'Movies / Music / Pictures / Download → folder BulkDL';

  @override
  String get settingsNetwork => 'Jaringan';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsCookies => 'Cookie login per situs';

  @override
  String get settingsCookiesNone => 'Belum ada';

  @override
  String get settingsAppearance => 'Tampilan';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String get settingsDynamic => 'Warna dinamis';

  @override
  String get settingsDynamicSub =>
      'Ikuti warna wallpaper (Android 12+). Mati = hijau bawaan';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get langSystem => 'Sistem';

  @override
  String get langEnglish => 'English';

  @override
  String get langIndonesian => 'Bahasa Indonesia';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get aboutText =>
      'Unduh hanya konten yang kamu berhak simpan. Kamu bertanggung jawab atas penggunaan dan hak cipta.';

  @override
  String get dnsHelp =>
      'DNS-over-HTTPS membantu saat ISP memblokir situs lewat DNS. Tidak bisa menembus blokir IP/SNI.';

  @override
  String get dnsTesting => 'Menguji...';

  @override
  String dnsOk(String provider, String ip) {
    return 'OK lewat $provider: $ip';
  }

  @override
  String dnsFailed(String error) {
    return 'Gagal: $error';
  }

  @override
  String get cookieTitle => 'Cookie login';

  @override
  String get cookieHelp =>
      'Tempel header Cookie dari browser yang sudah login agar link HD terbuka. Disimpan hanya di perangkat ini dan hanya dikirim ke situs itu sendiri.';

  @override
  String get cookieHost => 'Host (mis. www.situs.com)';

  @override
  String get cookieLabel => 'Cookie';

  @override
  String get settingsProxy => 'Proxy';

  @override
  String get proxyOff => 'Mati';

  @override
  String get proxyUse => 'Pakai proxy';

  @override
  String get proxyType => 'Jenis';

  @override
  String get proxyHost => 'Host';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyUser => 'Username (opsional)';

  @override
  String get proxyPass => 'Password (opsional)';

  @override
  String get proxyPaste =>
      'Atau tempel link, mis. socks5://user:pass@host:1080';

  @override
  String get proxyBadLink => 'Link proxy tidak valid';

  @override
  String get proxyHelp =>
      'Semua unduhan dan pemuatan halaman lewat proxy ini. SOCKS5 juga me-resolve nama di proxy, jadi memintas blokir DNS.';

  @override
  String get proxyTesting => 'Menguji...';

  @override
  String proxyTestOk(String ip) {
    return 'Berhasil. IP keluar: $ip';
  }

  @override
  String proxyTestFail(String error) {
    return 'Gagal: $error';
  }

  @override
  String get settingsVpn => 'VPN (WireGuard)';

  @override
  String get vpnConnected => 'Terhubung';

  @override
  String get vpnDisconnected => 'Tidak terhubung';

  @override
  String get vpnNoConfig => 'Belum ada config';

  @override
  String get vpnHelp =>
      'Mengarahkan lalu lintas perangkat ini lewat server WireGuard. Tempel file .conf dari penyedia VPN atau server kamu sendiri. Config, termasuk private key, disimpan hanya di perangkat ini.';

  @override
  String get vpnConfigLabel => 'Config WireGuard';

  @override
  String get vpnConnect => 'Hubungkan';

  @override
  String get vpnDisconnect => 'Putuskan';

  @override
  String get vpnAuto => 'Hubungkan saat app dibuka';

  @override
  String vpnInvalid(String error) {
    return 'Config tidak valid: $error';
  }

  @override
  String vpnFailed(String error) {
    return 'VPN gagal: $error';
  }

  @override
  String get vpnImport => 'Tempel dari clipboard';
}
