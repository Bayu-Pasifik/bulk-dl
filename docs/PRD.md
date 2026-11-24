# PRD — bulk_dl

Versi dokumen: 1.0 · Status: Draft · Platform: Android (Flutter)

## 1. Ringkasan

bulk_dl adalah aplikasi Android untuk mengunduh video secara massal dari sebuah
link playlist, dengan antrean, progres, dan layanan latar belakang. Saat ini
aplikasi hanya mendukung satu situs (Eporner) dan hanya mode playlist.

Rilis berikutnya memperluas aplikasi menjadi pengunduh serbaguna:

1. Bisa mengunduh **satu file** (single download), bukan hanya playlist.
2. Bisa mengunduh dari **banyak situs**, tidak terikat ke satu situs.
3. Tampilan baru: **Material You (Material 3) dengan warna dominan hijau**.

## 2. Kondisi saat ini (baseline)

Dari kode di `lib/`:

- `scraper.dart` — mengambil halaman playlist (`/`, `/2/`, `/3/` ...), mem-parse
  `a[href^="/video-"]`, lalu mengambil tautan `/dload/.../<kualitas>/...mp4`
  dari tiap halaman video. Logika ini spesifik Eporner.
- `queue.dart` — `DownloadQueue`: paralel, retry dengan backoff, mode hanya
  Wi-Fi, kecepatan per tugas, total progres + ETA, penyimpanan antrean,
  pembersihan file parsial, resume setelah restart.
- `bg.dart` — foreground service agar unduhan tetap jalan.
- `library.dart` — penanda "sudah diunduh".
- `main.dart` — satu layar: input URL, daftar playlist, filter judul, antrean.
- `neo.dart` — tema neo-brutalist (kuning), akan diganti.
- Menerima link dari share sheet aplikasi lain.
- Pengaturan tersimpan: kualitas, jumlah paralel, Wi-Fi saja, URL terakhir.

## 3. Tujuan dan non-tujuan

### Tujuan

- G1. Pengguna menempel satu link file/video → langsung masuk antrean.
- G2. Pengguna menempel link dari situs mana pun yang didukung → aplikasi
  mengenali jenis link (file langsung, halaman video, playlist) dan memberi
  pilihan yang tepat.
- G3. Situs baru bisa ditambah tanpa menyentuh antrean/UI (arsitektur adapter).
- G4. UI konsisten Material 3, hijau dominan, mendukung warna dinamis Android 12+
  dan mode gelap.
- G5. Semua fitur antrean yang sudah ada tetap berfungsi tanpa regresi.

### Non-tujuan

- Tidak membypass DRM (Widevine/FairPlay), paywall, atau login yang tidak
  dimiliki pengguna.
- Tidak menyediakan daftar situs bawaan yang melanggar hukum setempat; tanggung
  jawab atas konten dan hak cipta ada pada pengguna.
- iOS dan desktop tidak termasuk rilis ini.
- Konversi/encode ulang video tidak termasuk.

## 4. Pengguna dan skenario

| Skenario | Contoh |
|---|---|
| Unduh satu file | Pengguna menempel `https://host/file.mp4`, langsung terunduh |
| Unduh satu halaman video | Pengguna menempel link halaman, aplikasi mencari sumber videonya |
| Unduh playlist | Perilaku sekarang: daftar video, pilih, unduh |
| Dari aplikasi lain | Share link dari browser ke bulk_dl |
| Banyak link sekaligus | Menempel beberapa link (satu per baris) |

## 5. Kebutuhan fungsional

### 5.1 Mode unduh

- F1. Input tunggal menerima satu atau banyak URL (satu per baris).
- F2. Deteksi otomatis jenis URL:
  - **Direct file** — ekstensi/`Content-Type` media (`mp4`, `mkv`, `webm`, `mp3`,
    `m4a`, `jpg`, `png`, `pdf`, `zip`, dll.) → unduh langsung.
  - **Halaman video** — satu video, cari sumber media di halaman.
  - **Playlist/koleksi** — banyak video, tampilkan daftar untuk dipilih.
- F3. Jika deteksi ambigu, pengguna bisa memilih mode manual (Single / Playlist).
- F4. Single download tidak melewati layar daftar; langsung ke antrean dengan
  opsi ganti nama file dan folder tujuan.
- F5. Untuk direct file: baca `HEAD` (ukuran, nama, dukungan `Range`) sebelum
  mulai; dukung resume bila server mendukung `Range`.

### 5.2 Dukungan banyak situs

- F6. Arsitektur **Extractor** (adapter per situs) dengan kontrak:
  - `bool matches(Uri url)`
  - `Future<UrlKind> classify(Uri url)` — file / video / playlist
  - `Future<List<VideoItem>> listPlaylist(Uri url, {onProgress})`
  - `Future<List<MediaSource>> resolve(VideoItem item)` — daftar kualitas/URL
- F7. Extractor yang disertakan:
  1. `EpornerExtractor` — logika scraper saat ini dipindahkan apa adanya.
  2. `DirectFileExtractor` — URL file langsung.
  3. `GenericHtmlExtractor` — fallback untuk situs lain: cari `og:video`,
     `<video src>`, `<source src>`, tag `link`/`a` ke file media, dan JSON-LD
     `VideoObject.contentUrl`.
  4. `HlsExtractor` — playlist `.m3u8` tanpa enkripsi DRM: pilih varian,
     unduh segmen, gabung (lihat F10).
- F8. Pemilihan extractor: situs spesifik lebih dulu, lalu Direct, lalu Generic.
- F9. Jika tidak ada sumber ditemukan, tampilkan pesan jelas ("Tidak ada media
  yang bisa diunduh di halaman ini") dengan tombol salin log.
- F10. HLS: hanya stream tidak terenkripsi atau AES-128 dengan kunci yang
  tersedia publik di manifest. Stream DRM ditolak dengan pesan jelas.
- F11. Cookie sesi opsional per host (bukan satu cookie global) — dikirim hanya
  ke host asalnya.

### 5.2b DNS kustom (anti blokir DNS)

Banyak ISP memblokir situs lewat DNS. Aplikasi menyediakan resolver sendiri.

- F20. Pengaturan **DNS**: Sistem (default) · Cloudflare (`1.1.1.1`) · Google
  (`8.8.8.8`) · DNS.SB (`185.222.222.222`) · Kustom (URL DoH atau IP).
- F21. Resolusi lewat **DNS-over-HTTPS (DoH)** agar kueri tidak bisa dibelokkan
  ISP. Semua request Dio (halaman, `HEAD`, unduhan, segmen HLS) memakai resolver
  yang sama.
- F22. Koneksi ke IP hasil DoH tetap memakai hostname asli untuk SNI dan
  validasi sertifikat (TLS tidak dilonggarkan).
- F23. Fallback otomatis: bila DNS sistem gagal/diblokir (NXDOMAIN palsu atau
  IP halaman blokir), coba DoH; bila DoH gagal, coba penyedia berikutnya.
- F24. Cache hasil DNS dengan TTL, dan tombol "Tes DNS" di pengaturan.
- F25. Batasan jujur: ini hanya mengatasi blokir tingkat DNS. Blokir IP atau SNI
  tidak teratasi; aplikasi menampilkan pesan yang menjelaskan hal itu.

### 5.3 Antrean (dipertahankan dan diperluas)

- F12. `Task` menyimpan `extractorId`, `sourceUrl`, `kind` agar bisa dilanjutkan
  setelah restart.
- F13. Semua fitur lama tetap: paralel, backoff retry, Wi-Fi saja, kecepatan,
  ETA, pembersihan parsial, foreground service.
- F14. Nama file di-sanitasi dan dihindari tabrakan (`nama (1).ext`).
- F15. Penanda "sudah diunduh" berlaku untuk semua situs (kunci = URL kanonik).

### 5.4 Tampilan

- F16. Material 3 dengan warna hijau dominan (lihat `STYLE.md`).
- F17. Warna dinamis (Material You) di Android 12+, fallback seed hijau.
- F18. Mode terang, gelap, dan ikuti sistem.
- F19. Layar: **Beranda** (input + tempel + riwayat singkat), **Pilih video**
  (hasil playlist), **Antrean**, **Pengaturan**.

## 6. Kebutuhan non-fungsional

- N1. Antrean 500 item tetap mulus (daftar lazy, tanpa jank).
- N2. Unduhan tetap hidup saat layar mati (foreground service, notifikasi progres).
- N3. Tidak ada data pengguna dikirim ke server pihak ketiga; semua proses lokal.
- N4. Minimum Android 8.0 (API 26); warna dinamis aktif di API 31+.
- N5. Aksesibilitas: kontras WCAG AA, target sentuh ≥ 48dp, dukung font besar.
- N6. Setiap extractor punya tes unit dengan HTML fixture (tanpa jaringan).

## 7. Metrik keberhasilan

- 95% link direct file berhasil diunduh tanpa langkah tambahan.
- Menambah situs baru ≤ 1 file extractor + 1 file tes, tanpa mengubah UI/antrean.
- Tidak ada regresi pada tes antrean yang ada.
- Waktu dari tempel link ke unduhan berjalan (single) ≤ 3 ketuk.

## 8. Risiko

| Risiko | Mitigasi |
|---|---|
| Situs mengubah HTML sehingga extractor rusak | Fixture + tes; pesan error jelas; extractor terisolasi |
| Situs memakai DRM / JS berat | Ditolak dengan pesan jelas; di luar cakupan |
| ISP memblokir situs lewat DNS | DoH + fallback antar penyedia (F20–F24) |
| Blokir tingkat IP/SNI tidak teratasi DNS | Pesan jelas; pengguna bisa memakai VPN/Private DNS sistem |
| Isu hak cipta | Disclaimer di layar pertama; tanggung jawab pada pengguna |
| Generic extractor salah ambil iklan/preview | Pilih sumber terbesar, tampilkan pratinjau ukuran sebelum unduh |
| Refaktor merusak fitur Eporner | Pindahkan kode dulu tanpa ubah perilaku, tes sebelum lanjut |

## 9. Fase rilis

1. **Fondasi** — kontrak Extractor, pindahkan Eporner, `Task` generik.
2. **Single download** — Direct file + deteksi URL + UI input baru.
3. **Multi-situs** — Generic HTML + HLS.
3b. **DNS** — resolver DoH + fallback, pengaturan DNS.
4. **Tema** — Material You hijau, ganti `neo.dart`.
5. **Poles** — pengaturan per host, tes, dokumentasi.

Rincian pekerjaan ada di `TASKS.md`; spesifikasi visual ada di `STYLE.md`.

## 10. Pertanyaan terbuka

- Daftar situs prioritas selain Eporner yang ingin didukung pertama?
- Perlu dukungan audio/gambar/dokumen, atau hanya video?
- Folder tujuan: tetap satu folder, atau pilih per unduhan (SAF)?
