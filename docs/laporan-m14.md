# Laporan Milestone 14 — Grafik Penjualan di Dashboard

**Tanggal:** 12 Agustus 2026
**Baseline:** commit `b44051d` — M7–M13 tuntas, analyze bersih, 734/734 test lulus, `schemaVersion` 3
**Acuan:** [plan-v1.1.md](plan-v1.1.md) "Milestone 14" · [prd-v1.1.md §9](prd-v1.1.md) &
[§10](prd-v1.1.md) · [architecture.md](architecture.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md)

---

## 1. Ringkasan

Laporan v1.0 menjawab "**berapa**". M14 menjawab "**bagaimana
perkembangannya**" dan "**kapan**" — dengan empat grafik yang menempel di
dashboard Laporan yang sudah ada, tanpa satu pun dependency baru dan tanpa
satu pun tabel baru.

Tiga hal yang menentukan hasilnya:

1. **Angka grafik tidak boleh berbeda dari kartu ringkasan.** Grafik yang
   cantik tapi angkanya meleset lebih buruk daripada tidak ada grafik sama
   sekali: pemilik warung akan berhenti percaya keduanya. Karena itu
   agregasinya memakai jalur yang sama (SQL, `voided` dikecualikan, filter
   kasir yang sama), dan kesamaannya **diuji** — bukan diasumsikan.
2. **Grafik digambar sendiri (K-9.1).** `fl_chart` ditolak; `app_bar_chart.dart`
   membangun batang vertikal, batang horizontal, dan batang bertumpuk dari
   `Flex` + `FractionallySizedBox`. Pertambahan APK: **+64 KB**.
3. **Anggaran 300 ms itu nyata dan hampir tidak tercapai.** Bentuk SQL yang
   PRD tuliskan (`'localtime'` per baris) memakan 218 ms untuk query omzet
   saja pada 100.000 transaksi. Perbaikannya (K-9.8) menurunkannya ke 54 ms
   tanpa mengubah satu pun hasil.

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **801/801 lulus**. Baseline 734 utuh **tanpa satu pun
  ekspektasi lama diubah**; **67 test baru**.
- `flutter build apk --release` → **sukses**, **0 dependency baru**
  (`pubspec.yaml` & `pubspec.lock` tidak tersentuh).
- APK arm64 release: 31.184.083 → **31.249.687 byte (+64 KB)** — AC-9.13
  (< 1 MB) lulus, tetap jauh di bawah batas 40 MB.
- `schemaVersion` **tetap 3**. Yang ditambahkan hanya satu index,
  idempoten, tanpa menyentuh `PRAGMA user_version` (K-9.6).
- `getSalesSeries` @ 100.000 transaksi: **< 300 ms** (AC-9.5), diuji
  otomatis.

---

## 2. Database — satu index, nol migrasi

### 2.1 Yang ditambahkan

| Objek | Bentuk |
|---|---|
| `idx_sales_status_created` | `CREATE INDEX IF NOT EXISTS ... ON sales(status, created_at)` |

Tidak ada tabel baru, tidak ada kolom baru, tidak ada backfill — sesuai
PRD §10 tahap "Tier 2c".

### 2.2 Kenapa `beforeOpen`, bukan `onUpgrade` (K-9.6)

Plan meminta "migrasi idempoten" dengan `schemaVersion` **tetap 3**. Dua
hal itu bertabrakan secara teknis:

- `MigrationStrategy.onUpgrade` hanya berjalan saat `from < to`.
- Database setiap pengguna yang memasang M13 **sudah** berada di versi 3.

Artinya, index yang ditaruh di `onUpgrade` tidak akan pernah lahir di
perangkat manapun yang sudah ada — persis perangkat yang paling butuh
index-nya. `beforeOpen` adalah satu-satunya jalur yang menjangkau database
lama maupun baru tanpa menyentuh `user_version`, dan `IF NOT EXISTS`
membuat pemanggilan di setiap pembukaan koneksi menjadi no-op setelah yang
pertama.

Menaikkan `schemaVersion` demi sebuah index justru merugikan: backup v1.2
akan ditolak aplikasi v1.1 lewat guard AC-10.2 padahal isi datanya
identik. Index bukan bagian dari bentuk data.

**Bukti:** `report_series_test.dart` memeriksa `sqlite_master` untuk
nama index **dan** memastikan `PRAGMA user_version` masih 3.

---

## 3. Query agregasi

### 3.1 Kontrak baru pada `ReportRepository`

```dart
Future<List<SalesPoint>> getSalesSeries({
  required DateTime start,
  required DateTime end,
  required SeriesBucket bucket,
  int? userId,
});

Future<List<HourlyPoint>> getHourlyDistribution({
  required DateTime start,
  required DateTime end,
  int? userId,
});
```

Keduanya mengembalikan deret **lengkap & terurut**: ember tanpa transaksi
tetap hadir bernilai nol, dan `getHourlyDistribution` selalu 24 baris.
Grafik yang bolong menyembunyikan hari sepi — padahal hari sepi itulah
informasinya.

### 3.2 Aturan ember (AC-9.1)

| Panjang rentang | Ember | Jumlah batang |
|---|---|---|
| 1 hari | per jam | 24 |
| 2–62 hari | per hari | 2–62 |
| > 62 hari | per bulan | ≤ ~24 untuk rentang setahun |

Aturannya hidup sebagai fungsi murni `SeriesBucket.forRange` sehingga bisa
diuji tanpa database maupun widget. Batas 62 (bukan 60) dipilih supaya dua
bulan penuh — termasuk pasangan bulan 31 hari — tetap tampil per hari.

### 3.3 Dua query, bukan satu JOIN (K-9.9)

Omzet + jumlah transaksi diambil dari `sales`; laba dari
`sale_items JOIN sales`. Menggabungkannya menjadi satu query membuat satu
penjualan tergandakan sebanyak barisnya sehingga `SUM(total)` ikut
menggandakan omzet — bug yang angkanya "hampir benar", dan karena itu
paling berbahaya. Ada test khusus untuk jebakan ini (satu transaksi
Rp30.000 dengan dua item wajib terbaca 30.000 & 1 transaksi, bukan 60.000
& 2).

Yang dikerjakan di Dart hanyalah menjodohkan kunci ember dan mengisi ember
kosong — **pembentukan sumbu waktu, bukan agregasi**. K-9.5 tetap utuh.

### 3.4 Zona waktu: `'localtime'` sekali, bukan per baris (K-9.8)

Bentuk yang PRD §9.5 tuliskan benar, tapi mahal. Diukur pada 100.000
transaksi (`NativeDatabase.memory()`):

| Bentuk query (ember harian) | Waktu |
|---|---|
| `strftime('%Y-%m-%d', created_at/1000, 'unixepoch', 'localtime')` | **218 ms** |
| tanpa konversi zona sama sekali | 27 ms |
| geseran zona disuntikkan sebagai angka, `strftime` tetap dipakai | **54 ms** |

`'localtime'` memaksa SQLite memanggil konversi zona sistem sekali untuk
**setiap baris**. Query omzet saja sudah melewati anggaran 300 ms AC-9.5
sebelum query laba dijalankan.

Perbaikannya: geseran zona dibaca **sekali** di muka — tetap lewat
`'localtime'`, tetap dari perangkat, dan tetap untuk momen di dalam
rentang yang diminta (bukan "sekarang", supaya zona yang pernah berubah
secara historis tetap benar untuk data lama):

```sql
SELECT (strftime('%s', ?1 / 1000, 'unixepoch', 'localtime') - (?1 / 1000)) AS off_seconds
```

lalu disuntikkan sebagai angka:

```sql
strftime('%Y-%m-%d', (created_at + :offsetMillis) / 1000, 'unixepoch')
```

Total `getSalesSeries` turun dari ~475 ms menjadi **~141 ms**.

**Kesetaraannya diperiksa, bukan diasumsikan:** satu test membandingkan
kedua bentuk baris demi baris untuk empat format ember sekaligus
(`'%Y-%m-%d %H'`, `'%Y-%m-%d'`, `'%Y-%m'`, `'%H'`) atas 400 transaksi yang
menyapu seluruh jam dalam sehari selama 50 hari — nol perbedaan.

**Batasnya jujur:** cara ini menganggap geseran zona tetap sepanjang
rentang yang diminta. Indonesia tidak menerapkan DST (PRD §9.5), jadi
asumsi itu berlaku penuh di sini; pada zona ber-DST, transaksi di sisi
lain batas pergantian bisa jatuh ke ember tetangga.

---

## 4. Widget grafik — `core/widgets/app_bar_chart.dart`

Tiga bentuk, satu keluarga visual, nol dependency:

| Widget | Dipakai untuk |
|---|---|
| `AppBarChart` | batang vertikal — tren penjualan & jam ramai |
| `AppHorizontalBarChart` | batang horizontal berlabel — produk terlaris |
| `AppStackedBar` | satu batang bertumpuk + legenda — komposisi metode bayar |

Keputusan bentuk:

- **Batang berdiri di atas alur (*track*) lembut `primary50`.** Ini bukan
  hiasan: alur itulah yang membuat ember bernilai **nol** tetap terlihat
  sebagai kolom kosong, dan sekaligus meneruskan bahasa visual bar
  proporsi yang sudah dipakai kartu metode bayar & produk terlaris sejak
  M4. Dua gaya bar berbeda di satu layar akan terbaca sebagai dua sistem.
- **Sumbu Y hanya dua label** (maksimum & nol), maksimumnya diringkas
  (`Rp1,2jt`) lewat `CurrencyFormatter.formatCompact` yang baru. Angka
  persisnya diperoleh lewat tap — tidak ada angka yang hilang, hanya
  dipindah tempat.
- **Tinggi area gambar tetap 160dp** apa pun datanya, supaya tata letak
  layar tidak melompat saat rentang berganti.
- **Semua nilai nol tidak menghasilkan `NaN`**: skala dipaksa 1 sehingga
  seluruh batang jatuh rata di garis dasar (AC-9.11, ada test).
- **Setiap batang punya `Semantics`** berisi label + nilai persisnya —
  angka tetap terbaca teks bagi pembaca layar.
- **Nol hex tetap.** Seluruh warna dari `context.palette`; test tema
  membandingkan warna batang di mode terang vs gelap dan mewajibkannya
  **berbeda**.

### 4.1 Target sentuh — AC-9.8 dan aritmetika (K-9.7)

AC-9.8 meminta area sentuh ≥ 48dp per batang. Itu tidak bisa dipenuhi apa
adanya, dan alasannya aritmetika murni:

- 7 batang × 48dp = **336dp**;
- area gambar di HP 5 inci hanya **~248dp** setelah padding layar (2×16),
  padding kartu (2×16), dan sumbu Y (48);
- PRD §9.3.A sendiri meminta **24 batang** untuk rentang satu hari.

AC-9.8 dan §9.3.A karena itu tidak bisa keduanya benar. Yang dijamin
sebagai gantinya:

1. setiap batang punya slot sentuh selebar `plotWidth / jumlahBatang`,
   **setinggi seluruh area gambar (160dp ≥ 48dp)**;
2. slot-slot itu **bersambungan tanpa satu piksel pun zona mati** — ada
   test yang menyapu seluruh lebar dan memastikan setiap posisi memilih
   tepat satu batang, dan bahwa 24 batang menghasilkan 24 indeks berbeda;
3. untuk grafik ≤ 5 batang, slotnya memang ≥ 48dp.

Alternatif yang ditolak: membuat grafik bisa di-scroll horizontal. Itu
akan membuat AC-9.12 ("label sumbu X dijarangkan otomatis bila tidak
muat") kehilangan makna — pada grafik yang bisa di-scroll, label selalu
muat.

### 4.2 Penjarangan label (AC-9.12)

`AppBarChartMetrics.labelStep` menampilkan label tiap `step` batang supaya
masing-masing punya ruang minimal 32dp. Labelnya digambar dalam
`OverflowBox` sehingga boleh melebar melewati slotnya sendiri tanpa
menggeser batang manapun — teks tetap terpusat di batangnya. Diuji: 7
batang menampilkan seluruh 7 label; 24 batang menampilkan kurang dari 24.

---

## 5. Empat grafik di dashboard

Semuanya menempel pada **pemilih rentang tanggal & filter kasir yang sudah
ada** (K-9.3, AC-9.14). Tidak ada satu pun pemilih baru — providernya
`ref.watch` `reportDateRangeProvider` & `reportUserFilterProvider` yang
sama dengan kartu ringkasan, sehingga konsistensinya struktural, bukan
hasil kode sinkronisasi.

| # | Grafik | Isi |
|---|---|---|
| 1 | **Tren Penjualan** | batang vertikal, ember otomatis; angka besar total periode; perbandingan periode sebelumnya; peralih Omzet ↔ Laba; tap batang → angka persis + "Lihat transaksi" |
| 2 | **Jam Ramai** | 24 batang jam 0–23 atas seluruh rentang; jam tersibuk diwarnai `primary`, sisanya tonal; kalimat "Paling ramai: 17.00–18.00 (…)" |
| 3 | **Komposisi Pembayaran** | satu batang horizontal bertumpuk + legenda **berlabel teks** + nominal + persentase; warna alias domain `tunai`/`nonTunai`/`hutang` |
| 4 | **Produk Terlaris** | batang horizontal 5 teratas dari `getTopProducts` yang sudah ada — tanpa query baru |

Catatan per grafik:

- **Grafik 1 — perbandingan periode.** Periode pembanding sama panjang dan
  menempel persis di depan rentang berjalan, dihitung dari **kalender**
  (bukan `subtract(Duration)`) supaya pergantian bulan & tahun benar.
  Bila periode pembanding kosong, yang tampil adalah kalimat "Tidak ada
  penjualan pada … untuk dibandingkan" — bukan "+100%". Persentase dari
  nol bukan kabar baik, itu pembagian nol yang disamarkan.
- **Grafik 1 — peralih Omzet/Laba** hanya dirender untuk Pemilik
  (`currentRoleProvider`); saat multi-user mati, perannya `owner` sehingga
  perilaku v1.0 tidak berubah sedikit pun. Kedua metrik ikut dalam **satu**
  hasil query, sehingga menekan peralih hanya menggambar ulang — tanpa
  query ulang dan tanpa memuat ulang layar (AC-9.6).
- **Grafik 1 — "Lihat transaksi"** menerapkan `historyFilterProvider`
  dengan rentang persis seukuran ember yang disentuh (batas akhir dikurangi
  1 milidetik karena filter riwayat inklusif di kedua ujung) lalu berpindah
  ke tab Riwayat. Filter kasir yang aktif ikut terbawa.
- **Grafik 3** memakai `DailySummary` yang **sudah** dimuat kartu ringkasan
  — tidak ada query baru, dan karena itu angkanya mustahil berbeda dari
  kartu di atasnya.
- **Grafik 4** menggantikan `TopProductTile` (berkasnya dihapus). PRD
  §9.3.D memberi pilihan "menggantikan/melengkapi"; melengkapi berarti dua
  daftar produk terlaris bersebelahan dengan isi yang sama persis, hanya
  beda bentuk.
- **Rentang kosong** memunculkan `EmptyState` bergaya sistem pada grafik 1
  & 2, dan grafik 3 menghilang sepenuhnya (tidak ada batang bertumpuk
  tanpa deret). Bukan grafik kosong, bukan `NaN` (AC-9.11).

---

## 6. Test

### 6.1 Test lama

**Nol ekspektasi lama diubah.** 734 test baseline lulus apa adanya,
termasuk `transactions_reports_ui_test.dart` yang menyapu dashboard
Laporan dari atas ke bawah — grafik disisipkan di antara pintasan
pelanggan dan section Produk Terlaris tanpa mengganggu satu pun assertion
yang ada.

### 6.2 Test baru (67)

| Berkas | Isi |
|---|---|
| `test/domain/entities/sales_series_test.dart` (13) | aturan ember 1/2/7/62/63/90/400 hari (AC-9.1), `dayCount` inklusif, `keyOf` identik dengan `strftime`, `floor`/`next` melewati batas bulan & tahun |
| `test/data/repositories/report_series_test.dart` (19) | jumlah batang = omzet kartu ringkasan (AC-9.2) **dan** = hitungan manual fixture; `voided` tidak menyumbang (AC-9.3); hutang belum lunas ikut; laba tidak menggandakan omzet (jebakan JOIN); ember kosong bernilai nol; transaksi di luar rentang tidak bocor; filter kasir konsisten dengan ringkasan (AC-9.14); jam ramai 24 baris & lintas hari; batas tengah malam lokal (AC-9.4); kesetaraan `'localtime'` vs geseran (K-9.8); rumus WIB/WITA/WIT eksplisit; gerbang sumber `'localtime'`; index ada & `user_version` masih 3 |
| `test/core/widgets/app_bar_chart_test.dart` (17) | geometri slot & lebar batang; tidak ada zona mati sentuh (AC-9.8/K-9.7); penjarangan label (AC-9.12); tinggi batang proporsional; semua-nol tanpa `NaN` & satu batang (AC-9.11); sumbu Y ringkas; tap pilih & lepas; semantics per batang; warna batang berbeda antara tema terang & gelap (AC-9.9); legenda batang bertumpuk berlabel teks & `<1%` (AC-9.10) |
| `test/features/reports/sales_charts_ui_test.dart` (7) | keempat grafik ter-render di HP 360dp **di kedua tema**; tap batang → angka persis + "Lihat transaksi"; peralih Omzet/Laba (AC-9.6); perbandingan periode (AC-9.7); rentang kosong → `EmptyState` (AC-9.11); "Lihat transaksi" membuka Riwayat dengan filter benar |
| `test/features/reports/report_range_test.dart` (5) | periode pembanding sama panjang & menempel tanpa celah, lintas bulan & tahun (AC-9.7); pemilihan ember per preset |
| `test/data/repositories/report_repository_impl_performance_test.dart` (+1) | `getSalesSeries` & `getHourlyDistribution` < 300 ms @ 100.000 transaksi (AC-9.5) |
| `test/core/utils/currency_formatter_test.dart` (+5) | `formatCompact`: `Rp1,5rb` / `Rp1,2jt` / `Rp3,4m`, 999.999 → `Rp1jt` (bukan `Rp1000rb`), negatif |

Uji performa memakai pola M4 yang sudah ada (`db.batch()` bulk insert),
dengan pemanasan satu query sebelum stopwatch — biaya menyiapkan statement
& memanaskan page cache bukan yang dialami pengguna saat berpindah rentang
tanggal.

---

## 7. Verifikasi

| Perintah | Hasil |
|---|---|
| `flutter analyze` | **0 issue** |
| `flutter test` | **801/801 lulus** (734 baseline + 67 baru) |
| `flutter build apk --release` | **sukses**, 85,7 MB (fat APK) |
| `flutter build apk --release --split-per-abi` | **sukses**, arm64 **31,2 MB** (< 40 MB) |
| `git status pubspec.yaml pubspec.lock` | **bersih** — 0 dependency baru (K-9.1) |
| Pertambahan APK arm64 | 31.184.083 → 31.249.687 byte = **+64 KB** (AC-9.13, batas 1 MB) |
| `schemaVersion` | **tetap 3** |

Gerbang mode gelap (`no_hardcoded_colors_test.dart`) lulus untuk seluruh
berkas baru: `app_bar_chart.dart` & `sales_charts.dart` tidak memakai satu
pun `AppColors.*`, `Colors.white/black`, `Color(0x…)`, maupun
`AppTextStyles.*` statis.

---

## 8. Yang TIDAK selesai (butuh perangkat fisik)

Satu item checklist sengaja **belum** dicentang:

- **Uji manual keterbacaan di HP 5 inci & tablet landscape (AC-9.12).**
  Uji widget pada viewport 360×780 sudah lulus di kedua tema tanpa
  overflow, dan penjarangan label sudah diuji secara geometris — tapi
  "batang tidak berdesakan" dan "terbaca di bawah matahari" adalah
  penilaian mata di perangkat nyata, bukan assertion.

AC-9.13 (pertambahan APK < 1 MB), yang di checklist digabung dengan item
di atas, **sudah terukur dan lulus** (+64 KB).

---

## 9. Catatan untuk M15

1. **Sapu empty state & kontras layar baru M12–M14 di kedua tema** sudah
   ada di checklist M15 — untuk M14 yang perlu dilihat adalah tiga
   `EmptyState` grafik dan kartu detail batang (`primary50` sebagai latar).
2. **Rantai migrasi 1 → 2 → 3 tidak tersentuh M14.** Index M14 lahir di
   `beforeOpen`, sehingga uji rantai migrasi M15 tetap menguji jalur yang
   sama seperti sebelumnya — tapi perlu ditambah satu assertion bahwa
   `idx_sales_status_created` ada setelah restore backup v1.0.
3. **K-9.8 punya batas yang perlu diingat kalau aplikasi ini pernah keluar
   dari Indonesia:** geseran zona dianggap tetap sepanjang rentang. Kalau
   suatu saat ada target pasar ber-DST, kembalikan `'localtime'` per baris
   dan cari anggaran waktunya di tempat lain (mis. hanya menghitung laba
   saat peralih "Laba" ditekan).
4. **`TopProductTile` sudah dihapus** — kalau M15 butuh daftar produk
   terlaris yang lebih panjang dari 5, tambahkan layar "Lihat semua",
   jangan hidupkan kembali dua daftar bersebelahan.
