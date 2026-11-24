# STYLE — Material You, hijau dominan

Menggantikan tema neo-brutalist (`lib/neo.dart`, seed kuning) dengan Material 3.

## 1. Prinsip

- Ikuti Material 3 / Material You: bentuk membulat, tonal surface, elevasi
  rendah, warna dari `ColorScheme`, bukan hex tersebar di widget.
- **Hijau dominan**: primary, primaryContainer, dan aksen utama hijau; netral
  mengikuti tint hijau dari seed.
- Warna dinamis di Android 12+ memakai `dynamic_color`; jika tidak tersedia atau
  pengguna mematikannya, pakai seed hijau di bawah.
- Tidak ada widget kustom yang melawan tema (hapus `NeoBox`, `NeoButton`,
  `NeoCheck`, `NeoTag`, `NeoProgress`; ganti dengan widget bawaan M3).

## 2. Warna

Seed: `Color(0xFF2E7D32)` (hijau). Skema dibuat dengan:

```dart
ColorScheme.fromSeed(
  seedColor: const Color(0xFF2E7D32),
  brightness: brightness,
  dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
)
```

Perkiraan hasil (acuan visual, nilai final dari generator):

| Peran | Terang | Gelap |
|---|---|---|
| primary | `#1B6D2F` | `#7FDA8B` |
| onPrimary | `#FFFFFF` | `#00390F` |
| primaryContainer | `#A0F6A6` | `#005319` |
| onPrimaryContainer | `#002106` | `#A0F6A6` |
| secondaryContainer | `#D4E8D1` | `#3B4B3A` |
| surface | `#F7FBF1` | `#10140F` |
| surfaceContainer | `#EBEFE6` | `#1C201B` |
| error | `#BA1A1A` | `#FFB4AB` |

Aturan pemakaian:

- Aksi utama (Unduh): `FilledButton` (primary).
- Aksi sekunder (Tempel, Filter): `FilledButton.tonal` atau `OutlinedButton`.
- Kartu tugas: `Card` varian filled/tonal (`surfaceContainerHigh`), bukan outline tebal.
- Status: selesai = primary, gagal = error, antre/jeda = `onSurfaceVariant`.
- Jangan memakai warna di luar `Theme.of(context).colorScheme`.
- Tambahkan tidak lebih dari satu warna ekstra (peringatan Wi-Fi): pakai `tertiary`.

## 3. Tipografi

- Font: Roboto Flex atau default sistem; tidak perlu paket font tambahan.
- Skala M3:

| Pemakaian | Style |
|---|---|
| Judul layar | `headlineSmall` |
| Judul kartu / judul video | `titleMedium` (maks 2 baris, ellipsis) |
| Isi, status | `bodyMedium` |
| Kecepatan, ETA, ukuran | `labelMedium`, `tabularFigures` |
| Tombol | `labelLarge` |

- Tidak lagi memakai huruf kapital paksa (`MB/S` jadi `MB/s`, gaya neo dihapus).

## 4. Bentuk, jarak, elevasi

- Radius: kartu 16dp, tombol pill (stadium), field input 28dp (search bar) atau 12dp.
- Kelipatan jarak 4dp; padding layar 16dp; jarak antar kartu 8dp.
- Elevasi: tonal (warna surface), bayangan minimal; tanpa border 2–3dp hitam.
- Target sentuh minimal 48×48dp.

## 5. Komponen

| Kebutuhan | Komponen M3 |
|---|---|
| Input URL | `SearchBar` / `TextField` filled + tombol tempel (trailing icon) |
| Pilih mode | `SegmentedButton` (Otomatis · Single · Playlist) |
| Filter judul | `SearchBar` kecil atau `FilterChip` |
| Pilih kualitas | `DropdownMenu` atau `ChoiceChip` |
| Daftar video | `ListView` + `ListTile` dalam `Card`, `Checkbox` leading |
| Progres tugas | `LinearProgressIndicator` (M3 expressive bila tersedia), tinggi 6dp, ujung bulat |
| Progres total | Kartu ringkas di atas antrean: persen, kecepatan, ETA |
| Tag (AV1, ukuran) | `Chip` kecil / `AssistChip` |
| Navigasi | `NavigationBar` (Beranda · Antrean · Pengaturan) |
| Aksi cepat antrean | `FloatingActionButton.extended` ("Tambah") |
| Konfirmasi/error | `SnackBar` floating, `AlertDialog` M3 |
| Pengaturan | `ListTile` + `Switch`, `Slider` untuk paralel |

## 6. Layar

1. **Beranda** — field URL besar dengan tombol tempel, `SegmentedButton` mode,
   tombol "Analisis"/"Unduh". Di bawahnya riwayat link terakhir.
2. **Pilih video** — `SliverAppBar` collapsing, pencarian judul, "pilih semua",
   `BottomAppBar` dengan jumlah terpilih + tombol Unduh.
3. **Antrean** — kartu ringkasan total di atas, lalu daftar tugas dengan
   progres, kecepatan, tombol batal/ulang; menu overflow "Bersihkan selesai".
4. **Pengaturan** — kualitas, paralel, Wi-Fi saja, warna dinamis (on/off), tema
   (terang/gelap/sistem), **DNS** (list radio: Sistem, Cloudflare, Google,
   Quad9, Kustom + tombol "Tes DNS"), cookie per situs.

## 7. Gerak

- Gunakan transisi bawaan M3 (container transform / shared axis) seperlunya.
- Durasi 200–300ms, kurva `Easing.emphasized`.
- Hormati `MediaQuery.disableAnimations`.

## 8. Mode gelap

- Seed sama, `brightness: Brightness.dark`.
- Ikuti sistem secara default; pengguna bisa memaksa terang/gelap.
- Pastikan kontras teks minimal 4.5:1 (cek `onSurfaceVariant` pada kartu).

## 9. Implementasi

- Tambah dependency `dynamic_color`.
- Buat `lib/theme.dart`:

```dart
const _seed = Color(0xFF2E7D32);

ThemeData buildTheme(ColorScheme scheme) => ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  cardTheme: CardThemeData(
    elevation: 0,
    color: scheme.surfaceContainerHigh,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    linearMinHeight: 6,
    borderRadius: BorderRadius.all(Radius.circular(3)),
  ),
);
```

- `App` membungkus `MaterialApp` dengan `DynamicColorBuilder`:
  gunakan `lightDynamic`/`darkDynamic` bila ada dan pengaturan aktif,
  selain itu `ColorScheme.fromSeed(seedColor: _seed, ...)`.
- Hapus `neo.dart` setelah semua pemakaian diganti.

## 10. Checklist penerimaan visual

- [ ] Tidak ada hex warna di luar `theme.dart`.
- [ ] Terang dan gelap sama-sama terbaca (kontras AA).
- [ ] Warna dinamis berganti saat wallpaper diganti (Android 12+).
- [ ] Semua tombol ≥ 48dp.
- [ ] Tidak ada sisa komponen `Neo*`.
