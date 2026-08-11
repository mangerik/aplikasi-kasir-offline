# Laporan Milestone 2 — Kasir (POS) Inti

**Tanggal:** 11 Agustus 2026
**Acuan:** [prd.md](prd.md) · [architecture.md](architecture.md) · [plan.md](plan.md) ·
[laporan-m0.md](laporan-m0.md) · [laporan-m1.md](laporan-m1.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 2 di `plan.md` selesai dikerjakan: `cartProvider`
(Riverpod Notifier in-memory dengan diskon per item/transaksi & item bebas),
layar Kasir adaptif HP portrait (grid + pencarian + filter kategori + bar
keranjang) dan tablet dua panel (breakpoint ≥600dp), scan barcode via kamera,
sheet pembayaran tunai (pecahan cepat + kembalian otomatis + validasi uang
cukup), usecase simpan penjualan **atomik** (insert `sales` + `sale_items` +
update stok + `stock_movements` dalam satu `db.transaction()`, plus generator
nomor invoice harian anti-duplikat), layar sukses transaksi dengan struk
digital yang bisa dibagikan sebagai gambar (`RepaintBoundary` + `share_plus`)
maupun teks, dan hold/parkir keranjang ke tabel `held_carts` + daftar &
lanjutkan transaksi yang diparkir.

`flutter analyze` bersih (0 issue). `flutter test` → **106/106 test lulus**
(66 dari M0+M1, ditambah 40 test baru M2 — lihat §4). `flutter build apk
--debug` sukses.

---

## 2. Yang Dikerjakan

### 2.1 Domain — entity, kontrak repository, usecase

- `lib/domain/entities/cart_item.dart` — `CartItem`: satu baris keranjang
  (`key` unik non-DB, `productId` nullable untuk item bebas, `qty` REAL,
  `sellPrice`/`costPrice` snapshot, `discount` SELALU nominal). Getter
  `grossTotal` (`sellPrice * qty`, dibulatkan) dan `lineTotal`
  (`grossTotal - discount`, di-*clamp* `0..grossTotal`). Punya
  `toJson`/`fromJson` murni Dart (dipakai serialisasi hold, lihat §2.3).
- `lib/domain/entities/sale_result.dart` — `SaleResult` + `SaleResultItem`:
  hasil `saveSale`, dipakai layar sukses transaksi/struk.
- `lib/domain/entities/held_cart.dart` — `HeldCart`: representasi baris
  `held_carts` yang sudah di-deserialize (list `CartItem` + diskon
  transaksi).
- `lib/domain/repositories/sale_repository.dart`,
  `held_cart_repository.dart` — kontrak abstrak baru.
- `lib/domain/repositories/product_repository.dart` — ditambah
  `getByBarcode(String)` (dipakai hasil scan di layar Kasir).
- `lib/domain/repositories/repository_exceptions.dart` — ditambah
  `KeranjangKosongException`, `UangTidakCukupException` (pesan format Rupiah
  lewat `CurrencyFormatter`, jadi domain kini meng-import `core/utils` —
  aman karena `core` adalah leaf module tanpa dependency balik),
  `NamaPelangganWajibException`.
- `lib/domain/usecases/save_sale_usecase.dart` — **`SaveSaleUsecase`**:
  satu-satunya pintu masuk `features/pos` untuk menyimpan transaksi.
  Tanggung jawabnya MURNI validasi & orkestrasi domain (keranjang tidak
  boleh kosong, uang tunai wajib cukup, nama pelanggan wajib untuk hutang,
  diskon transaksi di-*clamp* ke subtotal) — lalu delegasi ke
  `SaleRepository.saveSale` untuk penulisan atomik. Ini folder
  `domain/usecases/` baru (belum ada sebelumnya).

### 2.2 Data — implementasi repository & service

- `lib/data/repositories/sale_repository_impl.dart` — **`SaleRepositoryImpl`**:
  seluruh penulisan (insert `sales`, insert semua `sale_items`, update
  `products.stock` untuk item terdaftar, insert
  `stock_movements(type='sale')`, generator nomor invoice) dibungkus SATU
  `db.transaction()` persis mengikuti architecture.md §4 poin 1 & 4. Nomor
  invoice `YYYYMMDD-XXXX` dibangkitkan via query
  `SELECT invoice_number ... WHERE invoice_number LIKE 'YYYYMMDD-%' ORDER BY
  invoice_number DESC LIMIT 1` lalu +1, dijalankan DI DALAM transaksi yang
  sama dengan insert `sales`-nya sendiri. Item bebas (`productId == null`)
  dilewati dari update stok/`stock_movements`.
- `lib/data/repositories/held_cart_repository_impl.dart` —
  **`HeldCartRepositoryImpl`**: serialisasi keranjang ke JSON
  (`jsonEncode({'items': [...], 'transactionDiscount': ...})`) disimpan di
  `held_carts.cart_json`. Mengikuti pola prefix `db.` yang sama dengan
  `ProductRepositoryImpl`/`CategoryRepositoryImpl` (kelas baris Drift
  `HeldCart` bertabrakan nama dengan entity domain `HeldCart`).
- `lib/data/repositories/product_repository_impl.dart` — ditambah
  `getByBarcode` (query `barcode.equals(...) & isActive.equals(true)`,
  memakai partial unique index `idx_products_barcode_unique` dari M0).
- `lib/data/services/receipt_service.dart` — **`ReceiptService`**: format
  struk sebagai teks monospace (`formatReceiptText`) dan dua method share
  (`shareAsText`, `shareAsImage`) memakai `SharePlus.instance.share(
  ShareParams(...))` (API `share_plus` 12.x yang TIDAK deprecated — method
  statis lama `Share.share`/`Share.shareXFiles` sengaja dihindari karena
  ditandai `@Deprecated` dan akan memicu peringatan `flutter analyze`).
  `shareAsImage` menulis PNG hasil capture `RepaintBoundary` ke file
  sementara (`path_provider`) sebelum dibagikan sebagai `XFile`.

### 2.3 `cartProvider` (Riverpod Notifier in-memory)

`lib/features/pos/providers/cart_provider.dart` — `CartState` (list
`CartItem` + `transactionDiscount` nominal, getter `subtotal`/`total`/
`totalQty`/`lineCount`) dan `CartNotifier`:
- `addProduct(product, {qty})` — produk yang sama menambah qty baris yang
  sudah ada (key `'p_<productId>'`), bukan baris baru.
- `addFreeItem({name, price, qty, unit})` — SELALU baris baru (key unik
  `'f_<timestamp>_<counter>'`), `productId` tetap null (plan.md: "item
  bebas nama + harga manual").
- `incrementQty`/`decrementQty` (turun ≤0 → baris otomatis terhapus),
  `setQty` (mendukung desimal untuk satuan kg/liter), `removeItem`.
- `setItemDiscount(key, nominal)` / `setTransactionDiscount(nominal)` —
  **SELALU nominal**, di-*clamp* ke `grossTotal` baris / `subtotal`
  keranjang. UI (`DiscountDialog`, lihat §2.4) yang menyediakan input
  persen mengonversi ke nominal SEBELUM memanggil method ini — pemenuhan
  literal plan.md poin 1: "diskon per item (nominal/%→disimpan nominal)".
- `clear()`, `loadHeldCart(HeldCart)` — dipakai alur hold/lanjutkan (§2.7).

Provider terpisah `posProductFilterProvider`/`posProductListProvider`
(`lib/features/pos/providers/pos_product_providers.dart`) meng-*reuse*
`productRepoProvider` dari fitur Produk (tetap lewat kontrak
`ProductRepository`, bukan Drift langsung), dengan `onlyActive: true`
selalu aktif dan debounce **150ms** (architecture.md §5.1 — beda dari 300ms
di layar Produk M1 karena Kasir butuh respons lebih instan saat transaksi
berlangsung).

### 2.4 Layar Kasir — HP portrait & tablet dua panel

`lib/features/pos/screens/pos_screen.dart` (gantikan stub M0):
`LayoutBuilder` di breakpoint `AppSizes.tabletBreakpoint` (600dp, sudah ada
dari M0): `Row(ProductGrid | CartPanel tetap 400dp)` untuk tablet,
`Column(ProductGrid, CartSummaryBar)` untuk HP. AppBar punya tombol
"Transaksi ditahan" dengan badge jumlah hold.

- `lib/features/pos/widgets/product_grid.dart` — pencarian + chip kategori
  (pola sama `ProductsScreen` M1) + `GridView.builder` produk AKTIF saja +
  tombol scan barcode + tombol item bebas. Tap kartu produk →
  `cartProvider.addProduct`; badge qty kecil muncul di kartu bila produk
  sudah ada di keranjang.
- `lib/features/pos/widgets/cart_panel.dart` — isi keranjang lengkap
  (dipakai baik di sheet HP maupun panel tetap tablet): list item
  (`CartItemTile`), baris subtotal/diskon transaksi (tap → `DiscountDialog`)
  /total, tombol "Tahan" & "Bayar".
- `lib/features/pos/widgets/cart_summary_bar.dart` — bar ringkas bawah HP,
  tap membuka `CartPanel` dalam `showModalBottomSheet` (`FractionallySizedBox`
  90% tinggi layar).
- `lib/features/pos/widgets/cart_item_tile.dart` — qty stepper (+/-, tap
  angka untuk input manual/desimal), tombol diskon per item, hapus.
- `lib/features/pos/widgets/discount_dialog.dart` — dialog diskon BERSAMA
  untuk item & transaksi: toggle mode Rp/%, hasil selalu dikonversi & di-
  *clamp* ke nominal sebelum dikembalikan.
- `lib/features/pos/widgets/free_item_dialog.dart` — form item bebas (nama,
  harga, qty, satuan).

### 2.5 Scan barcode → tambah ke keranjang

`ProductGrid._scanBarcode()` mendorong `BarcodeScannerPage` (di-*reuse*
langsung dari `features/products/widgets/barcode_scanner_page.dart`, sesuai
instruksi "reuse pola scanner M1" — tidak ada file scanner baru dibuat).
Hasil barcode dicari lewat `ProductRepository.getByBarcode` (baru, §2.1/2.2);
ditemukan → langsung `cartProvider.addProduct`; tidak ditemukan → SnackBar
Bahasa Indonesia.

### 2.6 Sheet pembayaran tunai

`lib/features/pos/widgets/payment_sheet.dart` — `PaymentSheet`
(`ConsumerStatefulWidget`, dibuka lewat `showModalBottomSheet<SaleResult>`
dari `CartPanel._pay`): input uang diterima, 5 tombol pecahan cepat
(Rp10.000/20.000/50.000/100.000 — MENAMBAH ke nilai saat ini, meniru
kasir sungguhan yang menumpuk lembar uang; dan "Uang Pas" — SET langsung ke
nilai total), kembalian dihitung reaktif (`paid - total`), tombol
"Selesaikan Pembayaran" DISABLED selama `paid < total` (validasi "uang
cukup" di level UI, DIPERKUAT lagi oleh `UangTidakCukupException` di
`SaveSaleUsecase` sebagai lapis kedua). Sukses → memanggil
`SaveSaleUsecase`, mengosongkan `cartProvider`, `Navigator.pop(result)`.

### 2.7 Layar sukses transaksi & struk digital

- `lib/features/pos/widgets/receipt_widget.dart` — `ReceiptWidget`: tampilan
  struk gaya kertas kasir (monospace, lebar tetap 360dp) — nama toko
  (hardcode "KASIR WARUNG" sementara, lihat §3), nomor invoice, tanggal,
  daftar item + diskon, subtotal/diskon/total, tunai/kembalian atau info
  hutang, footer terima kasih.
- `lib/features/pos/screens/checkout_success_screen.dart` —
  `CheckoutSuccessScreen`: ringkasan (total/uang diterima/kembalian),
  `ReceiptWidget` dibungkus `RepaintBoundary` (key global) untuk di-*capture*
  jadi PNG (`boundary.toImage` → `ReceiptService.shareAsImage`), tombol
  "Bagikan Teks" (`ReceiptService.shareAsText`) dan "Bagikan Gambar", tombol
  "Transaksi Baru" (`Navigator.pop`, kembali ke layar Kasir kosong — cart
  sudah dikosongkan sebelumnya oleh `PaymentSheet`). `PopScope(canPop:
  false)` dipasang supaya tombol kembali sistem tetap melalui jalur yang
  sama (tidak ada efek samping tambahan, murni konsistensi UX).

### 2.8 Hold/parkir & lanjutkan transaksi

- `lib/features/pos/providers/held_cart_providers.dart` —
  `heldCartRepoProvider`, `heldCartListProvider` (stream reaktif).
- `CartPanel._hold` — dialog label opsional → `HeldCartRepository.hold`
  (serialisasi JSON, §2.2) → `cartProvider.clear()`.
- `lib/features/pos/screens/held_carts_screen.dart` — `HeldCartsScreen`:
  daftar hold (label/jumlah item/total/waktu), tap **lanjutkan**
  (konfirmasi dulu bila keranjang aktif SEDANG TIDAK kosong — akan
  ditimpa) → `cartProvider.loadHeldCart` + hapus baris hold dari DB;
  tombol hapus permanen per baris.

---

## 3. Keputusan Teknis

1. **Diskon SELALU nominal di storage** (`CartItem.discount`,
   `CartState.transactionDiscount`, `sale_items.discount`,
   `sales.discount`) — sesuai literal plan.md poin 1. Mode persen HANYA
   ada di `DiscountDialog` (UI), dikonversi (`round()`, di-*clamp*
   `0..baseAmount`) sebelum masuk ke provider/DB. Tidak ada kolom/field
   terpisah untuk "mode diskon" karena begitu tersimpan, nilainya sudah
   final (nominal) — mengubah basis harga nantinya tidak akan
   "menghitung ulang" diskon persen lama, ini konsisten dengan sifat
   `sale_items` sebagai snapshot (architecture.md §4).
2. **Generator invoice pakai `MAX(invoice_number) LIKE 'prefix-%'` di dalam
   transaksi** (bukan tabel counter terpisah) — cukup untuk skala
   single-user offline (PRD §8: "satu perangkat = satu toko = satu
   database", tidak ada penulis konkuren). Uniqueness tetap dijaga lapis
   kedua oleh `sales.invoice_number UNIQUE` (dari M0) — race condition
   teoretis akan gagal lewat `SqliteException` alih-alih menghasilkan
   duplikat diam-diam.
3. **`share_plus` API non-deprecated dipilih eksplisit** — `Share.share`/
   `Share.shareXFiles` (method statis lama) DITANDAI `@Deprecated` di
   versi terpasang (12.0.2, lihat laporan-m0.md untuk alasan pin versi).
   `ReceiptService` memakai `SharePlus.instance.share(ShareParams(...))`
   supaya `flutter analyze` tetap 0 issue tanpa perlu `// ignore:
   deprecated_member_use`.
4. **`ProductRepository.getByBarcode` ditambah di M2** (bukan M1) —
   dibutuhkan khusus untuk hasil scan di Kasir (exact match, bukan `LIKE`
   substring seperti pencarian teks). Memakai index yang sama
   (`idx_products_barcode_unique`) dari M0, jadi tidak ada migrasi skema
   baru.
5. **Pembayaran non-tunai & hutang sudah didukung penuh di domain/data**
   (`SaveSaleUsecase` menangani ketiga `paymentMethod`,
   `NamaPelangganWajibException` sudah divalidasi) tapi **UI kasir M2 baru
   membangun alur tunai** — sesuai cakupan resmi checklist M2 (`plan.md`
   hanya menyebut "Sheet pembayaran tunai"). UI pilih metode non-tunai/
   hutang adalah scope eksplisit Milestone 3 (`plan.md`: "Metode non-tunai
   ... & hutang/bon").
6. **`posProductFilterProvider` terpisah dari `ProductFilterNotifier`**
   (fitur Produk) — debounce beda (150ms vs 300ms, sesuai
   architecture.md §5.1) dan `onlyActive` SELALU `true` di Kasir (plan.md:
   "Hanya produk aktif yang tampil"), sementara layar Produk M1 sengaja
   menampilkan semua produk (aktif+nonaktif) dengan badge. Kedua provider
   tetap meng-*reuse* `productRepoProvider` yang sama (satu instance
   repository, bukan duplikasi).
7. **Nama toko di struk sementara hardcode "KASIR WARUNG"** — profil toko
   (nama/alamat/telp, tabel `settings`) adalah scope Milestone 5
   (`plan.md` §F "Pengaturan"). `ReceiptWidget`/`ReceiptService` sudah
   diisolasi supaya penggantian ke `settingsProvider` nanti hanya
   menyentuh satu tempat.
8. **`SingleChildScrollView` dipasang di tiga empty-state** (`CartPanel`,
   `ProductGrid`, `HeldCartsScreen`) alih-alih `Padding`+`Column` polos —
   ditemukan lewat `flutter test`: window test default (800×600) memicu
   layout TABLET (≥600dp) sehingga `CartPanel` mendapat tinggi terbatas di
   panel kanan, dan `Column` empty-state (ikon 64 + 2 baris teks) overflow
   33px. Perbaikan ini juga membuat layar lebih tahan di kondisi nyata
   (tablet layar pendek/landscape).

---

## 4. Status Analyze & Test

```
$ flutter analyze
Analyzing aplikasi-kasir...
No issues found! (ran in 1.7s)

$ flutter test
00:04 +106: All tests passed!

$ flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

Rincian 40 test baru Milestone 2 (66 lama dari M0+M1 tetap lulus semua):
- `test/features/pos/providers/cart_provider_test.dart` — 16 test:
  tambah produk (baris baru vs gabung qty), item bebas (selalu baris baru),
  qty (+/-, turun ke 0 menghapus, set desimal), diskon item & transaksi
  (nominal, di-*clamp*), subtotal/total, clear, `loadHeldCart`.
- `test/domain/usecases/save_sale_usecase_test.dart` — 10 test: validasi
  keranjang kosong, uang tunai kurang/pas, hutang tanpa nama (termasuk
  whitespace), validasi gagal tidak memanggil repo sama sekali, kembalian,
  diskon transaksi di-*clamp* sebelum ke repo, nama/catatan whitespace →
  null, orkestrasi meneruskan data apa adanya (pakai fake `SaleRepository`,
  TANPA database).
- `test/data/repositories/sale_repository_impl_test.dart` — 7 test (Drift
  in-memory): simpan atomik (sales+sale_items+stok+stock_movements), item
  bebas tidak menyentuh stok, diskon item+transaksi tersimpan benar,
  pembayaran hutang (status `debt_unpaid`), invoice berurutan 0001→0002
  hari sama, invoice reset ke 0001 di hari berbeda, **rollback penuh**
  (produk tidak ditemukan di tengah item kedua → item pertama yang sudah
  "berhasil" di step sebelumnya ikut batal, stok TIDAK berubah).
- `test/data/repositories/held_cart_repository_impl_test.dart` — 5 test:
  hold + baca kembali (termasuk qty desimal kg presisi & `costPrice` null
  untuk item bebas), label whitespace → null, `watchAll` reaktif, `getById`
  tidak ada → null, `delete`.
- `test/data/repositories/product_repository_impl_test.dart` — +2 test:
  `getByBarcode` ketemu/tidak ketemu, tidak ketemu untuk produk nonaktif.

---

## 5. Hal yang Belum Selesai / Di Luar Scope M2

- **UI pembayaran non-tunai & hutang** — domain/data sudah siap (lihat §3
  poin 5), UI pemilihan metode & form nama pelanggan adalah scope
  Milestone 3.
- **Void transaksi, riwayat, pelunasan hutang** — Milestone 3.
- **Profil toko di struk** (nama/alamat/telp toko sungguhan, bukan hardcode
  "KASIR WARUNG") — Milestone 5 bersama layar Pengaturan.
- **Widget test end-to-end alur kasir** (tap produk → bayar → sukses) belum
  ditulis — di luar permintaan eksplisit tugas ("Unit test: perhitungan
  keranjang & diskon, kembalian, atomisitas simpan penjualan + rollback +
  invoice berurutan", semuanya sudah dipenuhi di §4 lewat unit/DB test
  tanpa widget test). Widget test golden-path bisa ditambah belakangan bila
  diperlukan sebagai regresi UI.
- **Cetak struk printer thermal** — eksplisit di luar MVP (PRD §3.3, fase
  berikutnya).

---

## 6. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter run           # perlu device/emulator Android
```

Layar Kasir (`/kasir`, tab default): cari/scan produk → tap untuk tambah ke
keranjang → atur qty/diskon → "Tahan" untuk parkir atau "Bayar" untuk bayar
tunai (input uang/pecahan cepat) → struk digital + share gambar/teks.
Tombol "Transaksi ditahan" di AppBar untuk melanjutkan keranjang yang
diparkir sebelumnya.
