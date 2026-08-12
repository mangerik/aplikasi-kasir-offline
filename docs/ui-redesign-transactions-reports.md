# Redesign UI — Transaksi & Laporan

Area: `lib/features/transactions/**` & `lib/features/reports/**`
Design language: **"Kertas & Daun"** (`docs/ui-redesign-foundation.md` — sumber kebenaran)
Tanggal: 12 Agustus 2026 · Status: **selesai**

---

## 1. Ringkasan arah desain

Sebelumnya area ini adalah Material default: `ListTile` beruntun dipisah
`Divider`, badge status berupa `Container` + `withValues(alpha: 0.12)`
buatan sendiri, dan kartu ringkasan laporan yang generik (label sebesar
angkanya, warna dipilih ad-hoc per kartu). Rapi, tapi tidak bercerita.

Empat keputusan yang menyetir seluruh redesign:

1. **Angka dulu, label belakangan.** Setiap nominal dibungkus
   `AppMoneyText` (tabular figures) dan selalu lebih besar/tebal daripada
   labelnya. Label turun jadi `AppTextStyles.eyebrow` (11px kapital).
2. **Status seragam lewat `AppTone`.** Tidak ada lagi warna status
   buatan layar: lunas → `success`, hutang/bon → `accent` (gula aren),
   batal → `danger` (satu-satunya yang `filled: true` karena butuh
   penekanan maksimal), non-tunai → `info`.
3. **Angka yang bisa dibandingkan sekilas.** Komposisi metode bayar,
   peringkat produk terlaris, dan besar hutang per pelanggan memakai bar
   proporsi (`LinearProgressIndicator` bertema) supaya jarak antar angka
   terlihat, bukan cuma terbaca digit per digit.
4. **Empat state selalu ada.** `AppLoadingView` / `EmptyState` /
   `AppErrorView` di setiap cabang `AsyncValue.when`, semuanya dengan
   kalimat pengarah + tombol aksi (bukan "Tidak ada data").

Semua nilai spacing/radius/warna diambil dari token (`AppSizes`,
`AppColors`, `AppTone`, `AppShadows`, `AppTextStyles`) lewat satu import
barrel `core/widgets/app_widgets.dart`. **Tidak ada hex, `Colors.*`,
angka spacing mentah, `Card`, `BoxShadow`, atau `elevation:` Material di
folder ini.** Logika bisnis, provider, query, dan entity **tidak
disentuh** — perubahan murni visual & struktur widget.

---

## 2. Perubahan per berkas

### `transactions/widgets/status_badge.dart`
- `StatusBadge` sekarang membungkus `AppPill` dengan `AppTone` sesuai
  pemetaan foundation §2.5 (+ ikon: centang / jam pasir / blok). Status
  `voided` memakai `filled: true`.
- Tambahan opsi `dense` (untuk list padat) dan `showIcon`.
- Kelas baru `SaleStatusStyle.of(status)` → (label, tone, ikon) supaya
  layar lain (sheet filter, banner) memakai label & nada yang persis sama.
- Helper baru `paymentMethodTone()` & `paymentMethodIcon()` mendampingi
  `paymentMethodLabel()` yang sudah ada — metode bayar kini punya
  identitas visual seragam di seluruh aplikasi.

### `transactions/widgets/history_tile.dart`
- `ListTile` → `AppCard` yang bisa ditekan.
- Susunan baru: `AppIconBadge` metode bayar (kiri) · no. struk
  (`titleMedium`) + "jam · metode · pelanggan" (`bodySmall`) · nominal
  `AppMoneyText` + `StatusBadge` dense (kanan).
- Transaksi void: nominal dicoret (`strikethrough`), ikon & nada `danger`.
  Transaksi hutang: nominal berwarna `accentText`.
- Pill status **hanya tampil untuk status non-lunas** supaya baris normal
  tidak jadi dinding hijau dan yang butuh perhatian langsung menonjol.
- Param baru `showDate` (default `false`): dipakai daftar yang tidak
  dikelompokkan per hari (layar hutang pelanggan) agar tanggal tetap ada.

### `transactions/screens/transactions_screen.dart`
- Daftar **dikelompokkan per hari** dengan judul "HARI INI · KEMARIN ·
  12 AGU 2026" (`AppTextStyles.eyebrow` + garis). Pengelompokan dihitung
  dari item yang sudah dimuat — tidak ada query/paginasi yang berubah.
- Kartu dipisah `AppSizes.spaceSm` (bukan `Divider`), padding bawah
  `bottomSafePadding` supaya tidak tertutup dock nav.
- Ikon filter di AppBar berganti outlined ↔ filled + warna `primary`
  ketika filter aktif (menggantikan titik oranye buatan sendiri).
- `AppBanner` "Filter aktif" berisi ringkasan filter dalam satu kalimat
  + aksi "Hapus filter".
- Empty state bercabang: tanpa filter → ajakan "Mulai Jualan"
  (`context.go(AppRoutes.pos)`); dengan filter → "Hapus Filter" +
  "Ubah Filter". Error → `AppErrorView` + coba lagi. Loading →
  `AppLoadingView`. Semua dibungkus scroll view ber-`AlwaysScrollableScrollPhysics`
  supaya pull-to-refresh tetap jalan walau kontennya pendek.
- Indikator "muat halaman berikutnya" memakai `AppLoadingView(compact: true)`.

### `transactions/widgets/history_filter_sheet.dart`
- Kepala sheet memakai `SectionHeader` (judul + subjudul + aksi "Reset").
- Section diberi eyebrow: RENTANG TANGGAL · METODE BAYAR · STATUS.
- **Pilihan cepat tanggal baru**: chip "Semua / Hari ini / 7 hari /
  30 hari" + baris `AppCard` (surfaceAlt) untuk memilih rentang sendiri,
  lengkap dengan tombol hapus rentang. Nilainya tetap disimpan ke field
  `startDate`/`endDate` yang sudah ada — API provider tidak berubah.
- Chip metode & status kini beringon (`avatar`) dan labelnya diambil dari
  `paymentMethodLabel` / `SaleStatusStyle`, jadi tidak ada teks kembar
  yang bisa melenceng dari layar lain.
- Tombol aksi setinggi `buttonHeightLarge` (60) di zona jempol:
  Reset (1 bagian) + Terapkan (2 bagian).
- Fungsi baru `historyFilterSummary(HistoryFilter)` — dipakai banner
  "Filter aktif" di layar Riwayat.

### `transactions/screens/sale_detail_screen.dart`
Disusun ulang menjadi struk premium (urutan baca dari atas):
1. **Kartu kepala** (`AppCard(elevated: true)`): eyebrow "NO. STRUK" +
   nomor, `StatusBadge`, lalu **TOTAL BELANJA** sebagai
   `AppMoneyText(size: lg)` berwarna `primary`, waktu transaksi, pill
   metode bayar, dan nama pelanggan (ikon + teks ellipsis).
2. **Banner keadaan** (`AppBanner`) sesuai status: dibatalkan (`danger`),
   belum lunas (`accent`, menyebut nama & nominal hutang), hutang sudah
   dilunasi (`success`).
3. **Rincian Item** (`SectionHeader` + pill jumlah item): satu baris per
   barang — pill qty, nama, harga satuan/unit, diskon item (kalau ada),
   nominal baris di kanan.
4. **Ringkasan uang**: deret `AppKeyValueRow` (Subtotal → Diskon → Total
   `emphasized` → Dibayar → Kembalian). Catatan transaksi tampil di kartu
   `surfaceAlt` bila ada.
5. **Struk Digital**: `ReceiptWidget` (milik fitur POS, tidak diubah)
   tetap berada di dalam `RepaintBoundary` — wajib ikut ter-render supaya
   "Bagikan Gambar" bisa meng-capture-nya — kini dibingkai kartu
   `surfaceAlt` dan dibungkus `FittedBox(scaleDown)` supaya lebar
   tetapnya (360dp) tidak overflow di HP sempit.
6. **Aksi merusak** (Batalkan Transaksi) ditempatkan paling bawah konten
   dengan penjelasan satu kalimat — terlihat, tapi tidak bersaing dengan
   aksi utama.
- **Bar aksi mengambang** (`AppDecorations.floating()`) di zona jempol:
  eyebrow "BAGIKAN STRUK KE PELANGGAN" + tombol Teks/Gambar, dan tombol
  `Tandai Lunas` setinggi `buttonHeightLarge` khusus transaksi hutang.
- Loading/error memakai `AppLoadingView`/`AppErrorView` (dengan
  `ref.invalidate` sebagai retry) — bukan lagi teks error mentah.

### `reports/widgets/summary_card.dart`
- Ditulis ulang mengikuti resep foundation §7.3: `AppCard` + baris
  `AppIconBadge` & eyebrow label + nilai `AppMoneyText`.
- API baru: `tone` (`AppTone`) menggantikan `color` bebas, plus `caption`,
  `hero` (kartu utama: padding `spaceMl`, `elevated`, nilai `AppMoneySize.lg`),
  dan `onTap` opsional (memunculkan chevron).

### `reports/widgets/top_product_tile.dart`
- `ListTile` → `AppCard`; `CircleAvatar` peringkat → `AppPill` (peringkat
  1 `filled`, 2–3 nada `primary`, sisanya netral).
- Param baru `share` (0..1) menggambar bar proporsi terhadap produk
  peringkat 1 — kesenjangan antar produk langsung kelihatan.

### `reports/screens/reports_screen.dart`
- Preset tanggal jadi baris chip yang bisa digeser (tinggi ≥48dp) dengan
  entri "Pilih Tanggal" beringon; rentang aktif ditulis di bawahnya
  dengan ikon kalender.
- **Satu angka utama**: kartu hero Omzet + caption "Dari N transaksi
  selesai" (atau ajakan kalau kosong), disusul dua kartu pendukung
  (Transaksi `info`, Laba Kotor `success`/netral kalau nol).
- Section **"Cara Pelanggan Bayar"**: satu `AppCard` berisi baris per
  metode — ikon bernada, jumlah transaksi + persentase, nominal, dan bar
  proporsi terhadap total omzet.
- Section **Produk Terlaris**: `SectionHeader` dengan `SegmentedButton`
  (Qty/Nilai) sebagai `trailing` dan subjudul yang ikut berubah.
- **Pintasan hutang berjalan** (`_DebtShortcut`): kartu beraksen yang
  menampilkan total hutang + jumlah pelanggan dan membuka `DebtListScreen`.
  Ini satu-satunya elemen beraksen di layar (aturan "maksimal satu
  aksen menonjol"), dan hanya muncul kalau memang ada hutang. Datanya
  dari `unpaidDebtsProvider` yang **sudah ada** (tidak ada query baru,
  penjumlahan hanya untuk tampilan).
- Semua state async pakai `AppLoadingView`/`EmptyState(compact)`/
  `AppErrorView`; pull-to-refresh ikut menyegarkan daftar hutang.
- Padding bawah `bottomSafePadding` (layar tab).

### `reports/screens/debt_list_screen.dart`
- Kartu total di atas: eyebrow "TOTAL HUTANG BERJALAN" + nominal
  `AppMoneySize.lg` warna `accentText` + "N pelanggan · M transaksi".
- Daftar pelanggan (`SectionHeader` "Urut dari hutang terbesar"):
  `AppCard` + `AppIconBadge` orang + nama + jumlah transaksi + nominal,
  dengan **bar proporsi terhadap penghutang terbesar** → prioritas
  penagihan langsung terlihat.
- Kosong → `EmptyState` nada `success` ("Semua hutang sudah lunas") +
  tombol Kembali; error → `AppErrorView` + coba lagi; loading →
  `AppLoadingView`.

### `reports/screens/customer_debt_transactions_screen.dart`
- Kartu "SISA HUTANG" per pelanggan (ikon `lg`, nominal `lg`, jumlah
  transaksi) di paling atas — angka tagihan diketahui sebelum membuka
  struk satu per satu.
- Daftar transaksi tetap **reuse penuh** `HistoryTile` (`showDate: true`)
  dan `SaleDetailScreen`; pola invalidate setelah kembali dari detail
  dipertahankan persis.
- Kosong → `EmptyState` sukses bernama pelanggan + tombol Kembali.

### `test/features/transactions/transactions_reports_ui_test.dart` (baru)
Smoke test render seluruh area ini di layar HP 392×820 dengan data nyata
(3 transaksi: tunai 2 item + diskon, non-tunai, hutang atas nama panjang):
Riwayat (kartu + judul "HARI INI") → sheet filter (terapkan & hapus) →
detail hutang & detail tunai (di-scroll sampai pratinjau struk + tombol
void) → Laporan (kartu omzet & pintasan hutang) → daftar hutang → detail
hutang pelanggan. Test ini yang menangkap dua overflow saat pengerjaan
(lihat §4).

### `test/features/pos/pos_checkout_flow_test.dart` (penyesuaian kecil)
Baris riwayat bukan lagi `ListTile`, jadi `find.byType(ListTile).first`
diganti `find.byType(HistoryTile).first`. Assertion alur & DB tidak
berubah sama sekali.

---

## 3. Pola foundation yang dipakai

| Kebutuhan | Komponen/token |
|---|---|
| Baris transaksi, produk terlaris, pelanggan berhutang | `AppCard` + `AppIconBadge` + `titleMedium`/`bodySmall` + `AppMoneyText` + `AppPill` |
| Kartu angka ringkasan | `AppCard(elevated)` + `AppTextStyles.eyebrow` + `AppMoneyText(size: lg)` |
| Ringkasan struk | deret `AppKeyValueRow`, baris total `emphasized: true` |
| Status transaksi & metode bayar | `AppPill` + `AppTone` (§2.5) |
| Pesan kontekstual menetap | `AppBanner` (filter aktif, void, hutang, pelunasan) |
| Filter/preset | `ChoiceChip` bertema, tinggi ≥48dp |
| Aksi utama | bar `AppDecorations.floating()` + tombol `buttonHeightLarge` |
| Kosong/loading/error | `EmptyState` · `AppLoadingView` · `AppErrorView` |
| Judul section | `SectionHeader` (eyebrow/subtitle/trailing) |
| Jarak & radius | `AppSizes.space*` / `radius*` / `bottomSafePadding` |

---

## 4. Catatan & temuan untuk pemilik fondasi

1. **`AppPill` tidak menangani teks panjang.** Labelnya `Text` tanpa
   `overflow`/`Flexible`, jadi begitu dipakai untuk data dinamis (nama
   pelanggan) di dalam `Row`/`Wrap` yang sempit, hasilnya
   `RenderFlex overflowed`. Di layar ini sudah dihindari (nama pelanggan
   dirender sebagai ikon + teks ellipsis, pill hanya untuk label pendek
   yang kita kendalikan). Saran untuk fondasi: bungkus `Text` di
   `app_pill.dart` dengan `Flexible` + `overflow: TextOverflow.ellipsis`.
2. **`ReceiptWidget` lebarnya tetap 360dp.** Karena harus tetap
   ter-render demi capture gambar, di layar ini dibungkus
   `FittedBox(BoxFit.scaleDown)`. Kalau nanti fitur POS mengubah struk
   jadi responsif, pembungkus itu bisa dilepas.
3. **Tidak ada perubahan pada `lib/core/**`** — semua kebutuhan sudah
   tercukupi oleh komponen bersama yang ada.

---

## 5. Hasil verifikasi

- `flutter analyze` → **No issues found!** (0 error, 0 warning) untuk
  seluruh proyek, dan `flutter analyze lib/features/transactions
  lib/features/reports test/features/transactions` juga bersih.
- `flutter test` → **208 test lolos, 0 gagal** (207 sebelumnya + 1 smoke
  test baru area ini).
- Smoke test render: Riwayat, sheet filter, Detail Transaksi (tunai &
  hutang, sampai bagian bawah), Laporan, Daftar Hutang, dan Hutang per
  Pelanggan **tanpa overflow/exception** di layar HP 392×820 dengan nama
  produk & nama pelanggan panjang.
- Dua overflow ditemukan & diperbaiki selama pengerjaan: tombol bagikan
  yang labelnya kepanjangan (jadi "Teks"/"Gambar" dengan eyebrow
  penjelas) dan pill nama pelanggan di kartu kepala detail (jadi ikon +
  teks ellipsis).
