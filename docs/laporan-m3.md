# Laporan Milestone 3 — Pembayaran Non-Tunai, Hutang, Riwayat, Void

**Tanggal:** 11 Agustus 2026
**Acuan:** [prd.md](prd.md) · [architecture.md](architecture.md) · [plan.md](plan.md) ·
[laporan-m0.md](laporan-m0.md) · [laporan-m1.md](laporan-m1.md) · [laporan-m2.md](laporan-m2.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 3 di `plan.md` selesai dikerjakan: sheet
pembayaran di Kasir kini mendukung tiga metode (Tunai/Non-tunai/Hutang),
layar Riwayat (gantikan stub M0) dengan filter tanggal/metode/status dan
infinite scroll terpaginasi, layar Detail Transaksi yang me-reuse
`ReceiptWidget`/`ReceiptService` (M2) untuk menampilkan rincian & share
ulang struk, pelunasan hutang, dan void transaksi (pengembalian stok +
`stock_movements` dalam satu `db.transaction()`, dengan hook PIN siap
pakai untuk Milestone 5).

`flutter analyze` bersih (0 issue). `flutter test` → **128/128 test
lulus** (106 dari M0–M2, ditambah 22 test baru M3 — lihat §4). `flutter
build apk --debug` sukses.

---

## 2. Yang Dikerjakan

### 2.1 Domain — entity, kontrak repository, exception, usecase

- `lib/domain/entities/sale.dart` — **`Sale`**: header transaksi (TANPA
  daftar item) khusus untuk baris daftar Riwayat, supaya layar daftar
  tidak perlu memuat `sale_items` tiap baris.
- `lib/domain/entities/sale_result.dart` — ditambah field `status`
  (default `'completed'`), `voidedAt`, `debtPaidAt` — supaya `SaleResult`
  (sebelumnya hanya dipakai layar sukses checkout M2) bisa DIPAKAI ULANG
  sebagai hasil `SaleRepository.getDetail` (header + item lengkap) di
  layar Detail Transaksi, termasuk untuk share ulang struk lewat
  `ReceiptService`/`ReceiptWidget` — TIDAK ada widget/format struk baru
  yang ditulis ulang.
- `lib/domain/repositories/sale_repository.dart` — ditambah 4 method
  kontrak: `getHistory` (filter tanggal/metode/status + `LIMIT`/`OFFSET`
  untuk pagination), `getDetail`, `markDebtPaid`, `voidSale`.
- `lib/domain/repositories/repository_exceptions.dart` — ditambah
  `TransaksiTidakDitemukanException`, `TransaksiBukanHutangException`,
  `TransaksiSudahDibatalkanException` (pesan Bahasa Indonesia siap tampil).
- `lib/domain/repositories/settings_repository.dart` — kontrak MINIMAL
  (`getValue(key)`) khusus hook PIN sebelum void (lihat §2.4); implementasi
  penuh (profil toko, set/ubah PIN) adalah scope Milestone 5.
- `lib/domain/usecases/mark_debt_paid_usecase.dart` — **`MarkDebtPaidUsecase`**:
  validasi transaksi ada & berstatus `debt_unpaid` sebelum delegasi ke
  `SaleRepository.markDebtPaid`.
- `lib/domain/usecases/void_sale_usecase.dart` — **`VoidSaleUsecase`**:
  validasi transaksi ada & belum pernah di-void sebelum delegasi ke
  `SaleRepository.voidSale`. Konfirmasi UI & gerbang PIN dilakukan DI LUAR
  usecase (di layar), sesuai pemisahan tanggung jawab yang sama dengan
  `SaveSaleUsecase` (M2).

### 2.2 Data — implementasi repository

- `lib/data/repositories/sale_repository_impl.dart` — ditambah:
  - `getHistory`: query Drift dengan filter opsional (`createdAt` rentang
    inklusif, `paymentMethod`, `status`) + `orderBy(createdAt DESC)` +
    `limit(limit, offset: offset)`, memakai index `sales(created_at)`/
    `sales(status)` yang sudah ada dari M0 (architecture.md §4).
  - `getDetail`: satu query `sales` by id + satu query `sale_items` by
    `saleId`, digabung jadi `SaleResult` lengkap. Melempar
    `TransaksiTidakDitemukanException` bila `saleId` tidak ada.
  - `markDebtPaid`: update `status` -> `'completed'`, `debtPaidAt` -> now.
  - `voidSale`: **SATU `db.transaction()`** — cek transaksi ada & belum
    voided (defensif, di samping validasi usecase), loop `sale_items`:
    item terdaftar (`productId != null`) -> stok dikembalikan
    (`product.stock + item.qty`) + insert
    `stock_movements(type='void_return', qtyChange: +qty, ...)`; item
    bebas (`productId == null`) DILEWATI SAMA SEKALI (plan.md poin 6) —
    lalu update `sales.status` -> `'voided'`, `voidedAt` -> now. Persis
    mengikuti architecture.md §4 poin 2.
- `lib/data/repositories/settings_repository_impl.dart` — `getValue`
  sederhana: `SELECT value FROM settings WHERE key = ?`.

### 2.3 Sheet pembayaran non-tunai & hutang (Kasir)

`lib/features/pos/widgets/payment_sheet.dart` dirombak dari sheet
tunai-saja (M2) menjadi sheet dengan pemilih metode (`_MethodButton`
Tunai/Non-tunai/Hutang) + form berbeda per metode (dibangun lewat
private builder method di `_PaymentSheetState`, BUKAN widget terpisah,
supaya bisa memanggil `setState` langsung tanpa memicu lint
`invalid_use_of_protected_member`):
- **Tunai** — alur M2 tidak berubah (input uang, pecahan cepat,
  kembalian).
- **Non-tunai** — `ChoiceChip` jenis (QRIS/Transfer Bank/Kartu/Lainnya —
  "Lainnya" membuka input teks bebas), `paidAmount` otomatis diisi
  `total` (lunas seketika), jenisnya disimpan ke `sales.note` (lihat
  keputusan §3). Banner kecil menegaskan "tanpa integrasi" sesuai PRD §3.1.A.
- **Hutang** — `TextField` nama pelanggan WAJIB (validasi UI: error text +
  tombol bayar disabled bila kosong; `NamaPelangganWajibException` M2 tetap
  jadi lapis kedua di usecase), catatan opsional, `paidAmount = 0`.

`lib/features/pos/providers/sale_providers.dart` ditambah
`markDebtPaidUsecaseProvider` & `voidSaleUsecaseProvider`.

### 2.4 Hook PIN (siapan Milestone 5)

- `lib/core/utils/pin_hasher.dart` — `PinHasher.hash(pin)` (SHA-256, via
  package `crypto` yang baru ditambahkan — `crypto: ^3.0.7`, resolve
  bersih tanpa konflik versi).
- `lib/features/settings/providers/settings_providers.dart` —
  `settingsRepoProvider`.
- `lib/features/transactions/utils/pin_gate.dart` — `checkPinGate(context,
  ref)`: baca `settings.pin_hash` — `null`/kosong (KONDISI NORMAL di M3,
  karena layar set-PIN M5 belum dibuat, jadi tidak ada UI yang bisa
  mengisi `pin_hash`) -> lolos TANPA dialog apa pun; terisi -> dialog input
  PIN, dibandingkan via `PinHasher.hash`. Dipanggil SEBELUM
  `VoidSaleUsecase` di `SaleDetailScreen._voidSale`.

### 2.5 Layar Riwayat Transaksi

- `lib/features/transactions/providers/history_providers.dart`:
  - `HistoryFilter` + `HistoryFilterNotifier` (`NotifierProvider`) —
    rentang tanggal, metode bayar, status; diterapkan lewat tombol
    "Terapkan" di sheet filter (BUKAN debounce tiap ketukan, beda dari
    filter pencarian produk/kasir M1/M2).
  - `HistoryState` + `HistoryListNotifier` (`AsyncNotifier`) — `build()`
    mengamati `historyFilterProvider` (otomatis reset & muat ulang
    halaman pertama saat filter berubah), `loadMore()` menambah halaman
    berikutnya (infinite scroll), `refresh()` (`invalidateSelf` + `await
    future`) dipanggil setelah void/pelunasan berhasil.
  - `saleDetailProvider` — `FutureProvider.autoDispose.family<SaleResult,
    int>` untuk layar Detail.
- `lib/features/transactions/screens/transactions_screen.dart` (ganti stub
  M0): `ListView.separated` + `ScrollController` yang memicu `loadMore()`
  200px sebelum akhir daftar, `RefreshIndicator` (pull-to-refresh), tombol
  filter di AppBar dengan indikator titik saat filter aktif, empty state
  membedakan "belum ada transaksi" vs "tidak ada yang cocok dengan filter".
- `lib/features/transactions/widgets/history_filter_sheet.dart` — sheet
  filter: `showDateRangePicker` bawaan Flutter (localized `id_ID`, sudah
  terpasang dari M0), `ChoiceChip` metode bayar & status, tombol
  Reset/Terapkan.
- `lib/features/transactions/widgets/history_tile.dart` &
  `status_badge.dart` — baris daftar + badge status
  (`completed`->"Lunas" hijau, `debt_unpaid`->"Hutang" kuning,
  `voided`->"Batal" merah + invoice dicoret), label metode bayar Indonesia.

### 2.6 Layar Detail Transaksi, pelunasan hutang, dan void

`lib/features/transactions/screens/sale_detail_screen.dart`:
- Menampilkan `ReceiptWidget(sale: sale)` (REUSE PENUH dari M2, tidak ada
  duplikasi tampilan item/qty/harga/diskon/total/pembayaran/kembalian)
  dibungkus `RepaintBoundary`, plus banner info kontekstual (voided -> kapan
  dibatalkan; debt_unpaid -> peringatan belum lunas; lunas dari hutang ->
  kapan dilunasi).
- Tombol "Bagikan Teks"/"Bagikan Gambar" — persis pola
  `checkout_success_screen.dart` M2 (`boundary.toImage` ->
  `ReceiptService.shareAsImage`/`shareAsText`), TIDAK ada logic share baru
  ditulis dari nol.
- Tombol **"Tandai Lunas"** (hanya tampil bila `status == 'debt_unpaid'`):
  dialog konfirmasi -> `MarkDebtPaidUsecase` -> invalidate
  `saleDetailProvider` + `historyListProvider.refresh()`.
- Tombol **"Batalkan Transaksi"** (tampil selama `status != 'voided'`,
  termasuk transaksi hutang — membatalkan hutang yang salah catat juga
  valid): dialog konfirmasi (destructive, warna merah) -> `checkPinGate`
  -> `VoidSaleUsecase` -> invalidate provider terkait. Transaksi yang
  sudah voided TETAP tampil di Riwayat & Detail dengan `StatusBadge`
  "Batal" (dicoret di daftar) — TIDAK PERNAH dihapus, sesuai plan.md poin
  5 & architecture.md §4.

---

## 3. Keputusan Teknis

1. **Jenis pembayaran non-tunai disimpan di `sales.note`** (kolom yang
   sudah ada sejak M0), BUKAN kolom skema baru — PRD §3.1.A hanya minta
   "dicatat jenisnya", dan laporan per metode bayar (M4) tetap
   mengelompokkan lewat `payment_method` (`cash`/`noncash`/`debt`), bukan
   sub-jenisnya. Menghindari migrasi skema untuk kebutuhan yang cukup
   ditampung field existing.
2. **Hook PIN minimal, bukan sistem PIN penuh** — sesuai instruksi tugas
   eksplisit "PIN baru dibuat di M5, jadi cukup siapkan hook/cek
   settingnya". `checkPinGate` HANYA mengecek `settings.pin_hash`; karena
   layar set-PIN M5 belum ada, `pin_hash` akan selalu `null` di M3 —
   hook ini otomatis "diam" (tidak pernah menampilkan dialog) sampai M5
   selesai. `PinHasher` (SHA-256) sengaja ditambah lebih awal (bukan
   ditunda ke M5) supaya M5 tinggal MENULIS `pin_hash` dengan hasher yang
   sama, tidak perlu migrasi ulang nilai lama.
3. **Riwayat memakai pagination `LIMIT`/`OFFSET` via `AsyncNotifier`,
   BUKAN `Stream` reaktif** seperti `productListProvider` (M1) — PRD §6
   mensyaratkan skala hingga 100.000 transaksi, jadi memuat/diff seluruh
   tabel `sales` lewat stream tidak realistis. Konsekuensinya: Riwayat
   TIDAK auto-update realtime saat ada transaksi baru dari layar lain
   (beda dengan daftar Produk) — `RefreshIndicator` (pull-to-refresh) dan
   `refresh()` eksplisit setelah void/pelunasan dipakai sebagai
   gantinya. Ini konsisten dengan sifat halaman riwayat (baca-mostly,
   perubahan data terjadi lewat aksi eksplisit pengguna, bukan proses
   background).
4. **`SaleResult` diperluas (bukan entity `SaleDetail` baru)** untuk hasil
   `getDetail` — field baru (`status`/`voidedAt`/`debtPaidAt`) semua
   punya default aman sehingga `SaveSaleUsecase`/`SaleRepositoryImpl.saveSale`
   (M2) TIDAK perlu diubah pemanggilannya. Manfaat utama: `ReceiptWidget`
   dan `ReceiptService` (M2) langsung REUSE 100% tanpa modifikasi untuk
   layar Detail — sesuai instruksi eksplisit tugas ("share ulang struk,
   reuse receipt_service M2").
5. **`PaymentSheet` memakai private builder method (bukan `StatelessWidget`
   terpisah) untuk form per metode** — percobaan awal memisahkan
   `_CashForm`/`_NoncashForm`/`_DebtForm` sebagai widget sendiri yang
   memanggil `state.setState()` dari luar `State` memicu lint
   `invalid_use_of_protected_member` (`flutter analyze` tidak bersih).
   Builder method di dalam `_PaymentSheetState` menghindari masalah ini
   sekaligus tetap mudah dibaca.
6. **`voidSale` melakukan validasi status DUA LAPIS** — `VoidSaleUsecase`
   (domain, mengecek via `getDetail` sebelum menulis) DAN
   `SaleRepositoryImpl.voidSale` (data, mengecek ulang status DI DALAM
   `db.transaction()` sebelum mengembalikan stok). Lapis kedua ini
   mencegah stok dikembalikan dua kali seandainya void dipicu dua kali
   nyaris bersamaan (walau PRD §8 "satu perangkat = satu toko" berarti
   risiko konkurensi sangat rendah, biaya proteksinya kecil) — diuji
   eksplisit di `sale_repository_impl_test.dart`.
7. **Item bebas (`product_id NULL`) dilewati total saat void** — tidak
   ada baris `stock_movements` yang dibuat untuknya sama sekali (bukan
   dibuat lalu diabaikan), sama seperti perlakuannya saat `saveSale` (M2)
   — konsisten dengan prinsip "item bebas tidak pernah menyentuh stok
   produk apa pun".

---

## 4. Status Analyze & Test

```
$ flutter analyze
Analyzing aplikasi-kasir...
No issues found! (ran in 1.5s)

$ flutter test
00:07 +128: All tests passed!

$ flutter build apk --debug
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

Rincian 22 test baru Milestone 3 (106 lama dari M0–M2 tetap lulus semua):
- `test/data/repositories/sale_repository_impl_test.dart` — +11 test
  (Drift in-memory):
  - **Riwayat & pagination (4):** urutan terbaru dulu + `LIMIT`/`OFFSET`
    tanpa duplikat antar halaman, filter status, filter `paymentMethod`,
    filter rentang tanggal inklusif.
  - **Detail (2):** header+item sesuai tersimpan, `TransaksiTidakDitemukanException`
    untuk id tidak ada.
  - **Pelunasan hutang (1):** status `debt_unpaid` -> `completed` +
    `debt_paid_at` terisi.
  - **Void (4):** stok dikembalikan TEPAT per produk (multi-item) +
    `stock_movements(void_return)` benar, item bebas TIDAK disentuh
    (hanya 1 baris `void_return` walau ada 2 item di transaksi),
    `TransaksiTidakDitemukanException` untuk id tidak ada,
    `TransaksiSudahDibatalkanException` saat void dipanggil dua kali DAN
    stok TIDAK dikembalikan dobel.
- `test/domain/usecases/mark_debt_paid_usecase_test.dart` — 3 test (fake
  repository, tanpa DB): memanggil repo bila `debt_unpaid`, menolak bila
  `completed`, menolak bila `voided`.
- `test/domain/usecases/void_sale_usecase_test.dart` — 3 test (fake
  repository): memanggil repo bila belum voided (baik `completed` maupun
  `debt_unpaid`), menolak bila sudah `voided`.
- `test/data/repositories/settings_repository_impl_test.dart` — 2 test:
  `getValue` null saat belum diisi, mengembalikan nilai tersimpan.
- `test/core/utils/pin_hasher_test.dart` — 3 test: deterministik, PIN
  beda -> hash beda, hash bukan plaintext PIN.
- `test/domain/usecases/save_sale_usecase_test.dart` — `_FakeSaleRepository`
  diperbarui (menambah 4 method baru dari `SaleRepository` yang bertambah)
  supaya tetap compile; tidak ada test baru di file ini, murni penyesuaian
  interface.

---

## 5. Hal yang Belum Selesai / Di Luar Scope M3

- **Sistem PIN penuh** (layar set/ubah/hapus PIN di Pengaturan) — Milestone
  5, sesuai instruksi tugas. Hook (`checkPinGate`) sudah siap dipakai.
- **Riwayat pergerakan stok per produk, penyesuaian stok manual** —
  Milestone 4.
- **Laporan per metode bayar / daftar hutang belum lunas (dashboard)** —
  Milestone 4 (Riwayat M3 sudah bisa memfilter status `debt_unpaid` sebagai
  jalan pintas manual, tapi belum ada agregasi "total per pelanggan").
- **Profil toko di struk** (nama/alamat/telp toko sungguhan) — tetap
  Milestone 5, tidak berubah dari catatan M2.
- **Widget test end-to-end** untuk sheet pembayaran/riwayat/detail belum
  ditulis — di luar permintaan eksplisit tugas M3 ("Test: void
  mengembalikan stok tepat ..., pelunasan hutang mengubah status benar,
  filter riwayat", semuanya sudah dipenuhi lewat unit/DB test di §4 tanpa
  widget test, mengikuti pola M2).

---

## 6. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter run           # perlu device/emulator Android
```

Tab **Riwayat**: daftar transaksi terbaru dulu, scroll ke bawah untuk
memuat lebih banyak, tombol filter (ikon corong) di AppBar untuk
tanggal/metode/status. Tap satu baris -> Detail Transaksi: lihat struk
lengkap, bagikan ulang (teks/gambar), "Tandai Lunas" (khusus hutang),
"Batalkan Transaksi" (void, konfirmasi + PIN bila sudah diaktifkan lewat
M5 nanti). Sheet pembayaran di Kasir sekarang punya 3 pilihan metode di
bagian atas: Tunai/Non-tunai/Hutang.
