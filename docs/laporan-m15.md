# Laporan Milestone 15 — Polish & Rilis v1.2.0 (Tier 2)

**Tanggal:** 12 Agustus 2026
**Baseline:** commit `f8ccb6a` — M7–M14 tuntas, analyze bersih, 801/801 test lulus, `schemaVersion` 3, `version: 1.1.0+2`
**Acuan:** [plan-v1.1.md](plan-v1.1.md) "Milestone 15" · [prd-v1.1.md §10 & §11.2](prd-v1.1.md) ·
[laporan-m11.md §6](laporan-m11.md) (daftar uji fisik yang dilanjutkan di sini) ·
[laporan-m12.md](laporan-m12.md) · [laporan-m13.md](laporan-m13.md) · [laporan-m14.md](laporan-m14.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md)

---

## 1. Ringkasan

M15 tidak menambah satu pun fitur. Tugasnya tiga: **membuktikan rantai
migrasi 1 → 2 → 3 aman ujung ke ujung**, **membuktikan aplikasi terasa
persis seperti v1.1.0 selama fitur barunya mati**, dan **menyapu cacat kecil
yang tertinggal di M12–M14** sebelum v1.2.0 dilepas.

Empat hal yang menentukan hasilnya:

1. **Rantai migrasi yang belum pernah diuji utuh.** M12 menguji 1 → 2, M13
   menguji 2 → 3. Yang tidak diuji keduanya justru jalur yang paling banyak
   dilalui pengguna nyata: warung yang melewatkan v1.1 dan memasang v1.2 di
   atas database v1.0-nya, sehingga **dua** migrasi berjalan berurutan dalam
   satu kali buka aplikasi. 13 test baru menutupnya, termasuk skenario
   restore backup lintas versi dan gerbang AC-10.2 pada versi final.

2. **Separuh AC-10.5 ternyata belum ada.** Rollback-nya sudah dijamin
   transaksi sejak M12, tapi "pesan Bahasa Indonesia yang jelas" tidak pernah
   ditulis: yang naik ke layar adalah `SqliteException` yang lalu berubah
   menjadi "Terjadi kesalahan tak terduga. Coba lagi." — pada satu-satunya
   momen pengguna paling perlu tahu bahwa **datanya utuh** (K-10.2).

3. **Sebelas pesan kesalahan M12/M13 tidak pernah sampai ke pengguna.**
   `AppErrorMessage` memelihara daftar tipe manual yang tertinggal dua kali
   dengan pola yang sama. Diganti penanda `DomainException` + gerbang
   otomatis, sehingga pola itu tidak bisa terulang ketiga kalinya (K-10.3).

4. **"Nol tap tambahan" akhirnya menjadi angka, bukan pendapat.** PRD §11.2
   menuliskan targetnya sebagai bilangan; sekarang ada test yang menghitung
   tap alur kasir tunai dan menegaskannya **5**, sama persis dengan baseline
   v1.0 (K-10.4).

Hasil: `flutter analyze` **0 issue**, `flutter test` **831/831 lulus**
(801 baseline + 30 baru, seluruh test lama **tanpa diubah** kecuali satu
literal teks yang memang ikut diperbaiki), APK release per-ABI & App Bundle
**sukses** dengan R8 aktif, `version: 1.2.0+3`.

**Tag `v1.2.0` sengaja TIDAK dibuat agent ini** — sama seperti M11, tag &
commit adalah pekerjaan orkestrator.

---

## 2. Rantai migrasi 1 → 2 → 3 (AC-10.1 s.d. AC-10.5)

### 2.1 Yang diuji, dan kenapa terpisah dari uji M12/M13

`test/data/db/migration_chain_v1_to_v3_test.dart` (13 test) membuka snapshot
database **v1.0 nyata** (`test/fixtures/v1_database_fixture.dart`, DDL
salinan `sqlite_master` build v1.0) dengan `AppDatabase` build ini, lalu
memeriksa hasilnya dari luar lewat `sqlite3` mentah — bukan lewat Drift, yang
hanya bisa melihat bentuk yang ia harapkan.

| Kelompok | Yang dijamin |
|---|---|
| Rantai (6 test) | `user_version` berakhir di 3; jumlah baris seluruh tabel v1.0 identik; total hutang identik (**Rp0** selisih); seluruh `sales.customer_name` identik byte per byte (K-7.1); **bentuk setiap kolom v1.0 dibandingkan sebelum vs sesudah** (nama + tipe) — inilah bukti "tidak ada `DROP COLUMN`" yang sesungguhnya (AC-10.4); backfill M12 **dan** M13 keduanya berjalan dalam rantai yang sama; 13 index (7 v1.0 + 3 M12 + 2 M13 + 1 M14) semuanya ada; fitur baru tetap **mati** setelah migrasi |
| Kegagalan (2 test) | Kegagalan di langkah kedua mengembalikan database ke **v1.0 utuh** — `user_version` tetap 1, `sales.customer_id` milik langkah pertama ikut tergulung, tabel `users` & `customer_point_entries` tidak pernah lahir; pesannya Bahasa Indonesia siap tampil, bukan `SqliteException` mentah |
| Restore lintas versi (5 test) | Backup v1.0 (`user_version` 1) & v1.1 (2) diterima lalu termigrasi otomatis ke 3 tanpa kehilangan baris; backup v1.2 (3) diterima apa adanya; backup dari versi **lebih baru** ditolak dengan kalimat AC-10.2 pada versi final; angka yang dibandingkan guard = angka yang benar-benar ditulis Drift ke file |

Satu tambahan yang diminta [laporan-m14.md §9](laporan-m14.md): index grafik
`idx_sales_status_created` diperiksa ada **setelah restore backup v1.0**. Ia
lahir di `beforeOpen` (K-9.6), bukan di `onUpgrade`, jadi jalurnya berbeda
dari index lain dan pantas diperiksa terpisah.

### 2.2 Fixture v1 mendapat PIN global opsional

`V1DatabaseFixture.create(path, withGlobalPin: true)` menulis
`settings.pin_hash`/`pin_salt` seperti warung yang memasang kunci PIN sejak
v1.0. Tanpa itu, cabang terpenting migrasi 2 → 3 (PIN lama → akun
**Pemilik**, AC-8.2) hanya pernah diuji dari snapshot v2 — padahal pengguna
yang melompat dari v1.0 ke v1.2 justru menempuh jalur ini. Nilai default
`false` menjaga seluruh test M12 tetap lulus tanpa diubah.

### 2.3 Kegagalan migrasi disuntikkan, bukan disimulasikan dengan mock

Drift memakai `CREATE TABLE IF NOT EXISTS`, jadi kegagalan dipicu dengan
database v1.0 yang sudah "kotor": ada tabel `customers` sisa dengan bentuk
berbeda. Migrasi lolos membuat tabelnya, lalu pecah beberapa langkah
kemudian saat index dibuat di atas kolom yang tidak ada — persis bentuk
kegagalan yang tidak bisa diramalkan sebelumnya, dan yang paling berguna
untuk membuktikan rollback.

### 2.4 `MigrasiDatabaseGagalException` (K-10.2)

```dart
try {
  await transaction(() async { … });
} catch (e, s) {
  Error.throwWithStackTrace(
    MigrasiDatabaseGagalException(dari: from, ke: to, penyebab: e), s);
}
```

Pesannya:

> Pembaruan data dari versi 1 ke versi 3 gagal. Data Anda TIDAK berubah —
> semuanya kembali seperti sebelum pembaruan. Coba buka ulang aplikasi; bila
> tetap gagal, pulihkan dari file backup terakhir.

Penyebab teknisnya disimpan di field `penyebab` untuk laporan bug dan tidak
ikut ditampilkan.

---

## 3. Sapu polish M12–M14 — enam cacat yang diperbaiki

Tidak ada satu pun fitur yang ditambahkan. Audit menyisir seluruh layar baru
M12–M14 (pelanggan, poin, multi-user, grafik) untuk empty state, pesan
Indonesia, target sentuh, dan warna di kedua tema.

**Kabar baik lebih dulu:** nol warna hardcoded di seluruh berkas M12–M14 —
gerbang AC-5.6 memang bekerja — dan hampir seluruh daftar sudah memakai
`EmptyState`.

| # | Cacat | Perbaikan |
|---|---|---|
| 1 | **Sebelas exception M12/M13 berubah jadi pesan generik.** "Pelanggan sudah ada", "Poin tidak cukup", "Pemilik terakhir tidak boleh dinonaktifkan" — semuanya sampai ke pengguna sebagai "Terjadi kesalahan tak terduga. Coba lagi.", di seluruh layar pelanggan & pengguna sekaligus | Penanda `DomainException` + gerbang otomatis yang memindai berkas exception (K-10.3) |
| 2 | **`forgot_pin_screen.dart` menampilkan `e.toString()`** — satu-satunya tempat di M12–M14 yang tidak lewat `AppErrorMessage`; `Exception: …` bisa muncul di `errorText` field | `AppErrorMessage.from(e)` |
| 3 | **Grafik komposisi pembayaran menghilang diam-diam** saat memuat, saat gagal, dan saat rentang kosong — judul section-nya ikut lenyap | Pola yang sama dengan dua grafik di atasnya: judul selalu ada, isinya memuat / error / `EmptyState` / data |
| 4 | **Chip pengguna aktif 44dp** — satu-satunya elemen interaktif M12–M14 di bawah ambang target sentuh; inisialnya 10px, di luar skala tipografi | 48dp (`minTouchTarget`) & 11px (`labelSmall`) |
| 5 | **Tombol "Hitung Ulang Saldo" dipaksa 48dp** oleh `SizedBox`, padahal tema memberi 52dp untuk `OutlinedButton` — mengecil dibanding tombol lain | `AppSizes.buttonHeight` |
| 6 | **Dua `AppErrorView` tanpa `title`** (layar Masuk & Kelola Pengguna) jatuh ke judul default "Gagal memuat data"; yang di layar Masuk bahkan **membuang** error aslinya | Judul spesifik + `AppErrorMessage.from(error)`, seragam dengan layar pelanggan |

Ditambah empat string M12 yang memakai `...` alih-alih karakter elipsis `…`
seperti layar-layar acuan (`products_screen.dart`, `low_stock_screen.dart`).

**Cakupan tema gelap** diperluas: `dark_mode_screens_test.dart` kini memuat
lima layar baru yang sebelumnya tidak pernah dirender gelap oleh test mana
pun — **Masuk**, **Kelola Pengguna**, **Kode Pemulihan**, **Akses Ditolak**,
dan **Detail Pelanggan**. Tiga yang pertama hidup di luar shell navigasi
(tidak ada AppBar bertema yang menutupi kesalahan), jadi satu warna terang
yang tertinggal di sana akan menjadi "pulau putih" seukuran layar penuh.
Kelimanya lulus tanpa perlu perbaikan — yang kurang memang cuma penjaganya.

---

## 4. Regresi "fitur mati = perilaku v1.1.0" (AC-7.6, AC-8.1)

`test/features/regresi_perilaku_v1_test.dart` (4 test) menguji satu-satunya
keadaan yang dialami mayoritas pengguna: **semuanya mati** — multi-user mati
(default), program poin mati (default), printer belum dipasang.

| Test | Yang dijamin |
|---|---|
| Alur kasir inti | Urutan tap **persis sama** dengan regresi v1.0 di `pos_checkout_flow_test.dart`, dan jumlahnya ditegaskan **5**. Sisi datanya ikut: `sales.user_id`, `sales.user_name`, `sales.customer_id` wajib `NULL`, buku besar poin wajib kosong |
| Layar Kasir | Nol `ActiveUserChip`, nol menu ⋮, nol teks "Ganti Kasir", tidak pernah muncul layar Masuk |
| Sheet pembayaran | Nol elemen poin (`poin`/`Poin` tidak ditemukan di layar); pemilih pelanggan tidak pernah berlabel wajib untuk tunai |
| Riwayat & Laporan | Nol filter "Kasir" |

Prasyaratnya ikut ditegaskan di awal test: tabel `settings` benar-benar tidak
memuat `points_enabled`, `multi_user_enabled`, maupun `printer_address` —
karena "fiturnya mati" dan "key-nya tidak ada" adalah dua keadaan berbeda,
dan yang dialami pengguna sesudah update adalah yang kedua.

---

## 5. Verifikasi

| Perintah | Hasil |
|---|---|
| `flutter analyze` | **0 issue** |
| `flutter test` | **831/831 lulus** (801 baseline + 30 baru) |
| `flutter build apk --release --split-per-abi` | **sukses** — 27.398.123 / 31.249.783 / 33.690.991 byte (armeabi-v7a / arm64-v8a / x86_64) |
| `flutter build appbundle --release` | **sukses** — `app-release.aab` 76,7 MB (memuat 3 ABI; Play mengirim per perangkat) |
| R8 / shrink | **aktif** (`isMinifyEnabled = true`, `proguard-android-optimize.txt` + `proguard-rules.pro`) |
| Ukuran APK terdistribusi | **26,1 / 29,8 / 32,1 MiB** — ketiganya di bawah batas 40 MB (AC-3.14, AC-6.22) |
| Pertambahan sejak M14 (arm64) | 31.249.687 → 31.249.783 byte = **+96 byte** |
| Dependency baru | **0** (`pubspec.yaml` hanya berubah pada baris `version:`) |
| `schemaVersion` | **tetap 3** |
| Rahasia di repo (AC-6.19) | **bersih** — nol `*.key`/`*.pem`/`*.jks`/`lisensi-terbit.csv`/keystore ter-*track*, nol blok kunci privat |
| `version:` | `1.1.0+2` → **`1.2.0+3`** |

### Test baru (30)

| Berkas | Jumlah | Cakupan |
|---|---|---|
| `test/data/db/migration_chain_v1_to_v3_test.dart` | 13 | rantai 1 → 2 → 3, AC-10.1 s.d. AC-10.5, restore lintas versi, gerbang AC-10.2 pada versi final |
| `test/features/regresi_perilaku_v1_test.dart` | 4 | AC-7.5, AC-7.6, AC-8.1, AC-8.9 — "nol tap tambahan" sebagai angka |
| `test/features/settings/backup_reminder_test.dart` | 5 | AC-10.6, ambang "> 7 hari" dari kedua sisi, di kedua tema |
| `test/features/dark_mode_screens_test.dart` | +5 | lima layar baru M12/M13 di mode gelap (AC-5.10) |
| `test/core/utils/error_message_test.dart` | +3 | sebelas exception M12/M13 + gerbang penanda `DomainException` |

Ditambah satu assertion baru di `sales_charts_ui_test.dart` (grafik komposisi
pembayaran tetap menjelaskan diri pada rentang kosong).

Satu test lama diubah: literal `'Ketik nama atau no. HP...'` di
`pos_checkout_flow_test.dart` mengikuti perbaikan elipsis. Perubahan ini
tidak menyentuh ekspektasi perilaku mana pun (Definisi Selesai poin 3).

---

## 6. Metrik keberhasilan PRD §11.2, satu per satu

| Metrik | Target | Status |
|---|---|---|
| Nama pelanggan duplikat akibat typo setelah migrasi | berkurang ≥ 90% | ✅ pada data uji: 3 ejaan kembar ("Bu Ani"/"bu ani"/"Bu Ani ", "Mbak Sri"/"MBAK SRI") → **0** (100%). Angka "pada data uji nyata" tetap menunggu database warung sungguhan |
| Selisih total hutang sebelum vs sesudah migrasi | **Rp0** | ✅ diuji di rantai penuh **dan** di langkah 1 → 2 |
| Selisih saldo poin vs jumlah buku besar | **0 poin** | ✅ invarian acak `points_ledger_test.dart` (AC-7.11) |
| Tap tambahan pada alur kasir tanpa memilih pelanggan | **0** | ✅ dikunci sebagai angka (§4) |
| Kebocoran angka laba ke akun Kasir | **0** | ✅ `auth_redirect_test.dart` per rute + percobaan rute langsung |
| Transaksi tanpa `user_id` saat multi-user aktif | **0** | ✅ `user_trail_test.dart` |
| Pemilik terkunci permanen tanpa jalan pemulihan | **0** | ✅ kode pemulihan wajib dicatat (centang wajib) + diuji; **rasa**-nya tetap butuh uji fisik (blok F) |
| Waktu query + render grafik @ 100.000 transaksi | < 300 ms | ✅ ~141 ms di mesin pengembang (M14, K-9.8); angka di HP kelas menengah butuh perangkat |
| Selisih total grafik vs kartu ringkasan | **Rp0** | ✅ `report_series_test.dart` (AC-9.2) |
| Dependency baru untuk grafik | **0 package** | ✅ `pubspec.yaml` tidak bertambah sejak M11 |
| Pertambahan ukuran APK akibat grafik | < 1 MB | ✅ +64 KB (terukur di M14) |

Dari PRD §11.1 yang masih mengikat di rilis ini: **ukuran APK < 40 MB** ✅
(§5); **cold start < 3 detik** dan **verifikasi lisensi < 1 detik** butuh
perangkat fisik (blok G).

---

## 7. Daftar Uji-Terima Manual Final — Satu Sesi Device Fisik

Gabungan [laporan-m11.md §6](laporan-m11.md) blok A–G (Tier 1) **ditambah
blok H** untuk M12–M14. Kerjakan berurutan; **A harus tuntas lebih dulu**
karena gerbang lisensi menghalangi semua yang lain.

### A. Prasyarat rilis (sekali, sebelum semua)

- [ ] Keystore rilis dibuat & dicadangkan di luar laptop (§8)
- [ ] `build.gradle.kts` memakai `signingConfig` rilis; build ulang
      `--split-per-abi` sukses
- [ ] APK arm64 dipasang di **2 perangkat nyata** (idealnya 1 HP kecil ~5",
      1 tablet)
- [ ] **Pasang v1.1.0 lebih dulu di salah satu perangkat, isi data
      secukupnya, JANGAN backup selama > 7 hari** (atau mundurkan jam) →
      pengingat backup muncul **sebelum** dipasangi v1.2.0 (AC-10.6)

### B. Lisensi (M10) — gerbang penjualan

- [ ] Kode perangkat tampil di layar Aktivasi kedua HP; catat keduanya
- [ ] Terbitkan **2 kode** lewat `dart run tool/license_generator.dart`:
      satu **trial**, satu **lifetime**
- [ ] Aktivasi jalur **pindai QR** dengan kamera nyata → **≤ 30 detik**
- [ ] Aktivasi jalur **tempel dari WhatsApp** → **≤ 30 detik**
- [ ] Aktivasi jalur **ketik manual** → **≤ 2 menit**
- [ ] Kode untuk perangkat **lain** ditolak dengan pesan spesifik (AC-6.5)
- [ ] Kode **salah ketik 1 karakter** dikenali sebagai salah ketik, bukan
      kode palsu (CRC, K-6.7)
- [ ] **Uninstall → install ulang** (APK bertanda tangan sama): kode
      perangkat **SAMA**, kode trial lama **tetap kedaluwarsa** (AC-6.3,
      AC-6.11)
- [ ] **Mundurkan jam 1 tahun**: banner tampil, sisa masa berlaku **tidak
      bertambah** (AC-6.8/§6.3.G)
- [ ] Lisensi berakhir → **Riwayat, Laporan, Export, Backup tetap bisa
      diakses** (K-6.11)
- [ ] Gerbang **tidak pernah** mengunci di tengah transaksi berjalan
      (AC-6.18)
- [ ] Verifikasi kode di HP kelas menengah **< 1 detik** (PRD §11.1)
- [ ] Jalankan alur pembelian penuh dari sisi **penjual** dan **pembeli**;
      simpan hasilnya sebagai catatan rilis

### C. Mode gelap (M7)

- [ ] **Cold start mode gelap: tidak ada kedip putih** (AC-5.5), termasuk
      transisi dari splash hijau `#1B7A43`
- [ ] **"Ikuti Sistem"**: ubah tema Android saat aplikasi terbuka → ikut
      berubah **tanpa restart** (AC-5.3)
- [ ] Status bar & ikon sistem terbaca di **kedua** tema (AC-5.9)
- [ ] Angka & pill status terbaca di HP kecil **dalam ruangan gelap**
      (AC-5.11)
- [ ] Mode gelap di **tablet** (breakpoint 600dp, layar Kasir dua panel)

### D. Printer thermal (M8)

- [ ] Pasangkan printer di Pengaturan Bluetooth Android (PIN `1234`/`0000`)
- [ ] **Tombol "Buka Pengaturan Bluetooth Android" benar-benar membuka
      layar itu** (handler Kotlin M11, belum pernah diuji di perangkat)
- [ ] **Cetak Uji**: garis penggaris lurus, angka rata kanan
- [ ] Transaksi → layar sukses → **Cetak Struk** → **≤ 5 detik** sampai
      kertas keluar
- [ ] **Cetak Ulang** dari detail transaksi lama → `** CETAK ULANG **`
- [ ] Transaksi dibatalkan → `** DIBATALKAN **`
- [ ] Uji pada **3 model printer 58mm berbeda** → keberhasilan **≥ 90%**
- [ ] **Printer dimatikan / kehabisan kertas saat cetak**: transaksi **tetap
      tersimpan utuh** — **0 kasus** transaksi hilang
- [ ] **Android 12+**: tolak izin `BLUETOOTH_CONNECT` → penjelasan +
      pintasan, **bukan crash** (AC-3.10)

### E. Impor Excel (M9)

- [ ] Impor **500 produk** dari file valid → **≤ 20 detik**, 0 baris salah
      tafsir
- [ ] File dengan **kolom wajib hilang** → ditolak sebelum satu baris pun
      diproses, pesan menyebut nama kolomnya (AC-4.4)
- [ ] File dengan **beberapa baris rusak** → semua dilaporkan
- [ ] **Impor gagal di tengah** → **0 produk** tersimpan (AC-4.15)
- [ ] Pengisian katalog 300 produk terasa **≤ 15 menit** ujung ke ujung

### F. Backup & migrasi (M11 + M15)

- [ ] Backup di HP A → **restore di HP B**: seluruh data utuh
- [ ] **Pengaturan printer ikut terbawa** restore; printer HP A tidak ada di
      HP B → gagal terhubung dengan pesan wajar, **tanpa memblokir aplikasi**
      (AC-3.13)
- [ ] Restore file **bukan backup** (mis. foto yang diganti nama `.db`) →
      pesan "bukan file database", aplikasi tidak rusak
- [ ] **Restore backup v1.0 (schema 1) di v1.2.0** → migrasi 1 → 2 → 3 jalan
      otomatis, **total hutang sama persis**, daftar pelanggan langsung rapi
      (AC-10.3, AC-7.1, AC-7.2)
- [ ] **Restore backup v1.1 (schema 2) di v1.2.0** → seluruh akun & perannya
      terbawa, aplikasi meminta masuk lagi (AC-8.16)
- [ ] Backup dari perangkat **ber-v1.2** dicoba direstore di perangkat yang
      masih **v1.1** → ditolak dengan kalimat "File backup berasal dari versi
      aplikasi yang lebih baru…" (AC-10.2) — **inilah gerbang yang membuat
      M11 wajib dirilis lebih dulu**
- [ ] **Kode pemulihan Pemilik**: catat kodenya, lupakan PIN, pulihkan →
      kode lama hangus & kode baru terbit (AC-8.3)

### G. Regresi alur v1.0 & smoke rilis

- [ ] Seluruh checklist [prd.md](prd.md) §4 & §5 di **HP kecil** dan
      **tablet**, **mode terang** dan **gelap**
- [ ] Alur kasir inti tetap **tiga langkah**; tidak ada tap tambahan
- [ ] **Cold start < 3 detik** diukur di HP kelas menengah
- [ ] Ukuran APK terpasang tetap **< 40 MB**

### H. Fitur Tier 2 — M12, M13 & M14 (**baru di sesi ini**)

**Pelanggan & poin (M12)**

- [ ] Transaksi tunai **tanpa** memilih pelanggan: hitung tap-nya —
      **tidak boleh bertambah satu pun** dibanding v1.1.0 (AC-7.5)
- [ ] Pemilih pelanggan: ketik nama baru → "Buat pelanggan baru" → hutang
      tersimpan atas nama itu (AC-7.4)
- [ ] Nyalakan **Program Poin** → belanja Rp37.000 memberi **3 poin**;
      Rp9.999 memberi **0** (AC-7.7)
- [ ] Tukar poin di sheet pembayaran → struk memuat baris **"Tukar poin"**
      & **"Poin Anda"**; cetak ke printer thermal dan periksa kertasnya
- [ ] Batalkan transaksi berpoin → poin ditarik & poin yang ditukar kembali;
      saldo tidak pernah negatif
- [ ] **Matikan Program Poin** → nol elemen poin di layar mana pun termasuk
      struk (AC-7.6)
- [ ] Gabungkan dua pelanggan → riwayat & hutang keduanya menyatu, sumber
      hilang dari daftar aktif (satu arah, tidak bisa dibatalkan)
- [ ] Pencarian pada daftar pelanggan besar terasa **instan** (< 100 ms,
      AC-7.14) — inilah angka yang mesin pengembang tidak bisa buktikan

**Multi-user (M13)**

- [ ] Nyalakan multi-user pada perangkat yang **sudah punya PIN sejak
      v1.0** → PIN itu langsung menjadi PIN Pemilik, **tidak diminta membuat
      PIN baru** (AC-8.2)
- [ ] **Kode pemulihan** tampil sekali, centang wajib menolak ditutup
      sebelum dicentang; salin & simpan
- [ ] Buat akun **Kasir** → masuk sebagai Kasir: **nol angka laba & harga
      modal** di seluruh layar, Riwayat hanya hari ini, tidak bisa void
      (AC-8.5, AC-8.6)
- [ ] **Ganti kasir saat keranjang berisi** → kembali masuk, keranjang
      **masih utuh** (AC-8.11, AC-8.12)
- [ ] **Kunci otomatis** 1 menit → layar HP mati, buka lagi → diminta PIN
- [ ] **5 PIN salah** → keypad terkunci 30 detik; tutup-paksa aplikasi →
      **kuncinya tetap berlaku** (AC-8.10)
- [ ] Rasa **keypad PIN** di jempol: ukuran tombol, jarak, getaran
- [ ] Struk memuat baris **"Kasir: <nama>"**; ganti nama kasir → struk lama
      **tetap** menyebut nama saat transaksi (AC-8.7, AC-8.8)
- [ ] Chip pengguna aktif di AppBar Kasir **terbaca & mudah ditap** (48dp,
      diperbaiki di M15) tapi tidak menyaingi tombol "Bayar"
- [ ] **Matikan multi-user** → akun kasir nonaktif, PIN Pemilik kembali jadi
      PIN global, riwayat lama tetap menyebut kasirnya (AC-8.13)

**Grafik (M14)**

- [ ] Grafik tren, jam ramai, komposisi pembayaran & produk terlaris terbaca
      di **HP 5 inci** — batang tidak berdesakan, label dijarangkan (AC-9.12)
- [ ] Sama di **tablet landscape**
- [ ] Tap batang → angka persis muncul; "Lihat transaksi" membuka Riwayat
      terfilter
- [ ] Rentang **tanpa transaksi** → ketiga grafik menjelaskan diri
      (termasuk **komposisi pembayaran**, yang sebelum M15 menghilang)
- [ ] Total grafik **sama persis** dengan kartu ringkasan di atasnya
- [ ] Sebagai **Kasir**: peralih "Laba" **tidak ada** sama sekali
- [ ] Keterbacaan grafik di **mode gelap**, di bawah cahaya terang

---

## 8. PENGHALANG RILIS yang masih berdiri — keystore rilis

Belum berubah sejak [laporan-m11.md §5](laporan-m11.md), dan **wajib
diselesaikan pemilik sebelum v1.2.0 dibagikan**:

`android/app/build.gradle.kts` masih menandatangani build release dengan
**kunci debug**. Akibatnya mengikat pada dua hal sekaligus:

1. **Kode perangkat (SSAID) berbeda per kunci penanda tangan.** Kode lisensi
   yang diterbitkan untuk APK bertanda tangan debug tidak akan berlaku
   setelah APK ditandatangani kunci rilis — jadi blok B di atas hanya sah
   dikerjakan **setelah** keystore rilis ada.
2. **Keystore adalah rahasia jangka panjang milik pemilik.** Kehilangannya
   berarti tidak bisa lagi merilis pembaruan untuk pemasangan yang sudah
   beredar, selamanya. Karena itu ia sengaja **tidak** dibuat agent: membuat
   lalu meninggalkannya di direktori kerja adalah cara paling rapi untuk
   kehilangannya.

Selain itu: **tag `v1.2.0`, commit, dan push adalah pekerjaan orkestrator**,
bukan agent M15 — sama seperti M11.

---

## 9. Yang TIDAK selesai (butuh perangkat fisik)

Dua item checklist M15 sengaja dibiarkan tidak tercentang:

1. **Regresi manual seluruh alur di HP kecil & tablet, terang & gelap.**
   Padanan otomatisnya hijau seluruhnya (831 test), tapi "terasa sama seperti
   kemarin" adalah penilaian tangan. Daftar lengkapnya ada di §7.
2. **Cold start < 3 detik di device fisik.** Bagian lain dari item yang sama
   — build release, R8, dan ukuran < 40 MB — **sudah terukur dan lulus**
   (§5).

Yang juga masih menunggu dari milestone sebelumnya (semuanya sudah masuk
daftar §7): 3 merek printer thermal (M8), impor 500 produk di perangkat
(M9), alur aktivasi lisensi pada APK bertanda tangan rilis (M10),
keterbacaan grafik di HP 5 inci & tablet (M14), serta pencarian 2.000
pelanggan < 100 ms (M12).

---

## 10. Status akhir plan v1.1

| Milestone | Hasil | Sisa |
|---|---|---|
| **M7** Mode gelap | ✅ selesai | uji manual cold start & "Ikuti Sistem" (blok C) |
| **M8** Printer thermal 58mm | ✅ selesai | 3 merek printer (blok D) |
| **M9** Impor Excel | ✅ selesai | impor 500 produk di perangkat (blok E) |
| **M10** Lisensi offline | ✅ selesai | alur aktivasi pada APK bertanda tangan rilis (blok B) — **butuh keystore** |
| **M11** Rilis v1.1.0 | ✅ dirilis (tag `v1.1.0`) | — |
| **M12** Pelanggan & poin (skema 1 → 2) | ✅ selesai | tap alur kasir & performa pencarian (blok H) |
| **M13** Multi-user PIN (skema 2 → 3) | ✅ selesai | rasa keypad, kunci otomatis, ganti kasir (blok H) |
| **M14** Grafik penjualan | ✅ selesai | keterbacaan HP kecil & tablet (blok H) |
| **M15** Polish & rilis v1.2.0 | ✅ selesai (kode & uji) | satu sesi uji fisik (§7) + keystore rilis (§8) + tag oleh orkestrator |

**Cakupan PRD v1.1 tuntas seluruhnya:** enam fitur produk (mode gelap,
printer, impor, pelanggan & poin, multi-user, grafik) + satu fitur komersial
(lisensi offline), dua tier, tidak ada satu pun item di luar
[prd-v1.1.md](prd-v1.1.md) yang dikerjakan. `schemaVersion` naik dua kali
(1 → 2 → 3) dengan rantai yang kini terbukti aman ujung ke ujung, dan
kompatibilitas backup dijaga dua arah oleh AC-10.2 yang sudah beredar lebih
dulu di v1.1.0 — persis urutan yang direncanakan sejak awal plan.

Angka sepanjang plan v1.1: **608 → 831 test** (M11 → M15), `flutter analyze`
tidak pernah berhenti di 0 issue, dan **0 dependency baru** sejak M11.

Yang tersisa sebelum v1.2.0 sampai ke tangan pembeli tinggal tiga hal yang
memang bukan milik agent: **keystore rilis**, **satu sesi uji fisik**, dan
**tag `v1.2.0`**.

---

## 11. Berkas yang Disentuh

**Kode (produksi)**

| Berkas | Perubahan |
|---|---|
| `lib/domain/repositories/repository_exceptions.dart` | penanda `DomainException` + 28 exception memakainya; `MigrasiDatabaseGagalException` baru |
| `lib/domain/repositories/import_exceptions.dart` | `ImporProdukException implements DomainException` |
| `lib/core/utils/error_message.dart` | daftar tipe manual → satu pemeriksaan penanda |
| `lib/data/db/app_database.dart` | `onUpgrade` membungkus kegagalan jadi pesan Indonesia (AC-10.5) |
| `lib/features/reports/widgets/sales_charts.dart` | komposisi pembayaran: judul selalu ada + loading/error/`EmptyState` |
| `lib/features/auth/screens/forgot_pin_screen.dart` | `e.toString()` → `AppErrorMessage.from(e)` |
| `lib/features/auth/screens/login_screen.dart` | judul error spesifik + pesan asli tidak dibuang |
| `lib/features/auth/screens/users_screen.dart` | judul error spesifik |
| `lib/features/auth/widgets/active_user_chip.dart` | 44dp → 48dp; inisial 10px → 11px |
| `lib/features/settings/widgets/points_section.dart` | tinggi tombol 48 → 52 |
| `lib/features/customers/**` (3 berkas) | elipsis `...` → `…` |
| `pubspec.yaml` | `version: 1.2.0+3` |

**Test**

| Berkas | Perubahan |
|---|---|
| `test/data/db/migration_chain_v1_to_v3_test.dart` | **baru** (13) |
| `test/features/regresi_perilaku_v1_test.dart` | **baru** (4) |
| `test/features/settings/backup_reminder_test.dart` | **baru** (5) |
| `test/features/dark_mode_screens_test.dart` | +5 layar baru M12/M13 |
| `test/core/utils/error_message_test.dart` | +3 (exception M12/M13 + gerbang penanda) |
| `test/features/reports/sales_charts_ui_test.dart` | +1 assertion |
| `test/fixtures/v1_database_fixture.dart` | `withGlobalPin` opsional |
| `test/features/pos/pos_checkout_flow_test.dart` | literal hint mengikuti perbaikan elipsis |

**Dokumen**

| Berkas | Perubahan |
|---|---|
| `docs/plan-v1.1.md` | checklist M15 dicentang + Catatan Keputusan K-10.1 s.d. K-10.4 |
| `docs/laporan-m15.md` | laporan ini |

---

## 12. Cara Menjalankan

```bash
flutter analyze
flutter test
flutter test test/data/db/migration_chain_v1_to_v3_test.dart   # rantai migrasi
flutter test test/features/regresi_perilaku_v1_test.dart       # fitur mati = v1.0
flutter build apk --release --split-per-abi                    # distribusi per-ABI
flutter build appbundle --release                              # distribusi Play
```

Distribusi tetap **per-ABI atau App Bundle** (keputusan M10): APK gabungan
memuat tiga ABI sekaligus (±86 MB) sehingga melewati batas 40 MB, sedangkan
per-ABI berada jauh di bawahnya.
