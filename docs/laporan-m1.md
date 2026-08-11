# Laporan Milestone 1 — Produk & Kategori

**Tanggal:** 11 Agustus 2026
**Acuan:** [prd.md](prd.md) · [architecture.md](architecture.md) · [plan.md](plan.md) · [laporan-m0.md](laporan-m0.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 1 di `plan.md` selesai dikerjakan: entity & kontrak
repository domain, implementasi repository Drift + provider Riverpod, layar
daftar produk (pencarian real-time, filter kategori, indikator stok menipis),
form tambah/edit produk (barcode ketik/scan, kategori dropdown + tambah
cepat), CRUD kategori lewat dialog, nonaktifkan produk (soft-hide dari Kasir),
validasi barcode unik dengan pesan Bahasa Indonesia, dan unit test repository
+ validasi form.

`flutter analyze` bersih (0 issue). `flutter test` — lihat §4 untuk hasil
lengkap.

---

## 2. Yang Dikerjakan

### 2.1 Domain — entity & kontrak repository

- `lib/domain/entities/product.dart`, `lib/domain/entities/category.dart` —
  entity murni Dart (tanpa dependency Drift/Flutter), dengan `copyWith`,
  `==`/`hashCode`. `Product.isLowStock` menghitung status stok menipis
  (`stock <= (lowStockThreshold ?? defaultLowStockThreshold)`).
- `lib/domain/repositories/product_repository.dart`,
  `category_repository.dart` — kontrak abstrak yang dipakai `features/`
  (aturan arsitektur: `features` tidak pernah mengimpor Drift langsung).
- `lib/domain/repositories/repository_exceptions.dart` —
  `BarcodeSudahDipakaiException`, `NamaKategoriSudahAdaException`,
  `KategoriMasihDipakaiException`, masing-masing dengan `toString()`
  berbahasa Indonesia siap ditampilkan ke pengguna.

### 2.2 Data — implementasi Drift

- `lib/data/repositories/product_repository_impl.dart`,
  `category_repository_impl.dart` — implementasi di atas `AppDatabase`
  (Drift). `watchAll()` memakai `QueryStream` reaktif (`LIKE` untuk
  pencarian nama/barcode, filter kategori, filter `onlyActive` untuk layar
  Kasir di Milestone 2). Pelanggaran unique index (barcode produk, nama
  kategori) ditangkap lewat `SqliteException` dan dikonversi ke exception
  domain di atas.
- Catatan penamaan: kelas baris hasil generate Drift untuk tabel `Products`
  dan `Categories` bernama `Product`/`Category` — identik dengan nama entity
  domain. Untuk menghindari tabrakan, `app_database.dart` diimpor dengan
  prefix `db.` di kedua file implementasi repository (`db.Product`,
  `db.ProductsCompanion`, dst.), sehingga tipe domain (`Product`, `Category`)
  tetap bisa dipakai tanpa prefix.

### 2.3 Provider Riverpod

- `lib/features/products/providers/product_providers.dart` —
  `productRepoProvider`, `ProductFilter` (query + categoryId),
  `ProductFilterNotifier` (debounce pencarian 300ms via `Timer`, dibatalkan
  lewat `ref.onDispose`), `productListProvider` (`StreamProvider` yang
  watch filter aktif → `repo.watchAll(...)`).
- `lib/features/products/providers/category_providers.dart` —
  `categoryRepoProvider`, `categoryListProvider` (`StreamProvider` semua
  kategori, dipakai chip filter & dropdown form).
- `databaseProvider` sudah ada dari Milestone 0 (`lib/data/db/database_provider.dart`)
  dan dipakai ulang oleh kedua repo provider di atas.

### 2.4 Layar daftar produk

`lib/features/products/screens/products_screen.dart` menggantikan stub M0:
- Search field dengan debounce 300ms (lewat `ProductFilterNotifier.setQuery`).
- Chip filter kategori ("Semua" + tiap kategori), reaktif dari
  `categoryListProvider`.
- List produk (`ProductListTile`, `lib/features/products/widgets/product_list_tile.dart`)
  menampilkan nama, kategori, stok+satuan, badge "Stok menipis" (ikon
  warning) bila `product.isLowStock`, badge "Nonaktif" bila produk
  dinonaktifkan, dan harga jual format Rupiah (`CurrencyFormatter.format`).
- Empty state berbeda pesan untuk "belum ada produk" vs "tidak ditemukan
  (filter aktif)".
- Tombol "Kelola kategori" di AppBar membuka `CategoryManageDialog`; FAB
  "Tambah Produk" membuka form tambah.

### 2.5 Form tambah/edit produk

`lib/features/products/screens/product_form_screen.dart`
(`route: /produk/tambah` dan `/produk/:id/ubah`, ditambahkan ke
`app_router.dart` sebagai sub-route dari tab Produk):
- Nama (wajib), barcode (opsional — field teks + tombol scan kamera).
- Scan barcode: `lib/features/products/widgets/barcode_scanner_page.dart`
  memakai `mobile_scanner` (`MobileScannerController`, toggle senter),
  mengembalikan `rawValue` barcode pertama yang terbaca lewat
  `Navigator.pop`.
- Kategori: `DropdownButtonFormField` dari `categoryListProvider` + entri
  sentinel "+ Tambah kategori baru" (`_addCategorySentinel = -1`, aman
  karena id Drift autoincrement selalu ≥ 1) yang membuka
  `QuickAddCategoryDialog` lalu langsung memilih kategori baru tsb.
- Harga jual (wajib, integer > 0), harga modal (opsional, integer ≥ 0),
  stok (opsional, desimal ≥ 0 — label "Stok awal" saat tambah, "Stok" saat
  ubah), satuan (wajib, teks bebas: pcs/kg/liter/dll), threshold stok
  menipis (opsional, desimal ≥ 0).
- Foto produk: **ditunda sesuai instruksi tugas** — hanya kotak info
  "Foto produk belum didukung di versi ini", `imagePath` selalu `null`.
  Tidak ada dependency baru (`image_picker` dst.) ditambahkan.
- Mode ubah menampilkan `SwitchListTile` "Produk aktif" — mengubah
  `is_active` lewat `ProductRepository.setActive` (soal nonaktifkan produk,
  lihat §2.6).
- Validasi field lewat `lib/features/products/utils/product_form_validator.dart`
  (Dart murni, testable tanpa widget test — lihat §2.7).
- Error `BarcodeSudahDipakaiException` dari repository ditangkap dan
  ditampilkan lewat `SnackBar` berbahasa Indonesia.

### 2.6 CRUD kategori & nonaktifkan produk

- `lib/features/products/widgets/category_manage_dialog.dart` — dialog
  tambah (field + tombol di bagian bawah), ubah nama (dialog kecil ke-2),
  hapus (konfirmasi → `CategoryRepository.delete`, menangkap
  `KategoriMasihDipakaiException` bila kategori masih dipakai produk →
  SnackBar Bahasa Indonesia, kategori TIDAK terhapus).
- Nonaktifkan produk: `ProductRepository.setActive(id, false)` men-set
  `is_active = 0` tanpa menghapus baris. Layar Produk tetap menampilkan
  produk nonaktif (dengan badge "Nonaktif"); parameter `onlyActive: true`
  pada `watchAll()` (dipakai layar Kasir mulai Milestone 2) yang akan
  menyembunyikannya dari alur transaksi.
- Validasi barcode unik: partial unique index `idx_products_barcode_unique`
  (dari Milestone 0) ditangkap sebagai `SqliteException` di
  `ProductRepositoryImpl.createProduct`/`updateProduct` dan dikonversi ke
  `BarcodeSudahDipakaiException` dengan pesan
  `Barcode "..." sudah dipakai produk lain. Gunakan barcode yang berbeda
  atau kosongkan.`. String barcode kosong/whitespace dinormalisasi ke
  `null` sebelum disimpan (tidak memicu unique index).

### 2.7 Unit test

- `test/data/repositories/product_repository_impl_test.dart` — CRUD,
  normalisasi barcode kosong, penolakan barcode duplikat (pesan Bahasa
  Indonesia), pencarian nama/barcode, filter kategori, `watchAll` reaktif
  (stream re-emit setelah insert), `setActive` (produk nonaktif tetap
  tampil di `watchAll()` tapi hilang dari `watchAll(onlyActive: true)`),
  `Product.isLowStock` (threshold per-produk & default global).
- `test/data/repositories/category_repository_impl_test.dart` — CRUD,
  penolakan nama duplikat, `delete` gagal + melempar
  `KategoriMasihDipakaiException` saat kategori masih dipakai produk (dan
  kategori tidak ikut terhapus), `countProducts`.
- `test/features/products/product_form_validator_test.dart` — seluruh
  method `ProductFormValidator` (nama, harga jual, harga modal, stok,
  satuan, threshold, nama kategori), termasuk kasus kosong/opsional,
  bukan-angka, negatif, dan desimal koma/titik.
- Semua test DB baru memakai `NativeDatabase.memory()` (pola yang sama
  dengan `test/data/db/app_database_test.dart` Milestone 0).

---

## 3. Keputusan Teknis

1. **Threshold stok menipis default global di-hardcode sementara**
   (`Product.defaultLowStockThreshold = 5`, di `lib/domain/entities/product.dart`).
   PRD §3.1.F menyebut nilai ini seharusnya bisa diubah pengguna lewat
   Pengaturan, tapi layar Pengaturan (tabel `settings`) baru dikerjakan di
   Milestone 5 sesuai `plan.md`. Threshold **per-produk** (field
   `lowStockThreshold` di form) sudah berfungsi penuh sekarang; hanya nilai
   *default* global yang masih konstanta kode, bukan dari tabel `settings`.
2. **Prefix `db.` untuk tipe hasil generate Drift** — dijelaskan di §2.2:
   diperlukan karena kelas baris Drift (`Product`, `Category`) bertabrakan
   nama dengan entity domain. Solusi ini menjaga aturan arsitektur (entity
   domain tetap nama yang bersih, tanpa perlu mengganti nama entity jadi
   awkward seperti `ProductEntity`).
3. **Penyimpanan foto produk ditunda** — sesuai instruksi tugas eksplisit,
   tidak menambah dependency `image_picker`/sejenisnya. UI form sudah
   menyediakan tempat (kotak info "belum didukung") sehingga saat fitur ini
   dikerjakan (kemungkinan bersamaan dengan export/backup di Milestone 5,
   karena foto ikut memengaruhi strategi backup — lihat architecture.md
   §5.3), tinggal mengganti kotak info dengan image picker + field
   `imagePath` yang sudah ada di repository/entity.
4. **Satuan sebagai teks bebas** (bukan dropdown tertutup) — PRD menyebut
   "pcs/kg/liter/dll", jadi field satuan dibuat `TextFormField` bebas
   (default `pcs`) alih-alih dropdown tertutup, supaya pengguna warung bisa
   memakai satuan apa pun (ikat, lusin, dus, dll.) tanpa menunggu update
   aplikasi.
5. **Edit stok langsung dari form produk** — Milestone 1 mengizinkan field
   "Stok" diedit langsung saat ubah produk (tanpa mencatat
   `stock_movements`). Pencatatan mutasi stok terstruktur (masuk/keluar/
   opname + alasan, riwayat per produk) adalah scope eksplisit Milestone 4
   (`plan.md`). Edit langsung di M1 dianggap wajar untuk skenario koreksi
   cepat (typo stok awal) sebelum alur penyesuaian stok resmi ada.
6. **Sentinel `-1` untuk entri dropdown "+ Tambah kategori baru"** — aman
   karena kolom `categories.id` adalah `INTEGER PK AUTOINCREMENT` Drift,
   selalu bernilai ≥ 1.
7. **Fix widget test `app_test.dart` untuk provider berbasis stream Drift** —
   setelah tab Produk memakai `StreamProvider` (Riverpod) di atas
   `QueryStream` (Drift), test navigasi tab yang sudah ada sejak Milestone 0
   mulai gagal dengan error framework
   `A Timer is still pending even after the widget tree was disposed.`.
   Penyebab: Drift menjadwalkan `Timer(Duration.zero, ...)` internal saat
   sebuah `QueryStream` di-*cancel* (dipakai untuk toleransi resubscribe
   cepat, lihat `package:drift/src/runtime/executor/stream_queries.dart`),
   dan `flutter_test` (`AutomatedTestWidgetsFlutterBinding`, berjalan di atas
   `fake_async`) menganggap *timer* yang belum sempat diproses saat test
   berakhir sebagai kegagalan invariant. `tester.pumpAndSettle()` tidak
   cukup karena ia hanya menunggu *frame* terjadwal, bukan `Timer` polos, dan
   `tester.pump()` tanpa argumen hanya melakukan `flushMicrotasks()` (tidak
   meng-*elapse* fake clock, sehingga `Timer` walau `Duration.zero` tidak
   ikut terproses). Solusinya: tiap `testWidgets` di `app_test.dart`
   sekarang memanggil helper `disposeApp(tester)` di baris terakhir, yang
   mengganti root widget dengan `SizedBox` (memicu disposal `ProviderScope`
   secara eksplisit di dalam kendali test) lalu `await tester.pump(Duration.zero)`
   (bukan `tester.pump()` tanpa argumen) agar *timer* tsb benar-benar
   di-*flush* sebelum test dianggap selesai.
8. **Debounce pencarian 300ms** (bukan 150ms seperti disebut
   `architecture.md` §5.1 untuk layar Kasir) — dipilih karena layar Produk
   menampilkan daftar teks biasa (bukan grid kasir yang butuh feedback
   sangat instan saat transaksi berlangsung); 300ms adalah nilai umum untuk
   search-as-you-type pada daftar administratif. Provider `ProductFilterNotifier`
   didokumentasikan agar keputusan ini eksplisit dan mudah diubah bila
   diperlukan konsistensi dengan layar Kasir di Milestone 2.

---

## 4. Status Analyze & Test

```
$ flutter analyze
Analyzing aplikasi-kasir...
No issues found! (ran in 1.2s)

$ flutter test
00:03 +66: All tests passed!
```

Rincian 66 test (29 dari Milestone 0 + 37 baru Milestone 1):
- `test/data/repositories/product_repository_impl_test.dart` — 13 test (CRUD,
  normalisasi barcode kosong, penolakan barcode duplikat saat tambah & ubah,
  pencarian nama/barcode, filter kategori, stream reaktif, `setActive`,
  `isLowStock`).
- `test/data/repositories/category_repository_impl_test.dart` — 8 test (CRUD,
  penolakan nama duplikat saat tambah & ubah, `delete` gagal saat kategori
  masih dipakai produk, `countProducts`).
- `test/features/products/product_form_validator_test.dart` — 16 test
  (seluruh method `ProductFormValidator`).
- `test/app_test.dart` — masih 4 test (navigasi 5 tab), diperbarui agar
  memanggil `disposeApp(tester)` di akhir tiap test (lihat §3 poin 8) supaya
  kompatibel dengan provider berbasis stream Drift yang baru ditambahkan di
  tab Produk.
- Sisanya (29 test) tidak berubah dari Milestone 0.

---

## 5. Hal yang Belum Selesai / Di Luar Scope M1

- **Threshold stok menipis default global** dari tabel `settings` (baru
  konstanta kode) — menyusul di Milestone 5 bersama layar Pengaturan.
- **Foto produk** — ditunda sesuai instruksi tugas (lihat §3 poin 3), belum
  ada dependency image picker.
- **Riwayat pergerakan stok** (`stock_movements`) untuk perubahan stok lewat
  form edit produk — scope resmi Milestone 4.
- **Badge "stok menipis" di tab Produk (ikon navigasi bawah)** disebut di
  `plan.md` Milestone 4 (bukan M1) — belum dikerjakan; indikator per-baris
  di layar Produk (M1, badge pada `ProductListTile`) sudah ada.
- Widget test end-to-end untuk form tambah/edit produk & dialog kategori
  belum ditulis (di luar permintaan eksplisit tugas: "unit test repository
  produk & kategori + logika validasi form" — keduanya sudah dipenuhi di
  §2.7). Widget test alur kasir baru masuk scope Milestone 2
  (`architecture.md` §8).

---

## 6. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter run           # perlu device/emulator Android
```

Layar Produk (`/produk`): cari/filter produk, tambah kategori cepat, tambah/
ubah produk (termasuk scan barcode via kamera), nonaktifkan produk lewat
switch di form ubah.
