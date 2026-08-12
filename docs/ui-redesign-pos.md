# Redesign UI — Area POS / Kasir

**Design language:** "Kertas & Daun" (`docs/ui-redesign-foundation.md`)
Tanggal: 12 Agustus 2026 · Cakupan: `lib/features/pos/**` saja

> Tidak ada logika bisnis, provider, repository, atau skema data yang diubah.
> Seluruh pekerjaan di sini murni visual & struktur widget.

---

## 1. Masalah yang diperbaiki

Layar Kasir versi lama masih Material default: `Card` polos, ikon kardus
seragam di setiap tile produk, badge titik oranye kecil, bar keranjang datar
dengan `Material(elevation: 8)`, sheet pembayaran berupa tumpukan `TextField`
dan `OutlinedButton` seragam, serta layar sukses yang hanya menampilkan ikon
centang bawaan Material. Semua informasi punya bobot visual yang sama —
kasir harus *membaca* layarnya, bukan sekadar *melihat*.

Arah perbaikan mengikuti lima prinsip fondasi, dengan penekanan pada dua yang
paling relevan untuk warung: **angka lebih penting dari labelnya** dan
**cepat > cantik**.

---

## 2. Perubahan per berkas

### 2.1 `screens/pos_screen.dart`

- Import tunggal lewat barrel `core/widgets/app_widgets.dart`.
- **Badge "transaksi ditahan" jadi pil aksen berlabel angka** (`AppCard`
  radius pill, `accent50`/`accent100`/`accentText`, tinggi 44dp) menggantikan
  ikon + titik oranye 16dp yang mudah terlewat. Saat tidak ada transaksi
  ditahan, tombol kembali jadi `IconButton` biasa — aksen hanya muncul kalau
  memang ada pekerjaan yang menunggu (fondasi §2.2: maksimal satu elemen
  aksen menonjol per layar).
- Panel keranjang tablet duduk di atas `AppColors.surface` (via `ColoredBox`)
  dengan `VerticalDivider` setebal `AppSizes.hairline` — panel kanan terbaca
  sebagai permukaan tersendiri, bukan lanjutan kanvas.
- Lebar panel keranjang tablet dinaikkan 380 (dari 400 fixed jadi konstanta
  bernama `_cartPanelWidth`) supaya grid produk kiri tetap lega.

### 2.2 `widgets/product_grid.dart`

- **Tile produk dirancang ulang untuk dipindai:**
  monogram huruf awal (kotak `primary50` radius `radiusSm`) sebagai jangkar
  visual → nama produk (`titleMedium`, 2 baris) → harga `AppMoneyText`
  berwarna `primary` → status stok. Ikon kardus identik di semua tile dibuang
  karena tidak membedakan apa pun.
- **Produk yang sudah ada di keranjang** memakai `AppCard(selected: true)`
  (latar & border brand) + `AppPill(filled, dense)` berisi "3x" di pojok
  kanan atas. Kasir tahu apa yang sudah ditap tanpa membuka keranjang.
- **Status stok memakai `AppTone` sesuai peta §2.5:** habis → `danger`
  ("Stok habis"), menipis → `warning` ("Sisa 3 pcs"), aman → teks
  `bodySmall` netral. Warna hanya muncul saat butuh perhatian.
- Toolbar atas: field pencarian + dua `_ToolButton` persegi 56dp (scan
  barcode, item bebas) bernada brand lembut — tinggi sama dengan field
  sehingga barisnya rata.
- Chip kategori pindah ke `ListView.separated` setinggi 48dp (target sentuh
  penuh), jarak antar chip pakai `spaceSm`.
- **Semua state async pakai komponen bersama:** `AppLoadingView`,
  `AppErrorView` (dengan `onRetry: ref.invalidate(posProductListProvider)`),
  dan `EmptyState`. Dua empty state berbeda, keduanya punya tombol aksi:
  hasil filter kosong → "Tampilkan Semua" (mereset query + kategori),
  belum ada produk sama sekali → "Tambah Item Bebas" (jalan keluar yang
  benar-benar bisa dipakai dari layar Kasir).

### 2.3 `widgets/cart_summary_bar.dart`

- Dari `Material(elevation: 8)` datar → **kartu mengambang**
  (`AppDecorations.floating()` + margin) sesuai §7.3.
- Isi: `AppIconBadge` keranjang (filled saat ada isi) → jumlah item
  (`bodySmall`) → **total `AppMoneySize.lg` (28pt)** → CTA "Bayar" setinggi
  `buttonHeight` dengan `AppShadows.primaryGlow`.
- Total dibungkus `FittedBox(scaleDown)` agar nominal besar mengecil
  proporsional, tidak pernah membungkus ke baris kedua.
- Badge angka yang menempel di ikon dihapus — jumlah item sudah tertulis
  sebagai teks, dua penanda untuk informasi yang sama itu mubazir.

### 2.4 `widgets/cart_panel.dart`

- Judul memakai `SectionHeader` (judul + subtitle jumlah item + aksi teks
  "Kosongkan").
- Daftar item jadi **kartu terpisah** (bukan baris ber-`Divider`) dengan
  jarak `spaceSm` — tiap item punya ruang sentuh sendiri.
- Keranjang kosong memakai `EmptyState` dengan kalimat pengarah.
- **Bar checkout bawah** (`_CheckoutBar`): panel `AppDecorations.floating`
  radius `radius2xl` berisi sub-panel `surfaceAlt` dengan tiga
  `AppKeyValueRow` (Subtotal, Diskon transaksi, Total `emphasized`), lalu
  baris aksi.
- Baris diskon transaksi jadi baris yang bisa ditekan dengan ikon
  `local_offer_outlined`; nilainya "-Rp2.000" berwarna `dangerText`, atau
  "Atur" berwarna `primary` saat belum ada diskon (aksi terbaca tanpa
  tebak-tebakan).
- Aksi: "Tahan" (outlined, flex 2) + "Bayar" (filled + `primaryGlow`,
  flex 3), keduanya setinggi `buttonHeightLarge` (60dp).
- Dialog "Kosongkan Keranjang?" memakai `FilledButton` merah — satu-satunya
  override warna tombol yang diizinkan fondasi §7.3.
- Dialog "Tahan Transaksi" diberi kalimat penjelas + field berlabel ikon.

### 2.5 `widgets/cart_item_tile.dart`

- Satu item = satu `AppCard`. Baris atas: nama + harga satuan di kiri,
  `AppMoneyText` total baris di kanan (plus harga coret
  `strikethrough` saat ada diskon).
- Diskon item tampil sebagai `AppPill(tone: accent)` — konsisten dengan
  penanda hutang/ditahan di seluruh aplikasi.
- **Stepper qty jadi satu sub-panel `surfaceAlt`**: `−` 44dp · angka (tap =
  input manual, `AppTextStyles.numeric`) · `+` 44dp. Sebelumnya
  `IconButton.outlined` yang berdiri sendiri dan mudah tertukar dengan
  tombol hapus.
- Tombol diskon & hapus tetap icon-only + tooltip Indonesia (alasan
  anti-overflow di HP <360dp dari Milestone 6 dipertahankan), ikon diskon
  berubah warna jadi `accentText` saat item sedang berdiskon.
- Dialog "Ubah Qty" menampilkan nama item + input berukuran `moneyLarge`.

### 2.6 `widgets/payment_sheet.dart`

- Drag handle manual dihapus — tema `bottomSheetTheme` sudah menyediakannya
  (sebelumnya tampil dobel).
- **Panel hero total belanja** di atas: `AppCard` `primary50` dengan eyebrow
  "TOTAL BELANJA" + `AppMoneySize.lg` + jumlah item.
- **Metode bayar jadi tiga kartu besar** (`AppCard(selected:)`, ikon
  `iconLg` + label) menggantikan pasangan Filled/OutlinedButton — target
  sentuh jauh lebih besar dan keadaan terpilih terbaca jelas.
- **Form tunai:** input "Uang diterima" bergaya `AppTextStyles.moneyLarge`
  (28pt) supaya angka terbaca sambil menghitung uang; pecahan cepat disusun
  **dua kolom** (bukan empat, yang membuat tiap tombol sempit); "Uang Pas"
  dapat baris sendiri bernada aksen + ikon karena itu satu-satunya pintasan
  yang menyelesaikan input sekali tap.
- **Kembalian** tampil di panel bernada: `success` saat cukup, `danger` saat
  kurang (labelnya ikut berubah jadi "Kurang bayar"), nominal
  `AppMoneySize.lg`.
- Catatan non-tunai & hutang dipindah dari teks abu-abu kecil ke `AppBanner`
  (`info` dan `accent`). Error simpan memakai `AppBanner(tone: danger)`,
  bukan teks merah telanjang.
- CTA "Selesaikan Pembayaran" setinggi `buttonHeightLarge` + `primaryGlow`.

### 2.7 `widgets/discount_dialog.dart`

- Struktur: panel `surfaceAlt` "Harga sebelum diskon" → `SegmentedButton`
  (Nominal / Persen) → input `moneyLarge` → **panel pratinjau `primary50`**
  berisi dua `AppKeyValueRow` ("Potongan" merah, "Jadi bayar" hijau).
- Pratinjau "jadi bayar" adalah tambahan penting: kasir melihat langsung
  angka yang akan dibayar pembeli, bukan cuma potongannya.
- Logika konversi Rp↔% dan clamp `0..baseAmount` tidak disentuh.

### 2.8 `widgets/free_item_dialog.dart`

- Kalimat pembuka menjelaskan apa itu item bebas ("dicatat sekali pakai,
  tanpa memengaruhi stok").
- Field diberi ikon prefix, dan ditambahkan **panel "Total baris"**
  (`AppKeyValueRow(emphasized: true)`) yang dihitung ulang saat mengetik
  (`Form.onChanged`) — verifikasi sebelum menekan Tambah.
- Validator & bentuk `FreeItemInput` tidak berubah.

### 2.9 `screens/held_carts_screen.dart`

- Empty state manual → `EmptyState(tone: accent)` dengan kalimat pengarah.
- Loading/error → `AppLoadingView` / `AppErrorView` + tombol coba lagi
  (`ref.invalidate(heldCartListProvider)`); sebelumnya error dilempar sebagai
  satu baris teks `Center`.
- Item `Card` + `ListTile` tiga baris → `AppCard` dengan `AppIconBadge`
  aksen ukuran `lg`, label (atau "Tanpa label" berwarna sekunder),
  `AppPill` jumlah item, waktu `bodySmall`, dan `AppMoneyText` total.
- Header daftar memakai `SectionHeader` (eyebrow "DIPARKIR" + "N transaksi
  menunggu" + petunjuk "Tap kartu untuk melanjutkannya ke keranjang").
- Dialog hapus memakai `FilledButton` merah.

### 2.10 `screens/checkout_success_screen.dart` — momen puncak

- Kartu hero `AppCard(elevated: true)`: centang `AppIconBadge(filled,
  success, xl)` yang muncul dengan animasi skala+fade sekali jalan
  (`AppDurations.slow`, `Curves.easeOutCubic`) → judul → `AppPill` nomor
  struk.
- **Angka yang ditonjolkan berbeda per metode** (`_HeroAmount`):
  tunai → **KEMBALIAN** (`AppMoneySize.hero` 40pt, `successText`), hutang →
  **TOTAL HUTANG** (`accentText`) + pil "Belum lunas", non-tunai →
  **TOTAL DIBAYAR** + pil "Non-tunai" (`info`). Yang paling dibutuhkan kasir
  pada detik itu yang paling besar.
- Rincian pendukung (Total belanja, Uang diterima, Atas nama) turun ke
  sub-panel `surfaceAlt` sebagai `AppKeyValueRow`.
- Struk dibungkus `AppCard` (padding 0) dengan `SectionHeader` "Struk
  digital" + ajakan berbagi. `RepaintBoundary` tetap membungkus persis
  `ReceiptWidget`, jadi hasil capture gambar tidak berubah.
- Aksi bawah: dua tombol bagikan (outlined) lalu CTA "Transaksi Baru"
  setinggi `buttonHeightLarge` + `primaryGlow`.
- `automaticallyImplyLeading: false` — layar ini punya jalan keluar
  eksplisit, tidak perlu panah kembali yang membingungkan.

### 2.11 `widgets/receipt_widget.dart`

Struk **tetap monokrom & monospace** — file ini ikut dicetak/di-share sebagai
gambar dan harus terbaca di printer termal 58mm. Yang dirapikan hanya ritme
tipografinya:

- Hierarki empat gaya: judul toko 17pt kapital (letter-spacing 1), isi 12pt,
  tebal untuk nama item, **15pt tebal khusus baris TOTAL**.
- Lebar render 340 (dari 360) supaya proporsinya lebih mirip kertas 58mm dan
  muat di dalam kartu layar sukses pada HP 360dp.
- Garis putus-putus mengikuti lebar (`LayoutBuilder`, satu baris, tidak
  pernah membungkus) menggantikan string 32 tanda hubung yang tetap.
- Jarak antar blok memakai token `AppSizes`; hutang ditulis dua baris
  ("HUTANG atas nama:" + nama tebal) agar mudah dibaca saat ditagih.

**Pengecualian tercatat:** `Colors.black` / `Colors.white` di berkas ini
sengaja dipertahankan (bukan token `AppColors`) karena keluarannya adalah
media cetak monokrom, bukan permukaan aplikasi. Ini satu-satunya tempat di
`lib/features/pos/` yang memakai palet di luar fondasi.

---

## 3. Pola fondasi yang dipakai

| Kebutuhan | Komponen/token |
|---|---|
| Permukaan (tile produk, item keranjang, kartu bayar, sub-panel) | `AppCard` (termasuk `selected`, `color: surfaceAlt`, `elevated`) |
| Judul section | `SectionHeader` (+ `eyebrow`, `subtitle`, `actionLabel`) |
| Kosong / loading / error | `EmptyState`, `AppLoadingView`, `AppErrorView` |
| Status (stok, diskon, metode, ditahan) | `AppPill` + peta `AppTone` §2.5 |
| Ikon leading & perayaan | `AppIconBadge` (`md`/`lg`/`xl`, `filled`) |
| Ringkasan nominal | `AppKeyValueRow` (baris terakhir `emphasized`) |
| Semua nominal rupiah | `AppMoneyText` (`sm`/`md`/`lg`/`hero`, `strikethrough`) |
| Pesan kontekstual menetap | `AppBanner` (`info`, `accent`, `danger`) |
| Bar aksi mengambang | `Container(decoration: AppDecorations.floating())` |
| Kedalaman | `AppShadows.level*` & `primaryGlow` (hanya di bawah CTA Bayar / Selesaikan / Transaksi Baru) |
| Animasi | `AppDurations.slow` + `Curves.easeOutCubic` (centang sukses) |

**Disiplin yang dijaga:** tanpa hex mentah, tanpa `Colors.*` (kecuali struk),
tanpa angka spacing/radius mentah, tanpa `elevation:` Material, tanpa
gradient/blur, dan tanpa override tema komponen selain tombol merah untuk
aksi merusak (diizinkan §7.3).

---

## 4. Keputusan desain & alasannya

1. **Monogram huruf, bukan ikon produk.** Semua produk memakai ikon kardus
   yang sama sebelumnya — tidak menambah informasi apa pun. Monogram huruf
   awal memberi bentuk yang berbeda per produk sehingga mata punya pegangan
   saat memindai grid, tanpa butuh foto (aplikasi ini offline dan datanya
   sering tanpa gambar). Warnanya tetap satu (`primary50`) supaya grid tidak
   berubah jadi pelangi; pembeda status tetap dipegang pil stok.
2. **Keadaan "sudah di keranjang" ditampilkan di grid.** Menggunakan
   `AppCard(selected:)` + pil jumlah, kasir bisa menambah beberapa produk
   berturut-turut tanpa membuka keranjang untuk memastikan.
3. **Kembalian jadi angka terbesar di layar sukses.** Total sudah dikonfirmasi
   di sheet pembayaran; yang belum selesai pada detik itu adalah menyerahkan
   uang kembalian. Untuk hutang & non-tunai tidak ada kembalian, jadi total
   yang naik ke posisi hero.
4. **Metode bayar sebagai kartu, bukan tombol.** Tiga tombol berdampingan di
   HP sempit membuat label terpotong dan target sentuh tipis. Kartu vertikal
   (ikon di atas label) muat, terbaca, dan tingginya >72dp.
5. **Pecahan cepat dua kolom.** Empat tombol sebaris menyisakan ~80dp per
   tombol — terlalu sempit untuk ditekan sambil memegang uang. Dua kolom
   menggandakan lebarnya; "Uang Pas" diberi baris & nada aksen sendiri karena
   itu pintasan yang paling sering dipakai.
6. **Aksen dipakai sangat hemat.** Hanya tiga tempat: pil "N ditahan" di
   AppBar, tombol "Uang Pas", dan penanda diskon/hutang. Sisanya hijau brand
   atau netral.
7. **Bar keranjang tidak lagi menampilkan badge angka di ikon.** Jumlah item
   sudah tertulis; menghapus badge menyisakan satu titik fokus: totalnya.
8. **Tidak ada `bottomSafePadding` tambahan di area POS.** Dock navigasi
   dipasang sebagai `bottomNavigationBar` di `MainShell` (ruangnya sudah
   dipesan, bukan mengambang di atas body), jadi bar keranjang & grid tidak
   pernah tertutup. Padding ekstra justru akan menyisakan celah kosong.

---

## 5. Hasil verifikasi

- `flutter analyze` → **No issues found!** (0 error, 0 warning).
- `flutter test test/features/pos/pos_checkout_flow_test.dart` → **3/3 lolos**
  (happy path tunai, hutang, void).
- `flutter test test/app_test.dart test/core test/data test/domain test/features`
  → **207 test lolos, 0 gagal** (jumlah sama dengan baseline fondasi).
- **Tidak ada berkas test yang perlu diubah** untuk redesign ini: seluruh
  teks yang dijadikan pegangan test (`1 item`, `Bayar`, `Pembayaran`,
  `Rp10.000`, `Uang Pas`, `Selesaikan Pembayaran`, `Nama pelanggan *`,
  `Transaksi Berhasil`, `Transaksi Baru`, `Keranjang kosong`) sengaja
  dipertahankan apa adanya.

### Catatan overflow yang ditemukan & diperbaiki saat verifikasi

Font uji `flutter_test` lebih lebar daripada Plus Jakarta Sans, sehingga
memunculkan `RenderFlex overflowed` pada tata letak yang di perangkat asli
masih muat. Tiga hal disesuaikan supaya aman di HP paling sempit sekalipun:

1. Pil nomor struk dipendekkan (`Struk 20260812-0001`, bukan
   `No. Struk: ...`) dan nama pelanggan hutang dipindah ke `AppKeyValueRow`
   "Atas nama" — `AppPill` tidak bisa membungkus label panjang.
2. Tombol "Tahan" dilepas ikonnya dan proporsinya diubah jadi 2:3 terhadap
   "Bayar".
3. Total di bar keranjang dibungkus `FittedBox(scaleDown)`.

### Di luar kendali area ini

`test/tmp_ui_smoke_test.dart` (berkas sementara milik agent area
Riwayat/Laporan yang bekerja paralel) gagal karena overflow `AppPill` di
`lib/features/transactions/screens/sale_detail_screen.dart` — di luar scope
POS dan tidak berhubungan dengan perubahan di dokumen ini.
