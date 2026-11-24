# TASKS — bulk_dl

Rujukan: `PRD.md` (apa), `STYLE.md` (tampilan). Urutan fase sebaiknya diikuti
karena fase 1 adalah fondasi yang lain.

Legenda: `[ ]` belum · `[~]` jalan · `[x]` selesai · **(F#)** = kebutuhan di PRD.

## Fase 0 — Persiapan

- [ ] T0.1 Commit/rapikan perubahan yang belum di-commit
  (`main.dart`, `queue.dart`, `scraper.dart`, `tool/mock_server.js`).
- [ ] T0.2 Tulis tes karakterisasi untuk perilaku sekarang: parse playlist
  Eporner (fixture HTML), `Scraper.candidates/pick`, penamaan file. Jadi jaring
  pengaman sebelum refaktor.
- [ ] T0.3 Tambah `docs/` ke repo; perbarui `README.md` (nama, tujuan, cara jalan).

## Fase 1 — Fondasi extractor (F6, F8, F12)

- [ ] T1.1 Buat `lib/extractors/extractor.dart`: `abstract class Extractor`,
  `enum UrlKind { file, video, playlist }`, `MediaSource` (url, kualitas, codec,
  ukuran, tipe: direct/hls), `VideoItem` generik (tambah `extractorId`, `sourceUrl`).
- [ ] T1.2 Buat `lib/extractors/registry.dart`: daftar extractor + `pick(Uri)`
  (spesifik → direct → generic).
- [ ] T1.3 Pindahkan logika `scraper.dart` ke `EpornerExtractor` tanpa ubah
  perilaku; `Scraper` jadi lapisan tipis (cache link, throttle `_maxParallel`).
- [ ] T1.4 Ubah `Task` di `queue.dart` agar menyimpan `extractorId`, `sourceUrl`,
  `kind`; migrasi format persist lama (`_persist/restore`) agar antrean lama
  tetap terbaca.
- [ ] T1.5 Ganti cookie global jadi cookie per host (F11); migrasi pengaturan lama.
- [ ] T1.6 Jalankan tes T0.2 — harus tetap hijau.

## Fase 2 — Single download (F1–F5, F14)

- [ ] T2.1 `UrlClassifier`: dari URL → `UrlKind` (ekstensi, lalu `HEAD` untuk
  `Content-Type`, lalu tanya extractor `classify`).
- [ ] T2.2 `DirectFileExtractor`: `HEAD` (ukuran, nama dari `Content-Disposition`,
  `Accept-Ranges`), hasilkan satu `MediaSource`.
- [ ] T2.3 Dukung resume `Range` di `queue.dart` untuk direct file; fallback ke
  unduh ulang bila server tidak mendukung.
- [ ] T2.4 Sanitasi nama file + hindari tabrakan (`nama (1).ext`) (F14).
- [ ] T2.5 Alur single: URL → klasifikasi → langsung tambah ke antrean, tanpa
  layar daftar; dialog kecil untuk ganti nama.
- [ ] T2.6 Input multi-URL (satu per baris) (F1): klasifikasi paralel, gabung
  hasil ke antrean/daftar.
- [ ] T2.7 Share sheet: link yang diterima lewat share ikut alur klasifikasi baru.
- [ ] T2.8 Tes: klasifikasi URL, `HEAD` parsing, nama file, resume (mock server
  `tool/mock_server.js` — tambah endpoint `Range` dan file langsung).

## Fase 3 — Banyak situs (F7, F9, F10)

- [ ] T3.1 `GenericHtmlExtractor`: cari `og:video`, `<video>/<source>`,
  JSON-LD `VideoObject.contentUrl`, tautan ke file media; urutkan, buang
  kandidat kecil (iklan/preview) lewat `HEAD` ukuran.
- [ ] T3.2 Dukung playlist generik: halaman dengan banyak tautan video →
  daftar `VideoItem` (heuristik: kartu dengan `<a>` + `<img>`), dengan opsi
  manual "pakai pola link ini" bila heuristik meleset.
- [ ] T3.3 `HlsExtractor`: parse master/media playlist `.m3u8`, pilih varian
  sesuai kualitas, unduh segmen paralel kecil, gabung ke satu file; dukung
  AES-128 bila kunci ada di manifest; tolak DRM dengan pesan jelas.
- [ ] T3.4 Pesan error spesifik dan tombol salin log untuk "tidak ada media"
  (F9).
- [ ] T3.5 Tambah minimal 2 extractor situs spesifik selain Eporner setelah
  pengguna menentukan daftar situs (lihat pertanyaan terbuka PRD).
- [ ] T3.6 Tes tiap extractor dengan fixture HTML/m3u8 (N6).

## Fase 3B — DNS kustom / anti blokir (F20–F25)

Dikerjakan setelah Fase 1 (butuh satu titik pembuatan `Dio`), bisa paralel dengan Fase 2–3.

- [ ] T3B.1 Buat satu `HttpFactory` (`lib/net/http_factory.dart`) yang membuat
  semua `Dio`; hapus `Dio(...)` yang tersebar di scraper/queue.
- [ ] T3B.2 `DohResolver` (`lib/net/doh.dart`): kueri A/AAAA ke endpoint DoH
  (`https://cloudflare-dns.com/dns-query`, `https://dns.google/resolve`,
  `https://dns.quad9.net:5053/dns-query`) memakai format JSON; cache dengan TTL.
  Endpoint DoH diakses lewat IP langsung (mis. `1.1.1.1`) agar tidak bergantung
  DNS sistem.
- [ ] T3B.3 Pasang resolver ke `Dio` lewat `IOHttpClientAdapter.createHttpClient`
  dengan `HttpClient.connectionFactory`: sambung ke IP hasil DoH, TLS tetap
  memakai hostname asli (SNI + validasi sertifikat). Verifikasi di perangkat
  bahwa SNI benar dan sertifikat tidak dilonggarkan.
- [ ] T3B.4 Strategi fallback (F23): DNS sistem → DoH penyedia terpilih → DoH
  penyedia lain. Deteksi blokir: gagal resolve, IP loopback/`0.0.0.0`, atau
  IP halaman blokir ISP yang dikenal.
- [ ] T3B.5 Pengaturan DNS di `shared_preferences`: mode (sistem/Cloudflare/
  Google/Quad9/kustom) + nilai kustom; default **Cloudflare DoH dengan fallback
  ke sistem**.
- [ ] T3B.6 UI pengaturan DNS (list radio M3) + tombol "Tes DNS" yang
  me-resolve host contoh dan menampilkan IP + penyedia yang dipakai.
- [ ] T3B.7 Pesan error khusus (F25): bila DNS sudah benar tapi koneksi tetap
  gagal/di-reset, tampilkan "kemungkinan blokir IP/SNI, coba VPN atau Private
  DNS sistem".
- [ ] T3B.8 Terapkan resolver ke unduhan latar belakang (foreground service
  isolate) dan segmen HLS, bukan hanya request halaman.
- [ ] T3B.9 Tes: parsing respons DoH (fixture JSON), cache TTL, urutan fallback,
  deteksi IP blokir; mock server untuk resolver palsu.

## Fase 4 — Tema Material You hijau (F16–F19, `STYLE.md`)

- [ ] T4.1 Tambah dependency `dynamic_color`; `flutter pub get`.
- [ ] T4.2 Buat `lib/theme.dart` (seed `#2E7D32`, `buildTheme`, komponen tema).
- [ ] T4.3 `App`: `DynamicColorBuilder` + pengaturan tema (terang/gelap/sistem)
  dan toggle warna dinamis; simpan di `shared_preferences`.
- [ ] T4.4 Pecah `main.dart` (839 baris) menjadi layar: `home_screen.dart`,
  `picker_screen.dart`, `queue_screen.dart`, `settings_screen.dart`.
- [ ] T4.5 Ganti widget `Neo*` dengan komponen M3 per layar (Beranda → Pilih →
  Antrean → Pengaturan).
- [ ] T4.6 `NavigationBar` + `FloatingActionButton.extended`.
- [ ] T4.7 Kartu ringkasan total (persen, kecepatan, ETA) di antrean.
- [ ] T4.8 Hapus `neo.dart` dan semua referensi `Neo*`.
- [ ] T4.9 Cek kontras terang/gelap dan target sentuh 48dp (checklist `STYLE.md` §10).

## Fase 5 — Poles dan rilis

- [ ] T5.1 Layar pengaturan: kualitas, paralel, Wi-Fi saja, tema, warna dinamis,
  DNS, cookie per situs.
- [ ] T5.2 Disclaimer hak cipta di peluncuran pertama.
- [ ] T5.3 Uji performa antrean 500 item (N1) dan foreground service dengan
  layar mati (N2).
- [ ] T5.4 `flutter analyze` bersih; semua tes lulus.
- [ ] T5.5 Uji manual di perangkat Android 8, 12, dan terbaru.
- [ ] T5.6 Naikkan versi di `pubspec.yaml`; build APK rilis.

## Urutan dan ketergantungan

```
F0 → F1 → F2 → F3
        ↘ ↘
         ↘ F3B (DNS, setelah T1.x; paralel dengan F2/F3)
          F4 (bisa paralel dengan F2/F3 setelah T4.4 memecah main.dart)
F2+F3+F3B+F4 → F5
```

## Definisi selesai (tiap tugas)

- Kode lulus `flutter analyze`.
- Ada tes untuk logika baru (bukan UI murni).
- Tidak ada regresi pada tes yang ada.
- Perilaku fitur lama (antrean, retry, Wi-Fi saja, resume) tetap sama.
