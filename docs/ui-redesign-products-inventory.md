# Redesign UI — Area Produk & Inventori

Design language: **"Kertas & Daun"** (`docs/ui-redesign-foundation.md`)
Tanggal: 12 Agustus 2026 · Cakupan: `lib/features/products/**` &
`lib/features/inventory/**` · Status: **selesai**

> Semua perubahan **murni visual & struktur widget**. Tidak ada provider,
> repository, usecase, validator, atau skema data yang disentuh. Semua
> `TextEditingController`, `GlobalKey<FormState>`, validator
> (`ProductFormValidator`), pemanggilan repo, dan alur `Navigator.pop`
> dipertahankan persis seperti sebelumnya.

---

## 1. Ringkasan masalah lama

Area Produk & Inventori sebelumnya adalah Material 3 default: `ListTile` +
`Divider`, `CircleAvatar` warna semi-transparan, form berupa 9 field
berderet tanpa pengelompokan, tombol simpan ikut ter-scroll di ujung
daftar, dan tiga varian "layar kosong"/"error" buatan sendiri yang
berbeda-beda di tiap file. Angka yang paling dicari pemilik warung —
**harga** dan **sisa stok** — tampil dengan bobot yang sama seperti label
di sekelilingnya.

Arah perbaikan: kartu, bukan baris berpembatas; satu bahasa status
(`AppTone`) untuk stok; angka lebih tebal daripada label; aksi utama pindah
ke bar mengambang di zona jempol; semua state (data/kosong/loading/error)
memakai komponen bersama.

---

## 2. Perubahan per berkas

### 2.1 `lib/features/products/widgets/product_list_tile.dart`
- `InkWell` + `Padding` + `CircleAvatar` → **`AppCard(onTap:)`** dengan
  `AppIconBadge(size: lg)` sebagai leading (ikon `visibility_off_outlined`
  + nada `neutral` untuk produk nonaktif).
- Nama produk `titleMedium` satu baris (ellipsis) memakai lebar penuh kolom
  tengah; harga jual di kanan sebagai **`AppMoneyText`** warna
  `AppColors.primary` (abu untuk produk nonaktif).
- Baris meta jadi **`Wrap`** berisi: sisa stok (`AppTextStyles.numeric`,
  warna mengikuti nada stok) → pill status → pill kategori → pill
  "Nonaktif". Karena `Wrap`, di HP sempit chip turun ke baris berikutnya,
  bukan meluber.
- Status stok memakai `AppPill` + `AppTone` sesuai peta §2.5 fondasi:
  `stock <= 0` → **danger "Stok habis"**, menipis → **warning "Stok
  menipis"**, aman → **tanpa warna** (netral) supaya warna hanya muncul
  saat butuh tindakan.
- Widget privat `_Badge` (Container + `withValues(alpha:)`) dihapus —
  digantikan `AppPill`.
- Dua penjaga tata letak: nama kategori dipotong pada 16 karakter (pill
  tidak bisa meng-ellipsis teksnya sendiri) dan pill kategori disembunyikan
  saat ada pill status (yang mendesak dibaca duluan).

### 2.2 `lib/features/products/screens/products_screen.dart`
- Kolom pencarian pakai padding `screenPadding`, ikon `search_rounded`, dan
  tombol hapus `close_rounded` (teks hint dipersingkat "Cari nama atau
  barcode…").
- Chip kategori jadi `ListView.separated` horizontal setinggi
  `minTouchTarget` (48) dengan `ChoiceChip` bertema + tanda centang pada
  chip terpilih; `Semua` selalu pertama.
- **Baru: `AppBanner` nada warning** saat ada produk menipis — pesan
  berhitung ("5 produk stoknya menipis…") + aksi "Lihat daftarnya". Ikon
  peringatan ber-`Badge.count` di AppBar dipertahankan sebagai jalan pintas
  permanen (banner hanya muncul kalau memang ada).
- **Baru: `SectionHeader`** di atas daftar dengan judul kontekstual
  ("Hasil pencarian" / nama kategori / "Semua produk") dan `AppPill`
  jumlah hasil.
- Daftar: `Divider` dihilangkan; `ListView.separated` berjarak `spaceSm`
  antar `AppCard`, padding bawah `bottomSafePadding` (96) agar tidak
  tertutup dock nav.
- State: kosong → `EmptyState` (dua varian: belum ada produk → "Tambah
  Produk"; filter tidak menemukan → "Tampilkan Semua" yang mereset query &
  kategori lewat notifier yang sudah ada), loading → `AppLoadingView`,
  error → `AppErrorView` + `ref.invalidate(productListProvider)`.
  `_EmptyState` buatan sendiri dihapus.
- Ikon "Kelola kategori" diganti `sell_outlined` (label harga) supaya beda
  jelas dari ikon kategori Material yang generik.

### 2.3 `lib/features/products/screens/product_form_screen.dart`
- Form dipecah jadi **empat kartu section** (`_FormSection` = `AppCard` +
  `AppIconBadge` + `SectionHeader`):
  1. **Identitas Produk** — nama, barcode + tombol scan, kategori.
  2. **Harga** — harga jual, harga modal, dan **pratinjau "Untung per
     <satuan>"** (`AppKeyValueRow` di sub-panel `surfaceAlt`) yang muncul
     otomatis saat kedua harga terisi; hijau kalau untung, merah kalau
     rugi. Murni tampilan, tidak disimpan ke mana pun.
  3. **Stok & Satuan** — stok, satuan + **chip satuan cepat** (pcs,
     bungkus, botol, sachet, kg, liter — memilih lebih cepat daripada
     mengetik), batas stok menipis, dan (mode ubah) tombol "Sesuaikan" &
     "Riwayat".
  4. **Status & Lainnya** — switch produk aktif (mode ubah) + catatan
     "foto belum didukung" sebagai `AppBanner` netral (dulu `Container` +
     `BoxDecoration` manual).
- Tombol scan barcode jadi kotak `primary50` setinggi field di sebelahnya
  (dulu `IconButton.filledTonal` yang melayang tidak rata).
- Dropdown kategori diberi `isExpanded: true` — tanpa ini entri "+ Tambah
  kategori baru" meluber di HP 360dp.
- **Tombol simpan pindah ke bar mengambang bawah** (`AppDecorations
  .floating()` + `FilledButton.icon` setinggi `buttonHeightLarge` 60),
  sesuai §7.1 poin 7. Label kontekstual ("Simpan Produk" / "Simpan
  Perubahan") dan state menyimpan ("Menyimpan…" + spinner).
- Loading awal (mode ubah) → `AppLoadingView`; error kategori →
  `AppBanner` nada danger.

### 2.4 `lib/features/products/widgets/category_manage_dialog.dart`
- Daftar kategori: `ListTile` → kartu kecil `AppCard(color: surfaceAlt,
  radius: radiusMd)` berisi nama + dua tombol ikon (ubah/hapus, hapus
  berwarna `dangerText`).
- Kosong → `EmptyState(compact: true)` dengan kalimat pengarah; loading →
  `AppLoadingView(compact: true)`; error → `AppErrorView(compact: true)`
  + retry.
- Panel tambah cepat menempel di bawah: field + tombol `FilledButton`
  kotak setinggi field (dulu `IconButton` kecil), tetap bisa menambah
  berturut-turut tanpa menutup dialog.
- Dialog konfirmasi hapus: `AppIconBadge` nada danger sebagai ikon dialog,
  kalimat konsekuensi yang jelas, tombol hapus `FilledButton` warna
  `AppColors.danger` — satu-satunya override warna tombol yang diizinkan
  fondasi §7.3.

### 2.5 `lib/features/products/widgets/quick_add_category_dialog.dart`
- Ikon dialog `AppIconBadge`, judul dipersingkat "Kategori Baru", hint
  contoh ("mis. Minuman"), `textCapitalization: words`, dan satu baris
  keterangan bahwa kategori langsung terpakai untuk produk yang sedang
  diisi.

### 2.6 `lib/features/products/widgets/barcode_scanner_page.dart`
- `Colors.black` & `Colors.white` (dilarang fondasi §7.2) diganti
  `AppColors.surfaceDark` / `AppColors.onDark` / `AppColors.primary200`.
- `AppBar` bertema kertas dilepas — pita krem memotong bidang pandang
  kamera. Digantikan kontrol mengambang: tombol tutup (kiri) & lampu
  (kanan) berbentuk lingkaran di atas permukaan gelap, ikon lampu berubah
  `flashlight_off/on_rounded` dan berlatar `primary` saat menyala.
- **Bingkai bidik** di tengah (kotak radius `radiusXl` + empat sudut "L"
  `primary200`) dan kartu petunjuk di bawah: "Arahkan ke barcode produk" +
  "Kode akan terisi otomatis begitu terbaca."

### 2.7 `lib/features/inventory/screens/low_stock_screen.dart`
- Dibaca sebagai **daftar belanja**: `AppBanner` warning di pucuk daftar
  ("N barang perlu diisi ulang" + arahan untuk mengetuk barangnya).
- Tiap produk jadi `AppCard` berisi `AppIconBadge` (warning / danger kalau
  habis), nama, "Sisa X <unit> · batas Y <unit>", harga jual kecil di
  kanan, dan **bar sisa stok** (`LinearProgressIndicator` bernada
  `AppTone`, `value = stok/batas`) supaya "seberapa gawat" terbaca tanpa
  membandingkan dua angka di kepala.
- Kosong → `EmptyState(tone: success, icon: verified_outlined, "Semua stok
  aman")`; loading/error → `AppLoadingView`/`AppErrorView` + retry.
  `_LowStockTile` & `_EmptyState` lama dihapus.

### 2.8 `lib/features/inventory/screens/stock_adjustment_screen.dart`
Susunan mengikuti cara orang menghitung barang:
**stok sekarang → mau diapakan → berapa → jadi berapa → kenapa**.
- Kartu ringkasan `AppCard(elevated: true)`: nama produk, eyebrow "STOK
  SEKARANG", dan angka stok besar (`moneyLarge` 26, tabular).
- `SegmentedButton` jenis penyesuaian dengan label pendek (Masuk / Keluar /
  Opname) dan ikon arah `south_rounded` / `north_rounded` /
  `fact_check_outlined`; `showSelectedIcon: false` supaya tidak dobel ikon.
- Field jumlah dapat `prefixIcon` mengikuti jenis + `suffixText` satuan.
- **Kartu pratinjau "SEBELUM → STOK JADI"** (`_PreviewCard`,
  `AppDecorations.tonal` + `AnimatedContainer` 200ms) — inti layar ini.
  Nadanya mengikuti arah: masuk `success`, keluar `danger`, opname `info`.
  Nilai sesudah paling besar & tebal.
- Kartu "Alasan" terpisah dengan hint contoh yang berubah per jenis
  ("Belanja stok dari agen" / "Barang rusak / kedaluwarsa" / "Hasil hitung
  ulang rak depan").
- Tombol simpan pindah ke bar mengambang bawah setinggi
  `buttonHeightLarge`.

### 2.9 `lib/features/inventory/screens/stock_movement_history_screen.dart`
- Judul AppBar dipersingkat jadi "Riwayat Stok" (dulu "Riwayat Stok —
  <nama produk>" yang terpotong di HP kecil); konteks produk pindah ke
  **kartu ringkasan** di atas daftar (nama + eyebrow "STOK KINI" + angka).
- Daftar: `Divider` → jarak `spaceSm` antar `AppCard`, padding bawah
  `bottomSafePadding`; indikator "muat lagi" → `AppLoadingView(compact:
  true)`.
- Kosong → `EmptyState` + aksi "Sesuaikan Stok"; loading/error →
  `AppLoadingView`/`AppErrorView` + retry. `_EmptyState` lama dihapus.

### 2.10 `lib/features/inventory/widgets/stock_movement_tile.dart`
- `Padding` + `CircleAvatar` (alpha 0.12) → `AppCard` + `AppIconBadge`
  bernada.
- **Arah pergerakan dibaca dari tiga sinyal sekaligus**: ikon panah
  (`south_rounded` masuk / `north_rounded` keluar), warna nada (masuk
  `success`, keluar `danger`, opname `info`), dan tanda ± pada angka.
- Baris utama: jenis + waktu di kiri, `±qty <unit>` (numeric tabular,
  berwarna) + "sisa X <unit>" di kanan.
- Nomor invoice jadi `AppPill` dense berikon struk; catatan pindah ke
  sub-panel `surfaceAlt` berikon nota — dulu empat baris teks abu yang
  sama beratnya.

---

## 3. Keputusan desain

1. **Stok aman tidak diberi warna.** Peta §2.5 menyediakan `success` untuk
   "stok aman", tapi kalau setiap baris produk berpil hijau, warna
   kehilangan arti. Warna hanya dipakai saat butuh tindakan (menipis =
   warning, habis = danger); stok aman tampil netral. Ini mengikuti
   prinsip §1 poin 3 (satu titik fokus) dan §2.2 (aksen hemat).
2. **Kartu, bukan baris berpembatas.** `Divider` dilepas di semua daftar
   area ini supaya bahasa permukaannya sama dengan layar lain (kartu putih
   hangat + garis tipis, `AppShadows.level0`).
3. **Aksi utama turun ke bar mengambang.** Form produk & penyesuaian stok
   dulu menaruh tombol simpan di ujung `ListView` — kasir harus scroll
   dulu untuk menyimpan. Sekarang selalu ada di zona jempol.
4. **Angka > label di mana-mana.** Sisa stok, ±qty, "stok jadi", dan harga
   selalu memakai gaya tabular (`AppTextStyles.numeric`/`money`) dan lebih
   tebal daripada keterangannya.
5. **Pratinjau sebelum→sesudah** dipilih sebagai "momen puncak" kecil layar
   stok: pemilik warung paling takut salah hitung, jadi hasil akhirnya
   ditunjukkan sebelum ditekan simpan (dulu hanya satu baris teks hijau).
6. **Layar scanner boleh gelap.** Satu-satunya konteks gelap di area ini;
   tetap memakai token (`surfaceDark`, `onDark`, `primary200`), bukan
   `Colors.black`.
7. **Pilih daripada mengetik** (chip satuan) dan **hitung otomatis**
   (untung per satuan) ditambahkan karena keduanya menghemat waktu tanpa
   menambah logika bisnis — keduanya hanya turunan tampilan dari isi field.
8. **Tanpa Riverpod/logika baru.** Aksi "Tampilkan Semua" di layar kosong
   memakai `ProductFilterNotifier.setQuery/setCategory` yang sudah ada;
   tombol retry memakai `ref.invalidate` pada provider yang sudah ada.

## 4. Pola fondasi yang dipakai

| Pola | Dipakai di |
|---|---|
| `AppCard` (biasa / `elevated` / sub-panel `surfaceAlt`) | semua daftar, kartu form, ringkasan stok, catatan pergerakan |
| `AppIconBadge` (`sm`/`md`/`lg`) | leading tile produk, stok menipis, pergerakan stok, ikon section form, ikon dialog |
| `AppPill` (`dense`, `AppTone`) | status stok, kategori, "Nonaktif", jumlah produk, nomor invoice |
| `AppMoneyText` | harga jual di tile produk & kartu stok menipis |
| `AppKeyValueRow` | pratinjau untung di form harga |
| `SectionHeader` | judul daftar produk, judul tiap section form & kartu penyesuaian |
| `EmptyState` / `AppLoadingView` / `AppErrorView` | keempat layar + dialog kategori (semua state) |
| `AppBanner` | peringatan stok menipis, header daftar stok menipis, catatan foto, error kategori |
| `AppDecorations.floating()` / `.tonal()` | bar simpan bawah, kartu pratinjau stok |
| Token `AppSizes` / `AppTone` / `AppTextStyles` / `AppDurations` | seluruh berkas — tidak ada hex, `Colors.*`, atau angka spacing mentah |

Kepatuhan §7.2 (DON'T) diperiksa manual: **nol** `Color(0x…)`, nol
`Colors.*`, nol `withOpacity/withValues`, nol `elevation:` Material, nol
`Card`/`Container`+`BoxDecoration` manual untuk permukaan, nol angka
spacing/radius mentah (ukuran khusus seperti tinggi field & bingkai
scanner disusun dari token, mis. `minTouchTarget + spaceSm`).

## 5. Hasil verifikasi

| Pemeriksaan | Hasil |
|---|---|
| `flutter analyze lib/features/products lib/features/inventory` | **No issues found!** |
| `flutter analyze` (seluruh proyek) | **No issues found!** |
| `flutter test test/features/products/` | **20 test lolos** (termasuk widget test threshold stok menipis M6 — teks "Stok menipis" tetap ada persis) |
| `flutter test` (seluruh proyek) | lolos di area ini; kegagalan sementara yang muncul saat pengujian berasal dari berkas milik agent lain yang sedang diedit (POS/Riwayat/Laporan) — hilang saat berkas mereka selesai, dan tidak menyentuh Produk/Inventori |
| Smoke render 360×640 dengan font asli (Plus Jakarta Sans di-load lewat `FontLoader`) | **6 skenario lolos tanpa overflow**: form tambah produk (di-scroll penuh), penyesuaian stok + pratinjau + ganti jenis, daftar stok menipis, riwayat stok kosong, dialog kategori, dan kartu produk kasus ekstrem (nama 51 karakter, kategori 33 karakter, nonaktif + stok menipis, harga Rp1.250.000) |

Catatan verifikasi: smoke test tersebut dijalankan di salinan kerja
sementara (di luar repo) agar tidak menambah berkas test permanen. Tanpa
memuat font asli, `flutter_test` memakai font uji yang setiap glifnya
selebar 1em sehingga chip apa pun akan "overflow" di lebar 360 — bukan
cerminan perangkat sungguhan; karena itu font aplikasi dimuat lebih dulu
sebelum mengukur.
