# Laporan Milestone 7 — Mode Gelap & Fondasi Tema Sadar-Konteks

**Tanggal:** 12 Agustus 2026
**Acuan:** [prd-v1.1.md §5](prd-v1.1.md) · [plan-v1.1.md](plan-v1.1.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md) ·
[laporan-m6.md](laporan-m6.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 7 selesai kecuali satu item yang memang
menuntut device fisik. Aplikasi kini bisa **Terang / Gelap / Ikuti
Sistem**, pilihannya bertahan setelah aplikasi ditutup, dan seluruh
layar — kelima tab utama, detail transaksi, layar sukses, form produk,
layar PIN, pemindai barcode — mengambil warnanya dari palet sadar-konteks
`AppPalette`, bukan lagi dari konstanta statis.

Pekerjaan intinya bukan memilih warna, melainkan **membongkar asumsi
bahwa warna tidak bergantung konteks**. `AppColors` adalah
`abstract final class` berisi `static const Color`; nilai `const` tidak
bisa berubah menurut tema. Seluruh pemakaiannya di `lib/features` &
`lib/core/widgets` (51 berkas tersentuh) dipindahkan ke `context.palette`,
dan sekarang ada gerbang otomatis yang menolak kemunduran itu terjadi
lagi di M8–M14.

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **370/370 lulus** (215 dari M0–M6 **tanpa satu pun
  diubah**, AC-5.12 + 155 test baru M7).
- `AppColors.*` di `lib/features/` → **0**. `Colors.white`/`Colors.black`
  telanjang di `lib/features` & `lib/core/widgets` → **0** (satu berkas
  di allowlist berkomentar: struk).
- Tidak ada perubahan skema database. `schemaVersion` tetap **1**,
  backup v1.0 ↔ v1.1 tetap kompatibel penuh.

---

## 2. Apa yang Dibangun

### 2.1 `AppPalette` — palet sebagai `ThemeExtension` (K-5.1)

`lib/core/constants/app_palette.dart` (baru). Seluruh token warna
(netral, brand, aksen, trio semantik, alias domain) menjadi **field
instance**, dengan dua konstruktor `const`:

- `AppPalette.light()` — nilainya **diambil langsung dari `AppColors`**,
  bukan disalin. Ini bukan gaya penulisan melainkan jaminan: mode terang
  tidak mungkin bergeser satu digit pun (diuji terpisah, AC-5.12).
- `AppPalette.dark()` — palet **"Kertas & Daun Malam"** sesuai usulan
  PRD §5.4, dengan dua penyesuaian yang lahir dari uji kontras (§4.1).

Aksesnya dibuat sependek mungkin — `context.palette.ink` — karena
migrasi ratusan pemakaian tidak boleh menyakitkan:

```dart
extension AppPaletteContextX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? const AppPalette.light();
}
```

Fallback ke palet terang dipasang supaya widget yang diuji dengan
`ThemeData()` polos tidak pernah crash.

Empat aturan palet gelap PRD §5.4 diterjemahkan langsung jadi kode dan
**diuji sebagai aturan**, bukan sebagai daftar warna:

| Aturan PRD | Bentuknya di kode | Ditegakkan oleh |
|---|---|---|
| Tidak ada hitam murni | `background #141613`, `surface #1C1F1B` | test "tidak ada hitam murni sebagai permukaan" |
| Kedalaman dari tangga permukaan, bukan shadow | `background < surface < surfaceAlt` | test luminansi tangga permukaan |
| Peran warna brand dibalik | `primary #74CFA4` + `onPrimary #06281B` | test "peran warna brand dibalik" |
| Warna soft jadi gelap-bertint | trio `success/warning/danger/info` versi gelap | uji kontras trio semantik (§4.1) |

### 2.2 `AppTheme.dark()` — satu builder, dua tema

`AppTheme.light()` dan `AppTheme.dark()` sekarang keduanya memanggil
`_build(AppPalette p)` yang sama. Bentuk, radius, tinggi target sentuh,
dan aturan komponen **identik**; yang berbeda hanya nilai token. Ini
yang menjaga mode gelap tetap terasa aplikasi yang sama di ruangan
gelap, bukan tema kedua yang hidup sendiri.

Konsekuensi teknis yang perlu dicatat: `AppTypography.textTheme()`
sekarang menerima palet (`textTheme(AppPalette palette)`), sehingga
seluruh `TextTheme` ikut gelap tanpa satu pun layar perlu tahu.

`ThemeData.extensions` diisi `[p]` — inilah titik tempat
`context.palette` mengambil nilainya.

### 2.3 Bayangan & dekorasi sadar-tema

`AppShadows.of(context)` mengembalikan `AppShadowSet` sesuai tema. Versi
gelap memakai alpha jauh lebih rendah dan **bersifat dekoratif saja** —
di atas latar gelap shadow praktis tak terlihat, jadi hierarki dibawa
tangga permukaan + garis `border` (PRD §5.4 aturan 2). Konstanta lama
(`AppShadows.level1` dst.) dipertahankan `@Deprecated` selama masa
migrasi, dan pemakaiannya dijaga gerbang otomatis.

`AppDecorations.card/floating/tonal` kini menerima `BuildContext`
sebagai argumen pertama dan mengambil warna dari `context.palette`.

### 2.4 `AppTone.colorsOf(context)` (K-5.6)

Getter lama `tone.colors` dipertahankan tapi ditandai `@Deprecated` dan
**dilepas dari barrel `app_widgets.dart`** — cara paling murah untuk
memastikan kode baru tidak sengaja memakainya. Ditambah
`tone.resolve(AppPalette)` untuk kode yang sudah memegang palet (dipakai
uji kontras) dan `tone.fillOf(context)` untuk warna isi pekat.

### 2.5 Mode tema & persistensi (K-5.2)

`lib/features/settings/providers/theme_providers.dart` (baru):
`themeModeProvider` (`Notifier<ThemeMode>`) dibaca `MaterialApp.router`
lewat `themeMode:`. Nilainya disimpan di **`shared_preferences`** kunci
`theme_mode`, **bukan** tabel `settings` — sehingga restore backup di HP
lain tidak menyeret tema HP asal (AC-5.4), dan nilainya bisa dimuat di
`main()` sebelum `runApp()` (AC-5.5).

```dart
final prefs = await SharedPreferences.getInstance();   // SEBELUM runApp
runApp(ProviderScope(
  overrides: [themeModeStoreProvider.overrideWithValue(
    SharedPrefsThemeModeStore(prefs))],
  child: const KasirApp(),
));
```

Detail penting soal bentuk abstraksinya ada di §3.1.

### 2.6 Kartu "Tampilan" di Pengaturan

`lib/features/settings/widgets/appearance_section.dart` (baru), ditempatkan
di **paling atas** layar Pengaturan sebagai grup baru "TAMPILAN — Mata
Kamu" di atas grup "IDENTITAS".

`SegmentedButton` tiga pilihan (Terang / Gelap / Ikuti Sistem), tinggi
minimum `AppSizes.minTouchTarget` (≥48dp), masing-masing berikon,
ditutup kalimat keterangan *"Ikuti Sistem mengikuti pengaturan tema HP
Anda."*

Dua keputusan desain kecil di sini:

- **Letaknya di atas, bukan di bawah**, karena ini satu-satunya setelan
  yang efeknya terlihat seketika di layar yang sedang dipandang — kartu
  itu sendiri berubah warna di depan mata pengguna begitu ditekan. Kartu
  ikonnya pun ikut berganti (matahari ↔ bulan) sebagai konfirmasi.
- **Tidak ada pintasan di AppBar layar lain** (sesuai PRD §5.3.A):
  mengganti tema bukan aksi harian, dan ikon tambahan di AppBar kasir
  melanggar prinsip "satu titik fokus".

### 2.7 Migrasi 44 berkas layar

Urutan mengikuti plan: `core/widgets/` lebih dulu (7 berkas — ini
menyelesaikan sebagian besar permukaan sekaligus karena semua layar
memakainya), lalu `pos` → `products` → `transactions` → `reports` →
`settings` → `inventory`.

Selain penggantian mekanis `AppColors.x` → `context.palette.x`, ada
lima titik yang **tidak boleh** diterjemahkan apa adanya dan ditangani
manual:

1. **Teks di atas tombol berisi.** Semua `AppColors.onDark` di dalam
   `FilledButton`/spinner diganti `context.palette.onPrimary` — di mode
   gelap tombol utamanya hijau TERANG, jadi tulisannya harus gelap.
   Tombol merah (`danger`) memakai `colorScheme.onError`.
2. **`AppPill`/`AppIconBadge` berisi penuh.** Latarnya `c.fg` yang di
   mode gelap justru terang; teks di atasnya kini `palette.background`.
   Tanpa ini pill "Lunas" jadi hijau muda bertulis putih — hilang total
   (AC-5.11).
3. **SnackBar & tooltip.** Memakai `surfaceDark` yang *inversi*; teksnya
   memakai token baru `onSurfaceDark` yang ikut terbalik.
4. **`ReceiptWidget`** — dipaksa terang (§2.8).
5. **Pemindai barcode** — dipaksa gelap (§3.4).

### 2.8 Struk dipaksa tetap terang (K-5.3, AC-5.7)

`ReceiptWidget` membungkus dirinya sendiri:

```dart
return Theme(data: AppTheme.light(), child: _paperSheet(profile));
```

Pembungkusnya diletakkan **di dalam widget struk, bukan di pemanggil** —
supaya setiap layar yang menampilkan struk (sukses transaksi, detail
transaksi, dan nanti pratinjau cetak M8) otomatis benar tanpa perlu
mengingat aturannya. Warna kertas & tintanya adalah konstanta bernama
`ReceiptWidget.paper` / `inkOnPaper`, justru karena keduanya **tidak
boleh** ikut tema; keduanya satu-satunya isi allowlist gerbang AC-5.6.

---

## 3. Keputusan Teknis

Semua keputusan di bawah juga dicatat di bagian "Catatan Keputusan"
[plan-v1.1.md](plan-v1.1.md).

### 3.1 K-5.7 (baru) — `ThemeModeStore`, bukan `SharedPreferences` mentah

Rancangan pertama menyuntikkan `SharedPreferences` langsung sebagai
provider yang `throw` bila tidak di-override. Hasilnya: **12 test M0–M6
gagal serentak** karena setiap widget test membangun `KasirApp` tanpa
tahu-menahu soal tema. Memperbaikinya dengan mengubah test justru
melanggar AC-5.12 ("seluruh test lama lulus **tanpa diubah**").

Solusinya sebuah antarmuka tipis:

```dart
abstract interface class ThemeModeStore {
  ThemeMode read();                    // sinkron — dipakai frame pertama
  Future<void> write(ThemeMode mode);
}
```

`SharedPrefsThemeModeStore` dipasang di `main()`; `InMemoryThemeModeStore`
jadi **default provider**. Efek sampingnya disengaja: kalau suatu saat
`main()` lupa meng-override, aplikasi tetap berjalan bertema Terang dan
pilihan pengguna hanya tidak bertahan — jauh lebih baik daripada crash
karena fitur tampilan. Bonusnya, widget test mode gelap tinggal
`InMemoryThemeModeStore(ThemeMode.dark)`.

`read()` sengaja sinkron: ia dipakai untuk frame pertama, jadi tidak
boleh ada `await` di jalur itu (AC-5.5).

### 3.2 Token `onPrimary`, `onAccent`, `onSurfaceDark` ditambahkan

PRD §5.4 menyebut aturannya di catatan tabel ("teks di atasnya =
`#06281B`, bukan putih") tapi tidak memberi token. Tanpa token, setiap
layar harus mengingat aturan itu sendiri — sumber "pulau putih"
berikutnya.

`onSurfaceDark` menutup jebakan yang paling halus: `surfaceDark` adalah
permukaan **inversi**, jadi teks di atasnya harus ikut terbalik.
Implementasi pertama memakai `ink` dan langsung tertangkap uji kontras —
di mode gelap `ink` juga terang, sehingga SnackBar jadi terang-di-atas-
terang, rasio **1.00:1**. Ini persis jenis cacat yang tidak akan pernah
terlihat di widget test biasa.

### 3.3 `dangerBorder` & `infoBorder` dipromosikan jadi token

Di v1.0 keduanya nilai mentah yang ditanam langsung di dalam
`AppToneColorsX` (`Color(0xFFF3C9C5)`, `Color(0xFFC3DAEA)`). Mode gelap
membutuhkan pasangannya, dan token setengah jalan tidak bisa diuji
kontras.

### 3.4 Pemindai barcode dipaksa `AppTheme.dark()` di kedua mode

Chrome-nya mengambang di atas pratinjau kamera yang selalu gelap. Ini
bukan pengecualian terhadap mode gelap melainkan penerapannya: warnanya
tetap datang dari `context.palette`, hanya paletnya yang dipilih tetap.
Bonusnya, tombol lampu aktif kini hijau terang berikon gelap — lebih
terbaca dari versi v1.0 yang memakai hijau tua di atas latar gelap.

### 3.5 Dua pengecualian eksplisit di uji kontras, bukan satu

PRD §5.4 menyebut nilai tokennya "titik awal yang harus diverifikasi
kontrasnya oleh uji otomatis, bukan angka final yang sakral" — dan uji
itu memang menemukan dua hal:

- **`inkTertiary`** sudah diantisipasi PRD. Ambang yang dipakai **2.8:1**
  (bukan 3:1) karena nilai terangnya `#8A928B` = 2.86:1 berasal dari v1.0
  dan tidak boleh digeser oleh AC-5.12. Versi gelapnya (`#7A8078`) justru
  jauh lebih longgar (~4.1:1). Test juga menegaskan sebaliknya — bahwa
  token ini memang **di bawah** 4.5:1, supaya "lolos" tidak pernah
  disalahartikan sebagai "aman untuk teks kecil".
- **`accent` `#D97E27`** ternyata juga di bawah 3:1 di atas kertas
  (2.70–2.97:1) sejak v1.0. Nilainya tidak diubah. Yang menjaga
  keterbacaan bukan warnanya melainkan **aturan pemakaiannya**, dan
  aturan itu yang diuji: `accent` hanya boleh jadi ISI (track progress,
  latar chip), sedangkan teks/ikon aksen memakai `accentText` yang wajib
  lolos 4.5:1 di kedua tema.

### 3.6 Gerbang AC-5.6 dijadikan test, bukan grep manual

`test/core/constants/no_hardcoded_colors_test.dart` memindai
`lib/features` & `lib/core/widgets` setiap `flutter test`. Alasannya
lugas: M8–M14 masih akan menambah banyak layar baru (kartu printer,
sheet perangkat, wizard impor 5 langkah, layar aktivasi), dan gerbang
yang bergantung pada ingatan orang akan bocor. Allowlist-nya berkomentar
alasan, dan **panjang allowlist itu sendiri dibatasi test** (maks. 3
berkas) supaya penambahannya memaksa diskusi alih-alih menjadi kebiasaan.

---

## 4. Hasil Verifikasi

### 4.1 Uji kontras otomatis (AC-5.8) — 135 test

`test/core/constants/app_palette_contrast_test.dart` menghitung rasio
WCAG 2.1 untuk **setiap** pasangan (teks/ikon, latar) yang benar-benar
muncul di aplikasi, di kedua palet:

- teks netral (`ink`, `inkSecondary`) di atas ketiga permukaan;
- warna brand & semantik yang dipakai **sebagai teks** (`primary`,
  `accentText`, `successText`, `warningText`, `dangerText`, `infoText`)
  di atas ketiga permukaan — ambang 4.5:1;
- warna isi (`success`, `warning`, `danger`, `info`) sebagai ikon —
  ambang 3:1;
- trio semantik: teks di atas latar lembutnya sendiri;
- teks di atas permukaan berwarna (`onPrimary`, `onDark`, `onAccent`,
  `onSurfaceDark`);
- seluruh varian `AppPill` — berisi penuh maupun tonal — per `AppTone`.

Uji ini menemukan dan memaksa perbaikan dua hal sebelum satu piksel pun
terlihat manusia: `onSurfaceDark` yang salah arah (§3.2, 1.00:1) dan dua
pengecualian yang harus dinyatakan eksplisit (§3.5). Nilai usulan PRD
§5.4 selebihnya lolos apa adanya.

### 4.2 Widget test mode gelap (AC-5.7, AC-5.10, AC-5.11) — 7 test

`test/features/dark_mode_screens_test.dart`:

1. Kelima tab utama (Kasir, Produk, Riwayat, Laporan, Setelan) —
   `brightness == dark`, `scaffoldBackgroundColor == AppPalette.dark()
   .background`, dan ekstensi `AppPalette` gelap benar-benar terpasang.
2. Kartu "Tampilan" — tepat tiga pilihan; menekan "Gelap" mengubah tema
   **seketika tanpa restart**, menekan "Terang" mengembalikannya
   (AC-5.1).
3. Detail transaksi di mode gelap + pill status tetap membawa **label
   teks** ("Hutang"), bukan cuma warna (AC-5.11).
4. Form produk bertema gelap.
5. Layar PIN bertema gelap.
6. Layar sukses transaksi gelap, **tapi struk di dalamnya tetap kertas
   putih**.
7. Struk identik byte-per-byte warnanya di mode terang & gelap (AC-5.7).

### 4.3 Persistensi tema (AC-5.2, AC-5.4) — 9 test

`test/features/settings/theme_mode_provider_test.dart`: serialisasi
bolak-balik, fallback ke Terang untuk nilai kosong/tak dikenal,
pilihan bertahan setelah "buka ulang aplikasi" (container baru dari
`SharedPreferences` yang sama), dan penegasan bahwa kuncinya berada di
`shared_preferences` — bukan tabel `settings`.

### 4.4 Gerbang sapu bersih (AC-5.6) — 4 test

Nol pelanggaran untuk `AppColors.*`, `Colors.white`/`Colors.black`
telanjang, dan `AppShadows.level*` statis.

### 4.5 Analyze & test

```
$ flutter analyze
Analyzing aplikasi-kasir...
No issues found! (ran in ~3s)

$ flutter test
00:12 +370: All tests passed!
```

Rincian 155 test baru:

| Berkas | Test |
|---|---|
| `test/core/constants/app_palette_contrast_test.dart` | 135 |
| `test/features/settings/theme_mode_provider_test.dart` | 9 |
| `test/features/dark_mode_screens_test.dart` | 7 |
| `test/core/constants/no_hardcoded_colors_test.dart` | 4 |

215 test M0–M6 lulus **tanpa satu baris pun diubah** (AC-5.12).

Catatan kecil: `product_repository_impl_search_performance_test.dart`
(uji performa 5.000 produk, M6) sesekali melewati ambang 100 ms saat
seluruh suite berjalan paralel di mesin yang sibuk, dan lulus stabil
bila dijalankan sendiri. Ini karakteristik uji performa yang sudah ada
sejak M6, bukan regresi M7 — tidak ada perubahan di jalur query.

### 4.6 Cakupan perubahan

51 berkas dimodifikasi (+787 / −506), 3 berkas kode baru
(`app_palette.dart`, `theme_providers.dart`, `appearance_section.dart`),
4 berkas test baru. Tidak ada perubahan skema database, tidak ada
dependency baru (`shared_preferences` sudah ada sejak M0).

---

## 5. Sisa Pekerjaan Manual (Device Fisik)

Satu item checklist M7 sengaja **dibiarkan tidak tercentang** karena
tidak ada device Android fisik/emulator di environment ini:

1. **Tidak ada kedip putih saat cold start mode gelap (AC-5.5).**
   Jalurnya sudah benar secara struktural — `SharedPreferences` dimuat
   sebelum `runApp()`, jadi frame pertama sudah memegang `themeMode`
   yang benar — tapi "tidak berkedip" hanya bisa dibuktikan dengan mata
   di device sungguhan (termasuk transisi dari splash native hijau
   `#1B7A43` yang sengaja sama di kedua tema, K-5.5).
2. **"Ikuti Sistem" mengikuti perubahan tema Android tanpa restart
   (AC-5.3).** Ditangani `MaterialApp.themeMode: ThemeMode.system`
   (mekanisme bawaan Flutter), tapi belum dikonfirmasi dengan
   benar-benar mengubah setelan tema di HP saat aplikasi terbuka.
3. **Status bar & ikon sistem terbaca di kedua tema (AC-5.9).**
   `SystemUiOverlayStyle` sudah dibalik di dua lapis — `AppBarTheme`
   untuk layar ber-AppBar, dan `AnnotatedRegion` di `MaterialApp.builder`
   untuk layar tanpa AppBar (PIN, sukses transaksi). Rendering pita
   status sungguhan hanya bisa dilihat di device.
4. **Keterbacaan angka & pill status di HP kecil dalam ruangan gelap
   (AC-5.11).** Rasio kontrasnya sudah dihitung otomatis (§4.1); yang
   belum adalah pengamatan mata di layar murah pada kondisi cahaya
   sungguhan — justru kondisi yang jadi alasan fitur ini ada.

Ditambah satu item yang bisa dikerjakan kapan saja tapi bukan bagian
M7: verifikasi visual mode gelap di tablet (breakpoint 600dp, layar
Kasir dua panel).

---

## 6. Dampak untuk Milestone Berikutnya

- **Aturan baru berlaku sejak sekarang**: layar baru M8–M14 **dilarang**
  memakai `AppColors.*` langsung. Ditegakkan otomatis oleh
  `no_hardcoded_colors_test.dart`, bukan oleh review manual.
- Layar-layar baru M8 (kartu printer, sheet perangkat, pratinjau cetak),
  M9 (wizard impor 5 langkah), dan M10 (layar aktivasi, layar lisensi
  berakhir) lahir sudah sadar-tema — tidak perlu dimigrasi dua kali.
  Inilah alasan M7 didahulukan.
- **Pratinjau cetak struk M8 wajib memakai `ReceiptWidget`** atau
  meniru pola pembungkus `Theme(data: AppTheme.light(), ...)`-nya;
  PRD §5.3.D menempatkannya sebagai permukaan kedua yang dipaksa terang.
- Bila M8 menambah warna baru, tambahkan tokennya ke `AppPalette`
  (kedua konstruktor) — uji kontras akan otomatis menolak pasangan yang
  tidak terbaca.

---

## 7. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/core/constants/app_palette_contrast_test.dart   # uji kontras saja
flutter test test/features/dark_mode_screens_test.dart            # layar mode gelap
flutter run                                                        # perlu device Android
```

Mengubah tema saat aplikasi berjalan: **Pengaturan → Tampilan → Terang /
Gelap / Ikuti Sistem**.
