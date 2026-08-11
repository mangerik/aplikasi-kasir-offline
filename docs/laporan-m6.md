# Laporan Milestone 6 — Polish & Rilis

**Tanggal:** 11 Agustus 2026
**Acuan:** [prd.md](prd.md) · [architecture.md](architecture.md) · [plan.md](plan.md) ·
[laporan-m4.md](laporan-m4.md) · [laporan-m5.md](laporan-m5.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 6 di `plan.md` selesai: kedua perbaikan
integrasi lintas-milestone dari Tugas A (wiring threshold stok menipis
global & snapshot laba kotor export Excel) terverifikasi, empty
state/pesan error Bahasa Indonesia diaudit di semua layar, ukuran
sentuh/font/kontras direview, test performa pencarian produk & regresi
alur kasir (tunai/hutang/void) ditambahkan, ikon aplikasi + splash native
+ nama tampilan "Kasir Warung" dibuat, build release APK (split per-ABI,
semuanya < 40 MB) & App Bundle sukses dengan R8/shrinkResources aktif,
dan versi ditandai `v1.0.0`.

`flutter analyze` bersih (0 issue). `flutter test` → **207/207 test
lulus** (196 dari M0–M5 + 11 test baru Milestone 6).

Pekerjaan ini dikerjakan **paralel** dengan agent lain pada sesi
Claude Code TERPISAH tapi working directory Git yang SAMA (bukan
worktree) — lihat §6 untuk detail koordinasi. Tugas A (wiring threshold
& snapshot laba kotor) diselesaikan LEBIH DULU oleh agent paralel
tersebut (commit `dd43582`) — sudah diverifikasi identik/kompatibel
dengan analisis independen laporan ini sebelum lanjut ke Tugas B.

---

## 2. Tugas A — Perbaikan Integrasi (Verifikasi)

### 2.1 Threshold stok menipis global -> UI produk & kasir

**Sudah diwire** (dikerjakan oleh agent paralel, commit `dd43582`,
diverifikasi independen oleh laporan ini): `Product.isLowStockWith
(double defaultThreshold)` (method baru, melengkapi `isLowStock` lama
yang tetap dipertahankan untuk kompatibilitas mundur) dipakai di
`ProductListTile` (tab Produk), `_ProductCard` (grid Kasir), dan
`_LowStockTile` (layar Stok Menipis) — ketiganya menerima threshold dari
`lowStockDefaultThresholdProvider` (`settings.low_stock_default`,
fallback `Product.defaultLowStockThreshold` bila belum diisi) alih-alih
memakai `Product.isLowStock` yang hardcode `defaultLowStockThreshold = 5`.

**Bukti (test baru)**:
`test/features/products/products_screen_low_stock_threshold_test.dart` —
2 widget test end-to-end (app sungguhan, Drift in-memory): produk stok 8
dengan `settings.low_stock_default = '10'` (TANPA threshold per-produk)
HARUS tampil sebagai "Stok menipis" di tab Produk (8 <= 10) — kalau
kode masih memakai nilai hardcode lama (5), test ini akan GAGAL karena
8 > 5 dianggap aman. Test kedua membuktikan sebaliknya (stok di atas
threshold global -> TIDAK dianggap menipis).

### 2.2 Laba kotor export Excel -> snapshot `sale_items.cost_price`

**Sudah benar** — diverifikasi TIDAK perlu perubahan tambahan.
`ExcelExportService.exportSalesReport` sudah memakai
`SaleResultItem.costPrice` (snapshot `sale_items.cost_price` saat
transaksi, BUKAN harga modal produk saat ini) sejak commit `dd43582`
(agent paralel menambahkan field itu ke `SaleResultItem` +
`SaleRepositoryImpl.getDetail`, yang sebelumnya "hilang" di pemetaan
entity meski kolom `sale_items.cost_price` sudah ada sejak M0/M2).
Konsisten dengan `ReportRepositoryImpl.getSummary` (dashboard laporan
M4). Dibuktikan `test/data/services/excel_export_service_test.dart`:
item dengan `costPrice` snapshot 3000 tetap dihitung 3000 meski
`Product.costPrice` produk saat ini diisi 1000 (nilai berbeda sengaja
dipakai di test supaya kalau kode salah membaca harga modal PRODUK
SAAT INI, test langsung gagal).

---

## 3. Tugas B — Milestone 6 Checklist

### 3.1 Empty state & pesan error Bahasa Indonesia

Audit seluruh `lib/features/**/*.dart`: semua layar berbasis daftar
(`ListView`/`GridView`) sudah punya widget empty-state informatif sejak
M1–M5 (produk, kasir, riwayat, stok menipis, riwayat stok, hutang,
transaksi ditahan, kategori). Yang BELUM aman: banyak titik menampilkan
error dengan interpolasi `'$e'`/`'$error'` mentah — kalau exception-nya
BUKAN exception domain (mis. `DriftException`/`FileSystemException`/
`FormatException` dari package pihak ketiga), pesannya Bahasa Inggris
dan bocor ke UI.

**Perbaikan**: `lib/core/utils/error_message.dart` — `AppErrorMessage.
from(Object error)`: kembalikan `error.toString()` apa adanya HANYA
untuk exception domain (`domain/repositories/repository_exceptions.dart`,
sudah Bahasa Indonesia sejak ditulis), selain itu kembalikan pesan
generik `'Terjadi kesalahan tak terduga. Coba lagi.'`. Dipasang di
±20 file (`lib/features/**`) — setiap `Text('$e')`/`Text('...: $error')`
di catch block maupun builder `error:` milik `AsyncValue` diganti
`AppErrorMessage.from(e)`. Test: `test/core/utils/error_message_test.dart`
(3 test: exception domain dipakai apa adanya, exception pihak ketiga
diganti generik, `Exception`/`StateError` polos juga diganti).

### 3.2 Ukuran sentuh, font, kontras

- **Kontras**: `AppColors.warning` (dipakai sebagai warna TEKS label
  "Stok menipis", bukan cuma ikon) dipergelap dari `0xFFB8860B`
  (~3.25:1 di atas putih, di bawah ambang WCAG AA 4.5:1 untuk teks
  normal) ke `0xFF8A6508` (~5.3:1) — arah warna (amber/kuning tua)
  dipertahankan supaya tetap terbaca sebagai "peringatan".
- **Ukuran sentuh**: `cart_item_tile.dart` — tombol "Diskon" diubah dari
  `TextButton.icon` berlabel jadi `IconButton` polos (tetap >=48dp
  default Material, tooltip Indonesia dipertahankan untuk aksesibilitas)
  supaya baris tombol qty/diskon/harga tidak overflow di HP sempit.
- **Overflow layar sempit** (ditemukan lewat widget test baru yang
  sengaja memakai lebar 392dp — HP kecil): `cart_item_tile.dart` (baris
  qty+diskon+harga, RenderFlex overflow 44-61px), `cart_panel.dart`
  (header "Keranjang"+"Kosongkan", 7px), `payment_sheet.dart` &
  `checkout_success_screen.dart` (`_SummaryRow` label+nilai Rupiah,
  s/d 124px untuk label panjang seperti "Uang diterima" + nilai
  "Kurang Rp95.000") — semua dibungkus `Flexible`/`Expanded` +
  `TextOverflow.ellipsis`.

**Belum diverifikasi manual**: tampilan sungguhan di HP kecil fisik
(5") dan tablet (8-11", breakpoint 600dp) — perbaikan di atas berbasis
audit kode + widget test (yang mensimulasikan lebar layar, bukan
device sungguhan). Lihat §5.

### 3.3 Performa

- **Pencarian produk < 100 ms @ 5.000 produk**: test baru
  `test/data/repositories/product_repository_impl_search_performance_test.dart`
  — 5.000 produk via `db.batch()` (Drift in-memory), ukur
  `ProductRepositoryImpl.watchAll(...)` (method PERSIS dipakai
  `productListProvider`/`posProductListProvider`) untuk 3 skenario:
  pencarian teks, pencarian barcode persis, daftar penuh tanpa filter
  — ketiganya **<100ms** (dijalankan sungguhan, index `idx_products_name`/
  `idx_products_barcode` M0 dipakai).
- **Cold start < 3 detik**: diaudit lewat kode (tidak ada device nyata
  di environment ini) — `main()` HANYA `WidgetsFlutterBinding.
  ensureInitialized()` + `DateFormatter.init()` (muat locale `id_ID`,
  ringan) sebelum `runApp()`. `AppDatabase()` (`drift_flutter`) memakai
  `LazyDatabase` — koneksi SQLite dibuka ASINKRON di isolate saat query
  pertama, BUKAN blocking di `main()`. Seed data debug
  (`SeedDataService.seedIfNeeded()`) dipanggil TANPA `await` di
  `initState()` `KasirApp`, tidak memblokir frame pertama. Tidak ada
  perubahan diperlukan — sudah sesuai prinsip "tidak ada kerja berat
  sinkron sebelum frame pertama".

**Belum diverifikasi manual**: waktu cold start SUNGGUHAN (stopwatch
di device fisik/emulator) — audit kode di atas adalah pengganti terbaik
yang mungkin di environment tanpa device. Lihat §5.

### 3.4 Ikon app, splash screen, nama tampilan

- **Ikon**: keranjang belanja putih flat-design di atas latar hijau
  brand (`AppColors.primary #1B7A43`) — `assets/icon/icon.png` (launcher
  legacy) + `icon_foreground.png` (glyph putih transparan, adaptive
  icon Android 8+/API 26). `flutter_launcher_icons` 0.9.3 (versi lama —
  versi baru bentrok dependency dengan `excel`, catatan keputusan M0)
  berhasil generate PNG per densitas tapi **crash** di langkah deteksi
  `minSdk` (baca `android/app/build.gradle` format Groovy — proyek ini
  pakai `build.gradle.kts`/Kotlin DSL) sebelum sempat menulis
  `mipmap-anydpi-v26/ic_launcher.xml` + `colors.xml` (adaptive icon) dan
  `ic_launcher.png` flat legacy per densitas — kedua hal itu ditulis/
  digenerate manual (adaptive icon XML manual, `ic_launcher.png` legacy
  di-resize manual dari `icon.png` via Pillow per densitas mdpi..
  xxxhdpi) supaya tidak ada sisa logo default Flutter di manapun.
- **Splash**: `flutter_native_splash` 2.2.16, warna latar sama
  (`#1B7A43`) + `icon_foreground.png` (glyph putih) di tengah. Sempat
  dicoba `assets/splash/splash_logo.png` (aset terpisah) lebih dulu,
  tapi diverifikasi lewat komposit piksel (Pillow) warnanya hijau/hijau
  tua — NYARIS TAK TERLIHAT di atas latar hijau yang sama — diganti ke
  `icon_foreground.png` yang sudah terverifikasi kontras baik.
- **Nama tampilan**: `android:label` di `AndroidManifest.xml` diubah
  dari `"kasir_warung"` ke `"Kasir Warung"`.
- **`flutter_launcher_icons`/`flutter_native_splash` DIHAPUS dari
  `dev_dependencies`** setelah generate selesai — modul Android bawaan
  `flutter_native_splash` tidak punya `namespace` (format lama, tidak
  kompatibel AGP proyek ini) dan membuat `flutter build apk --release`
  **gagal total** di tahap konfigurasi Gradle selama dependency itu
  masih ada, walau tidak dipakai kode Dart manapun saat runtime.

### 3.5 Uji regresi otomatis alur PRD §4 & §5

`test/features/pos/pos_checkout_flow_test.dart` — 3 widget test
end-to-end (app sungguhan `KasirApp`, Drift in-memory, viewport HP
portrait 392x1600 dipaksa lewat `tester.view.physicalSize` supaya
`PosScreen` merender layout HP — bukan tablet dua panel — karena
permukaan default `flutter_test` 800x600 lebih lebar dari breakpoint
tablet 600dp):

1. **Happy path tunai**: tap produk -> keranjang "1 item" -> buka sheet
   keranjang -> buka sheet pembayaran -> tap pecahan cepat Rp10.000 ->
   kembalian tampil benar -> "Selesaikan Pembayaran" -> layar "Transaksi
   Berhasil" -> **verifikasi DB langsung**: 1 baris `sales`
   (`payment_method='cash'`, `status='completed'`, `total`/`paid_amount`/
   `change_amount` benar) + stok produk berkurang tepat qty terjual ->
   "Transaksi Baru" -> keranjang kosong lagi.
2. **Hutang**: pilih metode "Hutang" -> tombol "Selesaikan Pembayaran"
   nonaktif tanpa nama pelanggan (validasi form) -> isi nama -> aktif ->
   simpan -> **verifikasi DB**: `payment_method='debt'`,
   `status='debt_unpaid'`, `customer_name` benar, `paid_amount=0`.
3. **Void dari Riwayat**: selesaikan 1 transaksi tunai -> pindah tab
   Riwayat -> buka detail -> "Batalkan Transaksi" -> dialog konfirmasi
   -> "Batalkan" -> **verifikasi DB**: `status='voided'` DAN stok produk
   kembali ke nilai semula (dikembalikan penuh).

**Temuan penting**: test #3 (void) awalnya GAGAL berulang kali dengan
gejala status tetap `'completed'` walau tombol "Batalkan" di dialog
konfirmasi ter-tap dengan benar (dikonfirmasi lewat instrumentasi print
debug sementara: `onPressed` dialog TERPANGGIL, tapi `Future` dari
`showDialog` TIDAK PERNAH resolve). Root cause: `showDialog` default
`useRootNavigator: true` mendorong dialog ke Navigator ROOT aplikasi,
sedangkan tombol aksi di dalam dialog memanggil
`Navigator.of(context).pop(...)` memakai `context` method LUAR (bukan
context builder dialog sendiri) yang oleh Flutter di-resolve ke Navigator
CABANG (nearest ancestor) — karena `MainShell` (`app_router.dart`) pakai
`StatefulShellRoute.indexedStack` (Navigator terpisah per tab bawah),
dua Navigator itu BERBEDA. Bug ini SUDAH ADA sejak Milestone 3 (`
_voidSale`, `_markPaid` di `sale_detail_screen.dart`) dan Milestone 2
(`_confirmClear`, `_hold` di `cart_panel.dart`), tidak pernah ketahuan
karena test M2/M3 hanya menguji usecase/repository, bukan alur UI
lengkap lewat dialog sungguhan. **Diperbaiki** di 4 file (`cart_item_
tile.dart`, `cart_panel.dart`, `held_carts_screen.dart`, `sale_detail_
screen.dart`) — builder dialog memakai context miliknya sendiri untuk
pop, pola yang sudah benar dipakai `category_manage_dialog.dart` &
`backup_restore_section.dart` sejak awal. Dampak nyata bug ini di
produksi: tombol "Batalkan Transaksi", "Tandai Lunas", "Kosongkan
Keranjang", "Tahan Transaksi", "Ganti Keranjang Aktif" (transaksi
ditahan), "Hapus Transaksi Ditahan", dan "Ubah Qty" item keranjang TIDAK
PERNAH benar-benar berfungsi sejak awal ditulis (dialog konfirmasi
membeku, aksinya tidak pernah tereksekusi) — perbaikan ini adalah hasil
paling penting dari Milestone 6.

Cakupan regresi otomatis TOTAL (M0–M6): **207 test** — unit domain,
repository (Drift in-memory, termasuk performa 50k transaksi M4 & 5k
produk M6), usecase, dan widget test end-to-end (navigasi tab, gerbang
PIN, alur kasir tunai/hutang/void).

### 3.6 Build release APK & App Bundle

```
$ flutter build apk --release --split-per-abi
✓ app-armeabi-v7a-release.apk   25.6 MB
✓ app-arm64-v8a-release.apk     29.6 MB   (paling relevan — mayoritas device modern)
✓ app-x86_64-release.apk        32.0 MB
(app-release.apk universal/fat, semua ABI: 81.3 MB — BUKAN yang didistribusikan)

$ flutter build appbundle --release
✓ app-release.aab               72.9 MB   (Play Store deliver split per-device saat instal)
```

Semua APK per-ABI **< 40 MB** (target PRD §6) — dibandingkan APK
"universal"/fat (81.3 MB, berisi native lib SEMUA arsitektur sekaligus,
BUKAN cara distribusi yang wajar) size per-ABI adalah ukuran yang
relevan untuk instalasi device sungguhan.

`flutter build apk --release` (default) awalnya **GAGAL TOTAL** karena
`flutter_native_splash` (lihat §3.4) — diperbaiki dengan melepas
dependency itu setelah asetnya sudah digenerate & di-commit.

R8 (`isMinifyEnabled = true`) + `shrinkResources = true` diaktifkan di
`android/app/build.gradle.kts` untuk build type `release` (sebelumnya
tidak diaktifkan sama sekali) + `android/app/proguard-rules.pro` (keep
rules untuk `sqlite3` FFI & ML Kit barcode/`mobile_scanner`, yang
banyak memakai reflection). Build sukses tanpa masalah keep rule
apa pun. Ukuran APK per-ABI TIDAK banyak berubah dengan/tanpa R8
(±0.1 MB) — masuk akal karena ukuran APK Flutter didominasi native
library (`libapp.so` hasil kompilasi AOT Dart, `libflutter.so`, native
lib ML Kit) yang TIDAK disusutkan R8 (R8 hanya menyusutkan bytecode
Java/Kotlin), bukan berarti R8 tidak berfungsi.

Signing masih memakai **debug keys** (`signingConfig =
signingConfigs.getByName("debug")`, bawaan template `flutter create`,
TIDAK diubah) — cukup untuk `flutter run --release`/uji internal, TAPI
**wajib diganti keystore rilis sungguhan sebelum distribusi publik**
(Play Store menolak APK/AAB bertanda tangan debug key). Di luar scope
tugas ini (butuh keystore milik pemilik produk, bukan sesuatu yang bisa
dibuat sepihak oleh agent).

---

## 4. Status Analyze & Test

```
$ flutter analyze
Analyzing aplikasi-kasir...
No issues found! (ran in ~2s)

$ flutter test
00:09 +207: All tests passed!
```

Test baru Milestone 6 (11 test, di atas 196 dari M0–M5):
- `test/core/utils/error_message_test.dart` — 3 test.
- `test/data/repositories/product_repository_impl_search_performance_test.dart` — 1 test (3 sub-assertion waktu <100ms).
- `test/features/products/products_screen_low_stock_threshold_test.dart` — 2 test (dari commit paralel Tugas A).
- `test/features/pos/pos_checkout_flow_test.dart` — 3 test.
- Tambahan kecil di `sale_repository_impl_test.dart`/`excel_export_service_test.dart` (commit paralel Tugas A) — 2 test.

---

## 5. Hal yang Perlu Uji Manual (Device Fisik)

Tidak ada device Android fisik/emulator tersedia di environment
pengembangan ini — item berikut TERVERIFIKASI lewat kode/widget test
(bukan device sungguhan), disarankan dikonfirmasi manual sebelum rilis
publik:

1. **Cold start < 3 detik** — diaudit lewat kode (§3.3), belum diukur
   stopwatch di device fisik/emulator sungguhan.
2. **Tampilan HP kecil (5") & tablet (8-11", breakpoint 600dp) SUNGGUHAN**
   — perbaikan overflow/kontras (§3.2) diverifikasi lewat widget test
   (viewport disimulasikan) dan perhitungan kontras WCAG, bukan
   pengamatan visual di layar fisik.
3. **Scan barcode kamera** (`mobile_scanner`) — butuh kamera fisik,
   tidak bisa diuji di widget test.
4. **Share struk** (gambar/teks, `share_plus`) ke aplikasi lain
   (WhatsApp dll.) — share sheet native Android tidak bisa disimulasikan
   di widget test.
5. **File picker** (`file_picker`, restore backup `.db`) — dialog file
   picker native.
6. **Rasa sentuh keypad PIN** & keyboard on-screen sungguhan (ukuran
   ≥48dp sudah diverifikasi via kode, tapi "enak dipakai jempol" perlu
   device fisik).
7. **Build release APK di device Android nyata** — `flutter build apk
   --release --split-per-abi` sukses & APK terinstal (belum diverifikasi
   `adb install` di device sungguhan karena tidak tersedia).
8. Item manual dari M5 yang MASIH belum diverifikasi: **uji pindah
   perangkat nyata** (backup di device A -> restore di device B).

Semua item di atas TIDAK memblokir status "selesai" Milestone 6 sesuai
instruksi tugas ("uji manual device dicatat sebagai 'perlu uji manual'
di laporan") — dicantumkan di sini sebagai daftar verifikasi pra-rilis
yang disarankan.

---

## 6. Kerja Paralel dengan Sesi Lain

Milestone ini dikerjakan bersamaan dengan sesi Claude Code LAIN
(`aplikasi-kasir-19`) di working directory Git yang SAMA (ditemukan
lewat beberapa `<system-reminder>` yang menandai file berubah "oleh
user/linter" padahal tidak — lalu dikonfirmasi lewat `ListAgents`
menunjukkan peer session interaktif aktif). Langkah koordinasi yang
dipakai:
- Mengirim pesan (`SendMessage`) ke sesi tersebut begitu terdeteksi,
  menjelaskan progres masing-masing & menghindari tumpang tindih area
  kerja (ikon/splash dibiarkan jadi milik sesi lain begitu terlihat
  mereka sudah mengerjakannya; laporan/versi/tag/push diambil alih
  sesi ini dengan pemberitahuan lebih dulu).
- Sebelum tiap commit, `git status`/`git diff HEAD` diperiksa per file
  untuk memastikan tidak menimpa pekerjaan sesi lain — ditemukan Tugas A
  (§2) SUDAH dikerjakan & di-commit (`dd43582`) oleh sesi lain SAAT
  laporan ini sedang menganalisisnya secara independen; hasil analisis
  independen tersebut ternyata identik byte-per-byte untuk sebagian
  besar file (`Product.isLowStockWith`, dst.) — tidak ada yang ditimpa.
- `git add` selalu memakai daftar path eksplisit (tidak pernah `-A`),
  `git pull --rebase` sebelum tiap `git push`.
- Perubahan `AppColors.warning` (kontras) milik sesi lain, yang sudah
  ada di working tree saat commit dilakukan, ikut di-commit APA ADANYA
  (tidak diubah isinya) di commit "overflow & kontras" supaya tidak
  hilang.

---

## 7. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi   # APK production, 3 file per-ABI
flutter build appbundle --release             # App Bundle untuk Play Store
flutter run                                    # perlu device/emulator Android
```
