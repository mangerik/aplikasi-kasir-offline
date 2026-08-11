# Laporan Milestone 4 — Stok & Laporan

**Tanggal:** 11 Agustus 2026
**Acuan:** [prd.md](prd.md) · [architecture.md](architecture.md) · [plan.md](plan.md) ·
[laporan-m0.md](laporan-m0.md) · [laporan-m1.md](laporan-m1.md) · [laporan-m2.md](laporan-m2.md) ·
[laporan-m3.md](laporan-m3.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 4 di `plan.md` selesai dikerjakan: penyesuaian
stok manual (masuk/keluar/opname) dengan alasan wajib, riwayat pergerakan
stok per produk, daftar & badge "stok menipis" di tab Produk, dashboard
laporan harian (menggantikan stub Milestone 0) dengan preset rentang
tanggal, produk terlaris, dan daftar hutang belum lunas per pelanggan.
Seluruh agregasi laporan (omzet, laba kotor, per metode bayar, produk
terlaris, hutang per pelanggan) dijalankan lewat SQL (`SUM`/`COUNT`/
`GROUP BY` via query builder Drift & `customSelect`), BUKAN dihitung di
Dart, dan diuji performanya dengan data dummy ≥50.000 transaksi.

`flutter analyze` bersih (0 issue). `flutter test` → **194/194 test
lulus** (Milestone 4 menambah 66 test baru pada working tree ini — lihat
§4; sebagian angka lain berasal dari pekerjaan paralel Milestone 5 pada
`main` yang sama, di luar cakupan laporan ini). Pekerjaan dilakukan
**bersamaan** dengan agent lain yang mengerjakan Milestone 5 (Pengaturan,
export Excel, backup/restore) pada branch `main` yang sama — lihat §3
poin 7 untuk cara kerja sama yang dipakai.

---

## 2. Yang Dikerjakan

### 2.1 Domain — entity & kontrak repository

- `lib/domain/entities/stock_movement.dart` — **`StockMovement`**: satu
  baris pergerakan stok (jenis, qty ±, stok akhir, referensi transaksi +
  nomor invoicenya, catatan, waktu), dengan `typeLabel` (Bahasa Indonesia)
  dan `isManualAdjustment` sebagai helper tampilan.
- `lib/domain/entities/daily_summary.dart` — **`DailySummary`** (+
  `PaymentMethodTotal`): hasil ringkasan satu rentang tanggal — omzet,
  jumlah transaksi, laba kotor, pemecahan per metode bayar.
- `lib/domain/entities/top_product.dart` — **`TopProduct`**: qty & nilai
  terjual per produk untuk suatu rentang tanggal.
- `lib/domain/entities/customer_debt.dart` — **`CustomerDebt`**: total &
  jumlah transaksi hutang belum lunas per pelanggan.
- `lib/domain/repositories/stock_repository.dart` — kontrak
  **`StockRepository`**: `adjustStock` (masuk/keluar/opname, WAJIB atomik
  update `products.stock` + insert `stock_movements` dalam satu
  `db.transaction()`) dan `getMovements` (riwayat berpaginasi
  `LIMIT`/`OFFSET`, pola sama `SaleRepository.getHistory` M3).
- `lib/domain/repositories/report_repository.dart` — kontrak
  **`ReportRepository`**: `getSummary`, `getTopProducts` (+ enum
  `TopProductSort`), `getUnpaidDebts`, `getDebtTransactions`. Dokumentasi
  eksplisit menegaskan implementasi WAJIB agregasi SQL, bukan Dart.
- `lib/domain/repositories/product_repository.dart` — ditambah
  `watchLowStockCount`/`watchLowStock` (stream reaktif, agregasi
  `COUNT`/filter SQL, dipakai badge tab Produk & layar Stok Menipis).
- `lib/domain/repositories/repository_exceptions.dart` — ditambah
  `ProdukTidakDitemukanException`, `JumlahPenyesuaianTidakValidException`,
  `AlasanPenyesuaianWajibException` (pesan Bahasa Indonesia siap tampil).
  *(File ini dipakai bersama dengan Milestone 5 — lihat §3 poin 7.)*
- `lib/domain/usecases/adjust_stock_usecase.dart` — **`AdjustStockUsecase`**:
  validasi domain MURNI sebelum delegasi ke `StockRepository.adjustStock`
  — jenis harus `adjust_in`/`adjust_out`/`opname`, jumlah harus valid
  (>0 untuk masuk/keluar, ≥0 untuk opname), dan alasan/catatan WAJIB diisi
  (di-trim, tidak boleh kosong/spasi).

### 2.2 Data — implementasi repository

- `lib/data/repositories/stock_repository_impl.dart` —
  `adjustStock`: SATU `db.transaction()` — baca stok sekarang, hitung
  `(newStock, qtyChange)` lewat switch-expression sesuai `type`
  (`adjust_in`: `+amount`; `adjust_out`: `-amount`; `opname`: `amount`
  ADALAH stok akhir absolut, `qtyChange = amount - stokSekarang`), update
  `products.stock`, insert `stock_movements`. Melempar
  `ProdukTidakDitemukanException` bila produk tidak ada (TANPA menyisakan
  baris `stock_movements`, diuji eksplisit). `getMovements`: query
  `LIMIT`/`OFFSET` terbaru dulu (index `stock_movements(product_id,
  created_at)` M0) + SATU query tambahan (bukan N+1) untuk menggabungkan
  nomor invoice referensi.
- `lib/data/repositories/report_repository_impl.dart` — SELURUH method
  pakai `customSelect`/query builder Drift dengan `SUM`/`COUNT`/
  `GROUP BY` langsung di SQL:
  - `getSummary`: 3 query — total (`COUNT`/`SUM(total)` WHERE
    `status != 'voided'` DAN rentang tanggal), laba kotor (`SUM(CASE WHEN
    cost_price IS NOT NULL THEN line_total - cost_price*qty ELSE 0 END)`
    join `sale_items`↔`sales`), dan per metode bayar (`GROUP BY
    payment_method`).
  - `getTopProducts`: `GROUP BY product_id, product_name, unit` atas
    `sale_items` join `sales` (rentang tanggal, voided dikecualikan),
    `ORDER BY qty_sold` atau `total_value DESC` sesuai `TopProductSort`.
  - `getUnpaidDebts`: `GROUP BY customer_name` WHERE `status =
    'debt_unpaid'`, urut total terbesar.
  - `getDebtTransactions`: query builder Drift biasa (bukan raw SQL) —
    filter `status='debt_unpaid' AND customer_name=?`.
- `lib/data/repositories/product_repository_impl.dart` — ditambah
  `watchLowStockCount` (query `selectOnly` + `count()` agregat) dan
  `watchLowStock` (query `select` biasa + `orderBy(stock)`), keduanya
  berbagi kondisi SQL `_lowStockCondition` yang dibangun dengan fungsi
  `coalesce()` bawaan Drift: `stock <= COALESCE(low_stock_threshold,
  defaultThreshold)` — SAMA PERSIS logikanya dengan `Product.isLowStock`
  (Dart), tapi dijalankan di SQL agar tidak perlu memuat seluruh tabel
  produk ke memori.

### 2.3 Fitur Inventory — penyesuaian stok, riwayat, stok menipis

- `lib/features/inventory/providers/stock_providers.dart` —
  `stockRepoProvider`, `adjustStockUsecaseProvider`,
  `lowStockDefaultThresholdProvider` (baca `settings.low_stock_default`
  lewat `SettingsRepository` yang sudah ada sejak M3, fallback ke
  `Product.defaultLowStockThreshold` bila belum diisi — lihat §3 poin 1),
  `lowStockCountProvider`/`lowStockListProvider` (stream), dan
  `StockMovementNotifier` (`AsyncNotifier` family per `productId`, pola
  sama `HistoryListNotifier` M3: `build()` muat halaman pertama,
  `loadMore()` infinite scroll, `refresh()` dipanggil setelah penyesuaian
  berhasil).
- `lib/features/inventory/screens/stock_adjustment_screen.dart` — form
  `SegmentedButton` (Stok Masuk/Stok Keluar/Opname), field jumlah (label &
  validasi berubah sesuai jenis — opname minta "stok akhir hasil hitung
  fisik", bukan selisih), preview "stok setelah penyesuaian" real-time,
  field alasan/catatan WAJIB. Mengembalikan `true` lewat `Navigator.pop`
  saat berhasil supaya layar pemanggil tahu harus memuat ulang data
  produk.
- `lib/features/inventory/screens/stock_movement_history_screen.dart` —
  daftar riwayat (jenis, qty ±, stok akhir, referensi invoice, waktu,
  catatan) via `StockMovementTile`, infinite scroll, FAB "Sesuaikan
  Stok" langsung dari layar ini.
- `lib/features/inventory/screens/low_stock_screen.dart` — daftar produk
  stok menipis (urut stok tersedikit dulu), tap → langsung buka
  `StockAdjustmentScreen` untuk isi ulang.
- `lib/features/inventory/widgets/stock_movement_tile.dart` — baris
  riwayat dengan ikon & warna berbeda per jenis pergerakan (hijau untuk
  qty positif, merah untuk negatif).

### 2.4 Fitur Reports — dashboard laporan harian & hutang

- `lib/features/reports/providers/report_providers.dart` —
  `reportRepoProvider`, `ReportDateRange`/`ReportRangePreset` (factory
  `today()`/`yesterday()`/`last7Days()`/`thisMonth()`/`custom()`, selalu
  membulatkan ke awal & AKHIR hari — `23:59:59.999` — supaya rentang
  inklusif memuat transaksi terakhir), `reportDateRangeProvider`
  (`NotifierProvider`, default preset "Hari ini" = dashboard harian),
  `dailySummaryProvider`/`topProductsProvider` (`FutureProvider`, watch
  rentang tanggal aktif), `topProductSortProvider`,
  `unpaidDebtsProvider`, `customerDebtTransactionsProvider`
  (`FutureProvider.autoDispose.family<List<Sale>, String>`).
- `lib/features/reports/screens/reports_screen.dart` — GANTI STUB M0:
  chip preset rentang tanggal (custom → `showDateRangePicker` bawaan
  Flutter, sudah ter-localize `id_ID` sejak M0) + label rentang aktif,
  kartu ringkasan (Omzet/Transaksi/Laba Kotor via `SummaryCard`), daftar
  per metode bayar, produk terlaris dengan `SegmentedButton` urutan
  qty/nilai (`TopProductTile` bernomor peringkat), tombol AppBar ke
  Daftar Hutang, `RefreshIndicator`.
- `lib/features/reports/screens/debt_list_screen.dart` — daftar
  `CustomerDebt` (total & jumlah transaksi per pelanggan), tap → daftar
  transaksinya.
- `lib/features/reports/screens/customer_debt_transactions_screen.dart` —
  daftar transaksi hutang milik satu pelanggan; REUSE PENUH `HistoryTile`
  & `SaleDetailScreen` dari `features/transactions` (Milestone 3) — TIDAK
  ADA duplikasi tampilan struk/status/pelunasan. Setelah kembali dari
  Detail (mis. pelunasan), daftar di-invalidate supaya transaksi yang
  sudah lunas otomatis hilang.
- `lib/features/reports/widgets/summary_card.dart`,
  `top_product_tile.dart` — widget tampilan angka ringkasan & baris
  produk terlaris.

### 2.5 Integrasi ke layar Produk existing

- `lib/core/widgets/main_shell.dart` — diubah dari `StatelessWidget` ke
  `ConsumerWidget`; ikon tab Produk dibungkus `Badge.count` menampilkan
  `lowStockCountProvider` (plan.md Milestone 4 poin 3: "badge jumlah di
  tab Produk").
- `lib/features/products/screens/products_screen.dart` — tombol AppBar
  baru (ikon peringatan + badge sama) → `LowStockScreen`.
- `lib/features/products/screens/product_form_screen.dart` — mode ubah
  menampilkan tombol "Sesuaikan Stok" & "Riwayat Stok" (plan.md Milestone
  4 poin 1: "UI dari layar produk ... atau detail produk"); kembali dari
  penyesuaian stok berhasil memuat ulang data produk supaya angka stok di
  form ikut ter-update.

---

## 3. Keputusan Teknis

1. **Threshold default global dibaca lewat `SettingsRepository.getValue
   ('low_stock_default')`** (kontrak domain yang sudah ada sejak M3),
   BUKAN dengan menunggu/menyentuh implementasi penuh layar Pengaturan
   Milestone 5 yang sedang dikerjakan paralel. Belum diisi → fallback ke
   `Product.defaultLowStockThreshold` (keputusan M1 yang masih berlaku).
   Ini menjaga fitur M4 tidak terkopel ke jadwal penyelesaian M5: begitu
   M5 menulis `low_stock_default` ke tabel `settings`, badge & daftar
   stok menipis M4 otomatis memakainya tanpa perubahan kode apa pun (key
   sudah disepakati lewat nama kolom di dokumen arsitektur).
2. **`StockRepository.adjustStock` memakai SATU parameter `amount` yang
   artinya berbeda tergantung `type`** — untuk `adjust_in`/`adjust_out`
   adalah JUMLAH perubahan (selalu positif dari input pengguna), untuk
   `opname` adalah STOK AKHIR ABSOLUT hasil hitung fisik (bukan selisih).
   Alternatif lain (dua parameter terpisah, atau method berbeda per
   jenis) dipertimbangkan tapi ditolak karena menambah percabangan tanpa
   manfaat — kontrak method sudah mendokumentasikan arti `amount` per
   jenis secara eksplisit, dan `AdjustStockUsecase`/`StockAdjustmentScreen`
   menerjemahkan input form (label & validasi berbeda per jenis) ke
   parameter yang sama ini.
3. **`getDebtTransactions` DIBUAT SEBAGAI method baru di
   `ReportRepository`** (query builder Drift terpisah, sedikit duplikasi
   dengan pola `_toSale` di `SaleRepositoryImpl`), BUKAN menambah
   parameter `customerName` opsional ke `SaleRepository.getHistory` yang
   sudah ada sejak M3. Menambah parameter opsional baru ke method
   interface yang sudah diimplementasikan fake-nya di 3 file test
   (`void_sale_usecase_test.dart`, `mark_debt_paid_usecase_test.dart`,
   `save_sale_usecase_test.dart`) akan memaksa Dart mewajibkan override
   parameter itu juga di ketiga fake tersebut (aturan kompatibilitas
   override signature Dart) — mengubah file test M3 yang stabil demi
   kebutuhan M4 dianggap berisiko lebih tinggi daripada duplikasi kecil
   ini, apalagi kedua repository (`SaleRepository`/`ReportRepository`)
   memang dipisahkan sejak awal by design (architecture.md §3).
4. **Laba kotor MENGECUALIKAN item tanpa `cost_price`** (bukan
   menganggap modalnya 0) — `SUM(CASE WHEN cost_price IS NOT NULL THEN
   line_total - cost_price*qty ELSE 0 END)`. Kalau item tanpa modal
   dianggap modal=0, laba akan OVERSTATED (seolah untung penuh harga
   jual), padahal PRD §3.1.D eksplisit menyebut laba kotor dihitung
   "jika harga modal diisi" — jadi item tanpa modal memang sengaja tidak
   ikut menyumbang laba maupun rugi ke angka ini.
5. **`ReportDateRange` SELALU membulatkan `end` ke akhir hari
   (`23:59:59.999`)**, bukan jam saat ini — supaya "Hari ini" tetap
   memuat transaksi yang terjadi setelah laporan dibuka (mis. buka
   laporan jam 10 pagi, ada transaksi baru jam 2 siang, refresh laporan
   tetap dapat data lengkap tanpa perlu mengubah rentang tanggal).
6. **`watchLowStockCount`/`watchLowStock` dibangun dengan query builder
   Drift + fungsi `coalesce()` bawaan** (`stock <= COALESCE
   (low_stock_threshold, defaultThreshold)`), BUKAN `customSelect` raw
   SQL seperti `ReportRepositoryImpl` — dipilih karena kondisinya cukup
   sederhana untuk diekspresikan lewat query builder type-safe (tanpa
   join/`GROUP BY` kompleks), dan hasil `watch()`-nya otomatis reaktif
   mengikuti tabel `products` (dipakai badge tab Produk yang harus
   auto-update tiap ada penjualan/penyesuaian stok), sesuatu yang lebih
   langsung didapat lewat API stream Drift dibanding `customSelect`
   manual.
7. **Kerja paralel dengan Milestone 5 pada `main` yang sama (BUKAN
   worktree terpisah)** — kedua agent benar-benar mengedit file di
   direktori kerja yang sama secara bersamaan. Beberapa dampak konkret
   yang ditemukan & ditangani selama pengerjaan:
   - `lib/domain/repositories/repository_exceptions.dart` diedit oleh
     KEDUA agent hampir bersamaan (M4 menambah 3 exception penyesuaian
     stok, M5 menambah exception PIN/backup) — kedua blok akhirnya
     tergabung otomatis di file yang sama lewat operasi *string-replace*
     berurutan (tidak ada yang hilang, hanya urutan blok berbeda dari
     yang diperkirakan), lalu ter-commit oleh M5 sebelum M4 sempat
     commit sendiri — jadi commit M4 di file ini TIDAK ADA (sudah
     dibawa oleh commit M5 `29c2dc2`).
   - Sebelum tiap `git push`, working tree WAJIB bersih untuk `git pull
     --rebase`. Karena M5 kerap punya perubahan belum ter-commit
     (`lib/features/settings/...`, di luar wilayah M4) saat M4 siap
     push, dipakai `git stash push -u -- <path-milik-M5>` (BUKAN `git
     stash` polos yang akan ikut menyertakan perubahan M4 sendiri) untuk
     menyisihkan SEMENTARA hanya file M5, lalu `git pull --rebase` +
     `git push`, lalu `git stash pop` segera setelahnya untuk
     mengembalikan pekerjaan M5 yang belum di-commit itu — tanpa
     kehilangan satu baris pun perubahan siapa pun.
   - Tidak ada file di `lib/features/settings/`, `lib/data/services/`,
     atau `docs/plan.md` yang disentuh oleh pekerjaan M4 ini, sesuai
     batas wilayah yang ditugaskan.

---

## 4. Status Analyze & Test

```
$ flutter analyze
Analyzing aplikasi-kasir...
No issues found! (ran in 2.0s)

$ flutter test
00:06 +194: All tests passed!
```

Test baru Milestone 4 (semuanya lulus, tidak ada test lama yang
diregresi):
- `test/data/repositories/stock_repository_impl_test.dart` — 10 test
  (Drift in-memory): `adjust_in`/`adjust_out` mengubah stok & mencatat
  `qtyChange` bertanda benar, `opname` menyetel stok ABSOLUT (baik naik
  maupun turun dari stok sekarang) dengan `qtyChange` = selisih,
  `ProdukTidakDitemukanException` untuk produk tidak ada TANPA
  menyisakan baris `stock_movements` (atomik), `getMovements`
  berpaginasi terbaru dulu, hanya mengembalikan milik `productId` yang
  diminta, dan menyertakan nomor invoice referensi lewat join.
- `test/domain/usecases/adjust_stock_usecase_test.dart` — 9 test (fake
  repository, tanpa DB): menerima jumlah valid & men-trim alasan,
  menolak jumlah ≤0 (masuk/keluar) atau negatif (opname), menerima
  opname dengan hasil 0, menolak alasan kosong/null/spasi, menolak jenis
  tidak dikenal — SEMUA kasus penolakan dipastikan TIDAK memanggil
  repository sama sekali.
- `test/data/repositories/report_repository_impl_test.dart` — 14 test
  (Drift in-memory, termasuk 1 test end-to-end lewat `SaveSaleUsecase`
  sungguhan): omzet & jumlah transaksi = SUM/COUNT non-voided dalam
  rentang, **transaksi voided DIKECUALIKAN** (diuji eksplisit dengan 3
  status sekaligus dalam 1 test), laba kotor benar utk item ber-modal &
  0 untuk item tanpa modal, laba kotor mengecualikan item dari transaksi
  voided, per metode bayar terkelompok benar, rentang kosong
  menghasilkan 0 (bukan error/null), produk terlaris terkelompok &
  terurut benar (qty maupun nilai), produk terlaris mengecualikan
  voided, `limit` dihormati, hutang per pelanggan terkelompok & terurut
  dari terbesar, dan `getDebtTransactions` hanya mengembalikan milik
  pelanggan yang diminta.
- `test/data/repositories/report_repository_impl_performance_test.dart`
  — 1 test: **50.000 baris `sales` + 50.000 `sale_items`** (+300 produk
  pendukung FK) di-generate lewat `db.batch()` (bulk insert, BUKAN lewat
  `saveSale` satu-satu), lalu `getSummary`/`getTopProducts`/
  `getUnpaidDebts` diukur dengan `Stopwatch` — ketiganya **<1 detik**
  (dijalankan sungguhan: total test termasuk insert 50rb baris selesai
  dalam ~4 detik keseluruhan).
- `test/data/repositories/product_repository_impl_test.dart` — +4 test:
  `watchLowStockCount` menghitung benar (threshold per-produk ATAU
  default), mengabaikan produk nonaktif, `watchLowStock` urut stok
  tersedikit dulu, dan bersifat reaktif (emit ulang saat stok berubah).

---

## 5. Hal yang Belum Selesai / Di Luar Scope M4

- **Nilai `settings.low_stock_default` belum bisa diisi pengguna** dari
  layar Pengaturan M4 sendiri — itu memang scope Milestone 5 (layar
  Pengaturan penuh). Kontrak (`SettingsRepository.getValue`) dan key
  (`low_stock_default`) sudah disiapkan; begitu M5 menulis nilai itu
  (lewat fitur pengaturan mereka), M4 langsung memakainya tanpa
  perubahan kode.
- **Widget test end-to-end** untuk layar penyesuaian stok/riwayat
  stok/dashboard laporan belum ditulis — mengikuti pola M2/M3
  (cakupan test difokuskan ke unit/DB test repository & usecase, bukan
  widget test, sesuai instruksi tugas eksplisit "test unit ... angka
  omzet/laba benar, void dikecualikan, hutang per pelanggan").
- **Export Excel/laporan & PDF** tetap Milestone 5 (di luar cakupan M4).

---

## 6. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter run           # perlu device/emulator Android
```

Tab **Produk**: ikon segitiga peringatan (dengan badge jumlah) di AppBar
membuka layar "Stok Menipis"; badge yang sama muncul di ikon tab Produk
pada navigasi bawah. Buka salah satu produk (mode ubah) untuk melihat
tombol "Sesuaikan Stok" (masuk/keluar/opname + alasan wajib) dan "Riwayat
Stok" (daftar pergerakan, infinite scroll).

Tab **Laporan**: dashboard menampilkan omzet/jumlah transaksi/laba
kotor/per-metode-bayar untuk rentang aktif (default "Hari ini"); chip
preset (Hari ini/Kemarin/7 Hari/Bulan Ini/Custom) untuk mengganti
rentang; daftar produk terlaris dengan toggle urutan Qty/Nilai; ikon
struk di AppBar membuka "Hutang Belum Lunas" (total per pelanggan, tap →
daftar transaksinya → detail transaksi lengkap dengan opsi pelunasan,
reuse layar Milestone 3).
