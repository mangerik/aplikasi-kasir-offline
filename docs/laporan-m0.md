# Laporan Milestone 0 — Inisialisasi Proyek

**Tanggal:** 11 Agustus 2026
**Acuan:** [prd.md](prd.md) · [architecture.md](architecture.md) · [plan.md](plan.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 0 di `plan.md` selesai dikerjakan. Proyek Flutter
`kasir_warung` sudah bisa dijalankan/dibangun untuk Android (`flutter build apk
--debug` sukses), dengan fondasi arsitektur (struktur folder, tema, formatter,
navigasi 5 tab, skema database Drift lengkap) sesuai `architecture.md`.

`flutter analyze` bersih (0 issue) dan `flutter test` lulus (**29/29 test**).

---

## 2. Yang Dikerjakan

1. **Inisialisasi proyek** — `flutter create --project-name kasir_warung
   --org com.erik.kasir --platforms android .` di direktori yang sudah berisi
   `docs/` & `.git`. `minSdk` diset manual ke **26** (Android 8.0) di
   `android/app/build.gradle.kts` sesuai PRD §6. Ditambahkan izin `CAMERA` +
   `uses-feature` opsional di `AndroidManifest.xml` untuk scan barcode
   (`mobile_scanner`, dipakai mulai Milestone 2).
2. **Struktur folder `lib/`** — persis mengikuti `architecture.md` §3:
   `core/{constants,utils,widgets}`, `data/{db/tables,repositories,services}`,
   `domain/{entities,repositories}`, `features/{pos,products,inventory,
   transactions,reports,settings}/{screens,widgets,providers}`. Subfolder yang
   belum berisi kode (mis. `domain/entities`, `data/repositories`, dan semua
   `widgets/`+`providers/` per fitur) diberi `.gitkeep` agar strukturnya tetap
   ada di repo dan siap diisi mulai Milestone 1.
3. **Dependency** ditambah lewat `flutter pub add` — lihat §3 "Keputusan
   Teknis" untuk versi & alasan pin.
4. **Tema dasar Material 3** (`lib/core/constants/app_theme.dart`, ditopang
   `app_colors.dart` & `app_sizes.dart`): skema warna hijau sebagai brand,
   tipografi diperbesar (mis. `titleLarge` 22, `bodyLarge` 17) untuk
   keterbacaan, dan **semua** jenis tombol (`Elevated/Filled/Outlined/
   Text/IconButton`) diset `minimumSize` **48×48dp** sesuai PRD §6.
5. **Formatter** di `core/utils/`:
   - `CurrencyFormatter` — format Rupiah tanpa desimal, pemisah ribuan titik
     (`Rp12.345`), plus `parse()` untuk input pengguna. 10 unit test.
   - `DateFormatter` — format tanggal/waktu Indonesia (locale `id_ID`) beserta
     konversi epoch millis UTC ⇄ `DateTime` lokal (dipakai konsisten dengan
     kolom waktu di database). 7 unit test.
6. **Navigasi** — `go_router` dengan `StatefulShellRoute.indexedStack`, 5 tab
   bawah: **Kasir · Produk · Riwayat · Laporan · Pengaturan**
   (`lib/core/router/app_router.dart` + `lib/core/widgets/main_shell.dart`).
   Tiap tab berupa layar stub berlabel Bahasa Indonesia
   (`lib/features/*/screens/*_screen.dart`), siap diisi di milestone
   berikutnya. Locale aplikasi dikunci ke `id_ID` lewat
   `flutter_localizations`.
7. **Skema database Drift** (`lib/data/db/`) — seluruh 7 tabel sesuai
   `architecture.md` §4: `categories`, `products`, `sales`, `sale_items`,
   `stock_movements`, `held_carts`, `settings`. `AppDatabase` (`schemaVersion
   = 1`) membuka koneksi lewat `drift_flutter` dengan `PRAGMA
   journal_mode=WAL` saat setup, mengaktifkan `PRAGMA foreign_keys=ON`, dan
   membuat index penting + **partial unique index** pada `products.barcode`
   (unik hanya jika terisi) lewat SQL mentah di `onCreate`. `build_runner`
   sudah dijalankan sampai sukses (`app_database.g.dart` ter-generate).
8. **Seed data** (`lib/data/services/seed_data_service.dart`) — 3 kategori +
   7 produk contoh warung (beras, minyak goreng, gula, teh botol, air
   mineral, indomie, kerupuk), hanya jalan saat `kDebugMode` **dan** hanya
   jika tabel `products` masih kosong (aman dipanggil berulang). Dipicu dari
   `lib/app.dart` saat startup, berjalan di background tanpa memblokir frame
   pertama.
9. **Verifikasi:**
   - `flutter analyze` → 0 issue.
   - `flutter test` → **29/29 lulus** (10 test `CurrencyFormatter`, 7 test
     `DateFormatter`, 7 test `AppDatabase` skema+atomisitas+rollback, 4 test
     `app_test.dart` navigasi 5 tab & label Bahasa Indonesia).
   - `flutter build apk --debug` → **sukses** (baseline nyata bahwa proyek
     benar-benar bisa dikompilasi untuk Android, bukan cuma lulus test host).

---

## 3. Keputusan Teknis

### Versi package (hasil `flutter pub add`, dikunci di `pubspec.yaml`)

| Package | Versi | Catatan |
|---|---|---|
| drift | ^2.34.3 | |
| drift_flutter | ^0.3.1 | pembuka koneksi native + WAL |
| flutter_riverpod | ^2.6.1 | resolver memilih 2.x (3.x tersedia tapi ada konflik transitif) |
| go_router | ^17.5.0 | |
| intl | **0.20.2** (dikunci persis) | diturunkan dari `^0.20.3` karena `flutter_localizations` (SDK Flutter) memin `intl: 0.20.2` persis |
| path_provider | ^2.1.6 | |
| shared_preferences | ^2.5.5 | |
| excel | ^4.0.6 | |
| mobile_scanner | ^7.4.0 | |
| file_picker | **^10.3.3** (bukan versi terbaru 11.x) | lihat penjelasan konflik di bawah |
| share_plus | **^12.0.2** (bukan versi terbaru 13.x) | lihat penjelasan konflik di bawah |
| flutter_localizations | dari Flutter SDK | ditambahkan agar widget Material terlokalisasi `id_ID` (mendukung PRD §6 "Bahasa Indonesia") |
| drift_dev (dev) | ^2.34.5 | |
| build_runner (dev) | ^2.15.1 | |
| flutter_lints (dev) | ^6.0.0 | sudah aktif di `analysis_options.yaml` bawaan `flutter create` |

**Konflik `file_picker` vs `share_plus`:** versi terbaru `file_picker`
(≥8.3.3, <12.0.0-beta.1) mensyaratkan `win32 ^5.9.0`, sedangkan versi terbaru
`share_plus` (≥13.1.0) mensyaratkan `win32 ^6.0.1` — keduanya tak bisa
dipasang bersamaan dalam versi terbarunya. `win32` hanya relevan untuk target
Windows desktop (di luar scope MVP yang Android-only), tapi resolusi
dependency Dart/Flutter bersifat lintas-platform sehingga tetap harus
diselesaikan. Solusi: pin `file_picker: ^10.3.3` + `share_plus: ^12.0.2` —
keduanya versi stabil (bukan beta) terbaru yang saling kompatibel.

Sempat dicoba juga menaikkan `file_picker` ke `^11.0.3`/`>=12.0.0-beta.1`,
tapi versi itu hanya bisa resolve berbarengan dengan `share_plus` versi lama
di 12.x juga (yang sudah dipilih) — atau menyeret `file_picker` ke rilis
**beta** (12.0.0-beta.x) yang tidak diinginkan untuk dependency inti. Versi
final (`file_picker ^10.3.3` → resolve ke `10.3.10`) dipilih karena:
1. Stabil (bukan beta).
2. AAR Android-nya dikompilasi terhadap SDK yang cukup baru — versi awal yang
   dicoba (`8.3.7`, versi minimum yang sudah kompatibel `win32`) ternyata
   masih dikompilasi terhadap `android-34` dan **gagal build** karena
   `flutter_plugin_android_lifecycle` (dependency transitif plugin lain)
   mensyaratkan `compileSdk >= 36`. Setelah dinaikkan ke `10.3.3`
   (resolve `10.3.10`), `flutter build apk --debug` sukses.

### Tipe kolom waktu di Drift

Kolom seperti `created_at`, `updated_at`, `voided_at`, `debt_paid_at`
didefinisikan sebagai `IntColumn` biasa (bukan `DateTimeColumn` bawaan
Drift), berisi **epoch millis UTC** yang disuplai aplikasi lewat
`DateFormatter.toEpochMillis()`. Alasan: `DateTimeColumn` Drift secara
default menyimpan `DateTime` sebagai epoch **detik**, bukan milidetik —
supaya kolom betul-betul "INTEGER epoch millis" sesuai DDL di
`architecture.md` §4, tipe kolom didefinisikan manual.

### Partial unique index & index lain

`@TableIndex` annotation Drift belum mendukung klausa `WHERE` (partial
index) secara langsung, jadi seluruh index (termasuk partial unique index
`products.barcode`) dibuat lewat `customStatement()` SQL mentah di
`AppDatabase.migration.onCreate`, dijalankan setelah `Migrator.createAll()`.

### WAL mode

Diaktifkan lewat `DriftNativeOptions(setup: ...)` yang menjalankan
`PRAGMA journal_mode=WAL;` saat koneksi native dibuka (`drift_flutter`).
Tidak bisa diverifikasi otomatis lewat unit test karena `NativeDatabase.
memory()` (dipakai di semua test) tidak mendukung WAL (SQLite membatasi WAL
hanya untuk file DB sungguhan) — jadi hanya diverifikasi lewat kode
`_openConnection()` yang dipakai runtime, dan cek manual bahwa `flutter build
apk --debug` + kode berjalan tanpa error.

---

## 4. Status Analyze & Test

```
$ flutter analyze
Analyzing aplikasi-kasir...
No issues found! (ran in 2.2s)

$ flutter test
00:01 +29: All tests passed!

$ flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

Rincian 29 test:
- `test/core/utils/currency_formatter_test.dart` — 10 test (format, parse,
  negatif, pembulatan).
- `test/core/utils/date_formatter_test.dart` — 7 test (format tanggal/waktu
  Indonesia, konversi epoch millis pulang-pergi).
- `test/data/db/app_database_test.dart` — 7 test (skema, insert, barcode
  null vs duplikat, transaksi atomik simpan penjualan, **rollback penuh**
  saat salah satu insert dalam transaksi gagal karena FK).
- `test/app_test.dart` — 4 test (5 label tab benar & berurutan, tab awal
  Kasir, perpindahan tab via tap).

---

## 5. Hal yang Belum Selesai / Di Luar Scope M0

- **CI** — item "CI opsional" di checklist sengaja dilewati (memang
  opsional); belum ada workflow GitHub Actions.
- **Repository & entity domain** (`domain/entities`, `domain/repositories`,
  `data/repositories`) — foldernya sudah ada (dengan `.gitkeep`) sesuai
  struktur arsitektur, tapi isinya baru dikerjakan mulai **Milestone 1**
  sesuai urutan di `plan.md`.
- **Widget umum (`core/widgets`)** — baru berisi `MainShell` (navigasi).
  Widget umum lain (tombol besar kustom, empty state, dialog) akan
  ditambahkan sesuai kebutuhan fitur nyata di milestone berikutnya, bukan
  dibuat spekulatif di M0.
- **`flutter test` untuk WAL** tidak bisa 100% diverifikasi otomatis (lihat
  §3) — WAL hanya berlaku untuk file DB sungguhan, bukan `NativeDatabase.
  memory()` yang dipakai di seluruh test suite. Diverifikasi lewat code
  review + build sukses.
- Tidak ada perubahan pada `prd.md` atau `architecture.md` — implementasi
  M0 mengikuti kedua dokumen tersebut apa adanya.

---

## 6. Cara Menjalankan

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # jika tabel Drift berubah
flutter analyze
flutter test
flutter run           # perlu device/emulator Android
flutter build apk --debug
```
