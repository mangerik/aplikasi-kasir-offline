# Laporan Milestone 9 — Impor Produk dari Excel

**Tanggal:** 12 Agustus 2026
**Acuan:** [prd-v1.1.md §4](prd-v1.1.md) · [plan-v1.1.md](plan-v1.1.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md) ·
[laporan-m7.md](laporan-m7.md)

---

## 1. Ringkasan

Arah balik dari export akhirnya ada. Katalog ratusan produk yang selama
ini harus diketik satu per satu lewat form HP kini bisa masuk **sekali
jalan — atau tidak masuk sama sekali**. Tembok pertama pengguna baru
(warung dengan 300–1.000 barang) resmi hilang, dan siklus **export →
edit di laptop → import** menjadi alur yang didukung resmi, bukan
kebetulan.

Yang dikerjakan bukan sekadar "membaca file Excel". Tiga hal berikut yang
menghabiskan sebagian besar usaha, karena tiga-tiganya kelas cacat yang
baru ketahuan setelah data pengguna rusak:

1. **Angka Indonesia.** `1.500` yang terbaca 1,5 berarti harga rokok
   salah 1.000 kali lipat dan baru ketahuan di depan pembeli. Aturan
   normalisasi ditulis eksplisit, dipisah antara **kolom uang** (titik
   selalu ribuan) dan **kolom kuantitas** (satu tanda diikuti ≤2 digit =
   desimal), lalu dikunci dengan uji tabel-kasus.
2. **Stok.** File Excel pengguna hampir selalu lebih tua daripada stok
   berjalan. Opsi "Timpa stok" **default mati**, dan kalau dinyalakan
   setiap perubahan stok meninggalkan baris `stock_movements` berisi nama
   filenya — jejak audit M4 tetap utuh.
3. **Atomisitas.** Gagal di baris ke-50 dari 100 berarti **nol** produk
   masuk. Satu `db.transaction()` untuk seluruh file, dengan penjaga
   terakhir yang menolak baris bermasalah dari dalam transaksi.

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **503/503 lulus**, termasuk **76 test baru M9**
  (50 parser/normalisasi/pratinjau, 20 penulisan database, 6 tampilan).
  Tidak ada satu pun test M0–M8 yang diubah.
- **Tidak ada dependency baru** (K-4.1): memakai `excel` & `file_picker`
  yang sudah ada sejak v1.0.
- **Tidak ada perubahan skema database.** `schemaVersion` tetap **1**,
  backup v1.0 ↔ v1.1 tetap kompatibel penuh.

---

## 2. Apa yang Dibangun

### 2.1 Model impor sebagai data murni — `domain/entities/product_import.dart`

Satu berkas berisi seluruh kosakata fitur ini: `ProductImportColumn`
(9 kolom template), `ProductImportIssue` (error vs peringatan),
`ProductImportRow`, `ProductImportParseResult`, `ProductImportOptions`,
`ProductImportPlanRow`/`ProductImportPlan`, `ProductImportLookup`, dan
`ProductImportSummary`.

Semuanya **objek data biasa tanpa Flutter/Drift/closure**, karena hasil
parsing harus bisa menyeberang isolate (K-4.2) dan dipakai bersama oleh
layer `data/` (menulis) maupun `features/` (menampilkan).

Dua keadaan yang sengaja dibedakan sejak model — dan inilah yang membuat
impor ulang file export tidak merusak apa pun:

| Keadaan | Bentuknya di model | Artinya saat memperbarui produk lama |
|---|---|---|
| Kolomnya **tidak ada di file** | tidak masuk `ProductImportParseResult.columns` | nilai lama **tidak pernah** disentuh |
| Kolom ada, **selnya kosong** | field bernilai `null` | pengguna memang mengosongkannya |

### 2.2 Parser & normalisasi — `data/services/product_import_service.dart`

- **Header**: dicocokkan *case-insensitive*, spasi ganda dirapikan,
  **urutan kolom bebas**, kolom asing (`No`, `Status Stok`, catatan
  pribadi pengguna) diabaikan diam-diam. Kolom wajib hilang → impor
  ditolak **sebelum satu baris pun diproses** (AC-4.4).
- **Sheet**: bernama `Produk` bila ada; kalau tidak, sheet pertama —
  dengan pencocokan "diawali `produk`" supaya file export v1.0 yang
  sheet-nya `Produk & Stok` tetap terbaca walau bukan sheet pertama.
- **Normalisasi** (PRD §4.3.C) dipisah dua fungsi statis murni supaya
  bisa diuji sebagai tabel kasus tanpa file:

  | Masukan | `parsePrice` | `parseQuantity` |
  |---|---|---|
  | `Rp 12.000` / `12.000` / `12000` / `12 000` | 12000 | — |
  | `1.500` | 1500 | 1500 |
  | `1,5` | 1,5 | 1,5 |
  | `1.5` | 15 (titik = ribuan) | 1,5 |
  | `12.500,5` | 12500,5 | 12500,5 |

- **Sel bertipe angka Excel dipakai apa adanya**, tidak lewat jalur teks
  — kalau tidak, stok `1234.567` hasil hitung Excel akan dibaca 1.234.567.
- **Tiga keadaan sel angka dibedakan**: kosong, tidak terbaca, dan
  terbaca. Menggabungkan "kosong" dengan "tidak terbaca" akan membuat
  harga jual yang salah ketik diam-diam menjadi 0.
- **Tingkat masalah** (PRD §4.3.D): nama kosong/kepanjangan, harga jual
  kosong/negatif/tak terbaca, dan barcode ganda dalam file = **error**
  (baris dilewati). Harga dibulatkan, modal > jual, satuan dipotong,
  stok tak terbaca, nama kembar = **peringatan** (baris tetap masuk).
- **Barcode ganda dalam file**: **semua** barisnya ditandai error dan
  pesannya menyebut seluruh nomor baris ("Barcode 899123 muncul di baris
  2 dan 4"). Tidak ada penebakan mana yang benar (AC-4.5).
- **Batas 5.000 baris** dihitung dari baris yang benar-benar berisi data
  — baris kosong di ekor file (sangat umum setelah pengguna menghapus
  isi sel di Excel) tidak ikut terhitung (K-4.4, AC-4.13).
- Parsing dijalankan lewat `compute` — pola persis `ExcelExportService`:
  yang menyeberang isolate hanya byte + nama file, dan yang kembali hanya
  objek data murni (K-4.2).

### 2.3 Pratinjau sebagai fungsi murni — `ProductImportService.buildPlan`

Perbandingan dengan database dipisah dari parsing. `loadImportLookup()`
memuat **sekali** (bukan per baris): peta barcode → id produk (aktif
**maupun nonaktif**, K-4.7), nama produk aktif, dan nama kategori yang
sudah ada. `buildPlan` lalu menentukan tiap baris akan **dibuat**,
**diperbarui**, **dilewati**, atau **bermasalah** — tanpa I/O, sehingga
seluruh aturan PRD §4.3.E bisa diuji tanpa database sungguhan.

Karena murni memori, mengubah opsi di layar pratinjau (mode duplikat,
timpa stok, kategori otomatis) langsung menyusun ulang angka ringkasan
tanpa membaca file atau database lagi.

### 2.4 Penulisan atomik — `ProductRepository.importProducts`

Satu `db.transaction()` untuk seluruh file (K-4.5):

- Produk lama dicocokkan **hanya lewat barcode** (K-4.3) — tidak pernah
  lewat nama, sekalipun namanya sama persis.
- Mode **Perbarui** (default) memperbarui nama, kategori, harga jual,
  harga modal, satuan, threshold, dan status aktif — **stok tidak ikut**
  kecuali opsi timpa stok menyala (AC-4.6). Mode **Lewati** tidak
  menyentuh produk lama sama sekali (AC-4.7).
- Kategori baru dibuat **sekali saja** walau muncul di puluhan baris,
  dengan peta kategori ikut diperbarui di dalam transaksi (AC-4.9).
- Timpa stok menyala → satu baris `stock_movements` per perubahan:
  `opname` untuk produk lama (`qty_change` = selisih), `adjust_in` untuk
  produk baru berstok awal, keduanya bercatatan
  `"Impor Excel: <nama_file>"` (AC-4.8). Stok yang **sama persis** tidak
  menghasilkan baris pergerakan palsu.
- Impor **tidak pernah menghapus** produk (K-4.6): file yang lebih pendek
  daripada katalog tidak menghilangkan apa pun.
- Penjaga terakhir `_assertImportable` dilempar **dari dalam** transaksi,
  sehingga baris yang sudah ditulis sebelumnya ikut dibatalkan.

### 2.5 Wizard — `features/products/screens/product_import_screen.dart`

Layar **penuh**, bukan bottom sheet (PRD §4.7): isinya panjang dan
pengguna perlu menggulir sambil membaca. Lima langkah PRD dipetakan
menjadi **tiga layar + satu dialog**, dengan indikator langkah
`1 Pilih file · 2 Pratinjau · 3 Selesai`:

1. **Pilih file** — kartu pengantar + `Unduh Template`, tiga kartu
   "yang perlu diketahui" (hanya `.xlsx`, barcode yang menentukan produk
   lama, stok tidak ditimpa), dan CTA `Pilih File .xlsx` setinggi 60 di
   bar mengambang bawah.
2. **Membaca** — `AppLoadingView` indeterminate; parsing berjalan di
   isolate sehingga UI tidak membeku.
3. **Pratinjau** — kartu ringkasan angka besar (`84 Baru · 30
   Diperbarui · 6 Bermasalah`), banner peringatan & kategori baru, panel
   opsi (radio mode duplikat + dua switch), chip filter
   `Semua/Baru/Diperbarui/Dilewati/Bermasalah` berhitung, lalu daftar
   baris. Daftarnya `SliverList.builder` — 5.000 baris tetap malas
   dirender.
4. **Konfirmasi** — dialog pola ganda seperti restore backup, lengkap
   dengan pintasan **Backup Dulu** (membuat + membagikan file backup dan
   mencatat `last_backup_at`, sama seperti kartu Backup di Pengaturan).
   Konfirmasi kedua berganti kalimat bila opsi timpa stok menyala.
5. **Hasil** — ringkasan hasil, banner kategori baru & pergerakan stok,
   dan tombol **Unduh Laporan Baris Bermasalah**.

**Dua titik masuk** ke layar yang sama (PRD §4.7): menu ⋮ di layar Produk,
dan tombol `Impor Produk dari Excel` di kartu **Export Excel** pada
Pengaturan. Yang kedua sengaja ditaruh di dalam kartu export — dipisah
`Divider` + eyebrow **ARAH SEBALIKNYA** — karena export dan impor adalah
dua arah dari satu berkas yang sama; memisahkannya ke kartu lain justru
menyembunyikan hubungan itu. Keduanya `Navigator.push`, bukan rute
go_router: impor alur sekali jalan yang tidak perlu bisa di-deep link.

Baris pratinjau (`import_preview_row_tile.dart`) menampilkan **nilai
hasil parsing**, bukan teks aslinya — supaya salah tafsir angka ketahuan
sebelum data masuk. Statusnya selalu membawa **label tertulis**, bukan
hanya warna, dan baris berperingatan ditandai `Baru · perlu dicek`
(nada `warning`) sehingga tidak terbaca sebagai kegagalan.

Seluruh warna lewat `context.palette`; gerbang
`no_hardcoded_colors_test.dart` tetap hijau.

### 2.6 Template & laporan

- **`template_produk.xlsx`** — sheet `Produk` (9 kolom PRD §4.3.A, header
  tebal) + sheet `Petunjuk` berisi aturan pengisian Bahasa Indonesia:
  cara menulis angka, arti barcode, dan peringatan bahwa stok tidak
  ditimpa. Dua baris contoh diberi penanda `CONTOH (hapus baris ini)`.
- **Laporan baris bermasalah** — `.xlsx` berisi nomor baris Excel,
  tingkat (`Dilewati`/`Peringatan`), **seluruh sel baris aslinya** di
  bawah header asli file, dan alasan Bahasa Indonesia (AC-4.17). Dibuat
  di isolate lalu dibagikan lewat `share_plus`.

---

## 3. Keputusan Teknis

### 3.1 K-4.8 (baru) — "kolom tidak ada" ≠ "sel kosong"

PRD hanya menyebut nilai default per kolom ("kosong = 0", "kosong =
`pcs`"). Diterapkan mentah, aturan itu **merusak** kasus yang justru
diwajibkan AC-4.2: file export v1.0 tidak punya kolom "Batas Stok
Menipis", jadi setiap impor ulang akan menghapus threshold semua produk
— diam-diam, tanpa error, dan baru terasa saat badge stok menipis
berhenti muncul.

Karena itu `ProductImportParseResult.columns` mencatat kolom yang
BENAR-BENAR ada di file, dan `importProducts` memakai `Value.absent()`
untuk kolom yang tidak ada. Nilai default tetap dipasang seperti PRD,
tapi **hanya untuk produk baru**.

### 3.2 K-4.9 (baru) — baris contoh template ditandai & dilewati parser

Template wajib berisi contoh (PRD §4.3.A), tapi pengguna yang lupa
menghapusnya akan mengimpor produk fiktif — dan impor **tidak pernah
bisa menghapus** produk (K-4.6), jadi pembersihannya manual satu per
satu. Baris contoh karena itu diawali penanda literal
`CONTOH (hapus baris ini)` dan parser melewatinya. Efek sampingnya
disengaja: template polos yang diimpor apa adanya ditolak dengan pesan
"file tidak berisi satu pun baris produk", bukan membuat dua produk
palsu.

### 3.3 K-4.10 (baru) — exception impor di berkas sendiri

`ImporProdukException` dan turunannya tinggal di
`domain/repositories/import_exceptions.dart`, **bukan** di
`repository_exceptions.dart` yang dipakai seluruh fitur. Dua alasan:
(a) M8 dikerjakan paralel di berkas milik bersama yang sama, dan (b)
tipe induknya membuat `AppErrorMessage` cukup mengenali satu tipe alih-alih
enam. Pesan tiap turunannya sudah Bahasa Indonesia dan siap ditampilkan
apa adanya — wizard menampilkan `e.toString()` langsung.

### 3.4 K-4.11 (baru) — stok tak terbaca hanya peringatan, bukan error

PRD §4.3.D menyebut error hanya untuk nama & harga jual. Stok yang tidak
terbaca (`"banyak"`, `"habis"`) karena itu **tidak** membuang barisnya:
produknya tetap masuk dengan stok kosong dan pengguna diberi peringatan.
Membuang seluruh baris karena kolom yang bahkan tidak wajib akan membuat
impor pertama pengguna gagal ratusan baris sekaligus. Stok **negatif**
tetap ditolak sebagai peringatan + dikosongkan, bukan disimpan.

### 3.5 K-4.12 (baru) — alias header di luar 9 header template

Selain header resmi, parser mengenali istilah yang lazim dipakai di file
buatan sendiri: `Nama`/`Nama Barang`, `Harga`, `Harga Beli`/`Modal`,
`Stock`/`Jumlah Stok`, `Unit`, `Stok Minimum`/`Batas Stok`. Ini
melonggarkan bunyi PRD "header harus persis", dengan alasan yang sama
seperti normalisasi angka: pengguna yang filenya ditolak karena menulis
"Nama Barang" tidak akan menyalahkan filenya, ia akan berhenti memakai
fiturnya. Kolom yang tetap tidak dikenal diabaikan diam-diam, jadi
risikonya nol.

### 3.6 K-4.13 (baru) — pencocokan barcode dibaca ulang di dalam transaksi

Pencocokan produk lama dilakukan per baris **di dalam** transaksi, bukan
dari snapshot yang diambil sebelum menulis. Akibatnya barcode kembar
yang entah bagaimana lolos sampai ke repository (parser sudah menandainya
error, AC-4.5) akan memperbarui produk yang barusan dibuat alih-alih
menabrak partial unique index dan membatalkan seluruh impor. Diuji
eksplisit: 31 baris dengan satu barcode kembar → 30 produk, nol kembar.

### 3.7 `adjust_in` produk baru hanya saat opsi timpa stok menyala

Mengikuti PRD §4.3.F secara harfiah (kedua butirnya berada di bawah
"Bila aktif"). Ini juga konsisten dengan form produk yang sudah ada:
menambah produk baru berstok awal lewat form pun tidak menghasilkan
baris `stock_movements`. Opsi "Timpa stok" dengan begitu menjadi satu
saklar yang mengatur seluruh penulisan jejak stok dari impor.

### 3.8 Wizard 5 langkah ditampilkan sebagai 3 langkah

Indikator langkah mengikuti PRD §4.7 (`1 Pilih file · 2 Pratinjau ·
3 Selesai`), sementara "membaca" & "konfirmasi" tidak diberi nomor
sendiri: keduanya keadaan sesaat, bukan tempat pengguna berhenti dan
memutuskan sesuatu. Menomori keduanya akan membuat indikator berubah
lima kali dalam satu alur yang cuma butuh tiga keputusan.

---

## 4. Hasil Verifikasi

### 4.1 Parser & normalisasi — 50 test

`test/data/services/product_import_service_test.dart`

| Kelompok | Yang dibuktikan |
|---|---|
| Tabel kasus harga (AC-4.10) | 10 bentuk masukan → nilai yang sama; NBSP `U+00A0` hasil `intl` ikut terbaca; negatif tetap negatif; "kosong" ≠ "tidak terbaca" |
| Tabel kasus stok (AC-4.11) | `1,5` = `1.5` = 1,5 sedangkan `1.500` = 1500 |
| Kolom Aktif | `Ya/ya/YA/Y/1/true/aktif` vs `Tidak/T/N/0/false`; bentuk asing tidak ditebak |
| Header (AC-4.3, AC-4.4) | urutan diacak + huruf besar-kecil beda tetap terbaca; kolom asing diabaikan; kolom wajib hilang → exception menyebut namanya; sheet `Produk` menang atas sheet pertama |
| Masalah per baris | nama/harga kosong = error; harga berpecahan, modal > jual, satuan >10 karakter = peringatan; baris kosong di ekor file diabaikan |
| Barcode ganda (AC-4.5) | kedua baris error, pesan menyebut **kedua** nomor baris, baris lain tidak terseret |
| Batas & file rusak (AC-4.13, AC-4.14) | 5.001 baris ditolak, 5.000 diterima; CSV yang diganti nama `.xlsx` → pesan Bahasa Indonesia; `.csv` ditolak sebelum dibaca |
| Template (AC-4.1) | dua sheet & 9 kolom sesuai PRD; template polos tidak menghasilkan produk palsu; template terisi 3 baris → 3 baris siap impor dengan seluruh field benar |
| **Export → import (AC-4.2)** | file `produk_stok.xlsx` **sungguhan** dari `ExcelExportService` diimpor apa adanya: `-` dibaca kosong, kolom `No`/`Status Stok` diabaikan, kolom threshold terdeteksi TIDAK ADA |
| `buildPlan` (AC-4.6, AC-4.7, AC-4.9) | mode Perbarui vs Lewati; kategori baru terkumpul sekali; opsi kategori mati → peringatan; nama kembar tanpa barcode → peringatan tapi tetap dibuat baru |
| Laporan (AC-4.17) | nomor baris Excel, isi baris **asli**, dan alasan Bahasa Indonesia |

### 4.2 Penulisan database — 20 test

`test/data/repositories/product_repository_impl_import_test.dart`

- **AC-4.6** — mode Perbarui: harga berubah, **stok tetap 37**, nol
  `stock_movements`.
- **AC-4.7** — mode Lewati: baris produk identik sebelum & sesudah.
- **K-4.7** — produk **nonaktif** ikut tercocokkan lewat barcode → tidak
  ada produk kembar.
- **AC-4.8** — timpa stok: `opname` dengan `qty_change` = −27,5,
  `stock_after` = 12,5, note `Impor Excel: produk_stok_agustus.xlsx`;
  stok yang sama persis **tidak** menghasilkan baris palsu; produk baru
  berstok awal → `adjust_in`.
- **AC-4.9** — "Snack" di dua baris → **satu** kategori dipakai dua
  produk; kategori yang sudah ada dipakai ulang tanpa memandang huruf
  besar-kecil; opsi mati → produk masuk tanpa kategori.
- **AC-4.2** — impor ulang bersifat idempoten (0 produk baru, nilai tidak
  bergeser); kolom yang tidak ada di file tidak menghapus threshold lama.
- **AC-4.15** — error disuntikkan di baris ke-50 dari 100 → **nol**
  produk & **nol** kategori tersimpan, exception menyebut baris 51;
  kategori yang sudah terbuat ikut dibatalkan.
- **AC-4.16** — `watchAll` & `watchLowStockCount` memancarkan nilai baru
  sendiri setelah impor (tanpa `invalidate` manual).
- **K-4.6** — produk yang tidak ada di file tetap utuh setelah impor.

### 4.3 Tampilan — 6 test

`test/features/products/product_import_wizard_test.dart`

- Menu ⋮ di layar Produk → wizard terbuka di langkah 1 dengan indikator
  langkah, tombol `Unduh Template`, dan CTA `Pilih File .xlsx`.
- Kartu Export Excel di Pengaturan → **wizard yang sama** terbuka
  (titik masuk ganda PRD §4.7 dibuktikan dari kedua arah).
- Keempat status baris membawa **label tertulis**, bukan hanya warna.
- Baris pratinjau menampilkan nomor baris Excel, nilai hasil parsing
  (`stok 1,5`, `Rp68.000`), dan alasan masalahnya.
- Baris berperingatan berbunyi `perlu dicek`, bukan `bermasalah`.
- Kartu ringkasan di mode gelap memakai `surface` palet gelap (tidak ada
  "pulau putih", AC-5.6).

### 4.4 Analyze & test

```
flutter analyze   →  No issues found!
flutter test      →  503/503 lulus (76 di antaranya baru dari M9)
```

---

## 5. Sisa Pekerjaan Manual (Device Fisik)

**Butuh device fisik** (tidak ada Android device/emulator di environment
ini) — item checklist sengaja dibiarkan tidak tercentang:

1. **File picker atas file dari WPS/Google Sheets.** Jalur kodenya sama
   dengan restore backup yang sudah terbukti jalan (`FilePicker.pickFiles`
   dengan `FileType.custom`), tapi perilaku pemilih file di HP sungguhan
   — terutama `.xlsx` dari Google Drive yang perlu diunduh dulu — hanya
   bisa dipastikan di device.
2. **File 1.000 baris tampil ≤ 15 detik tanpa frame drop (AC-4.12).**
   Parsing sudah di isolate dan daftar pratinjaunya lazy, tapi angka
   detiknya harus diukur di HP kelas menengah sungguhan.
3. **Daftar Produk & badge stok menipis ter-refresh sendiri (AC-4.16)
   di aplikasi berjalan.** Sudah diuji di tingkat stream Drift (§4.2);
   yang belum adalah pengamatan mata pada aplikasi utuh.

Seluruh item checklist M9 lainnya — termasuk **titik masuk ganda** yang
sempat ditunda selama M8 memegang `lib/features/settings/` — sudah selesai
dan tercentang.

---

## 6. Dampak untuk Milestone Berikutnya

- **M10 (lisensi)**: impor menulis banyak baris dalam satu transaksi
  panjang. Gerbang lisensi dilarang mengevaluasi ulang di tengah proses
  ini, sama seperti larangan mengunci di tengah transaksi penjualan
  (K-6.10) — evaluasi hanya saat start & resume.
- **M11 (rilis)**: tambahkan impor ke daftar uji manual rilis, khususnya
  file dari WPS Office (aplikasi spreadsheet paling umum di HP Android
  kelas menengah Indonesia) dan item §5 nomor 4 di atas.
- **M12 (skema 1 → 2)**: bila kolom produk bertambah, tambahkan
  anggotanya ke `ProductImportColumn` **dan** header template sekaligus —
  keduanya sudah dibangkitkan dari enum yang sama, jadi tidak bisa
  berbeda diam-diam. Uji tabel-kasus normalisasi tidak perlu diubah.
- **Pola yang bisa dipinjam**: `parseFile` → `buildPlan` → pratinjau →
  satu transaksi adalah bentuk yang sama untuk impor apa pun di masa
  depan (pelanggan, harga grosir). Yang mahal — normalisasi angka
  Indonesia & pemisahan "kolom tidak ada" vs "sel kosong" — sudah jadi
  fungsi murni yang bisa dipakai ulang.

---

## 7. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/data/services/product_import_service_test.dart              # parser & normalisasi
flutter test test/data/repositories/product_repository_impl_import_test.dart  # transaksi & stok
flutter test test/features/products/product_import_wizard_test.dart           # wizard
flutter run                                                                   # perlu device Android
```

Membuka wizard di aplikasi: **Produk → menu ⋮ (kanan atas) → Impor dari
Excel**. Belum punya file? **Unduh Template** di langkah 1, isi di
laptop, lalu impor kembali.
