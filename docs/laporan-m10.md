# Laporan Milestone 10 — Sistem Lisensi Offline (Aktivasi Wajib)

**Tanggal:** 12 Agustus 2026
**Acuan:** [prd-v1.1.md §6](prd-v1.1.md) · [plan-v1.1.md](plan-v1.1.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md) ·
[laporan-m7.md](laporan-m7.md)

---

## 1. Ringkasan

Lima fitur sebelumnya menjawab kebutuhan **pengguna**. Milestone ini
menjawab kebutuhan **produk**: aplikasi ini akan dijual, dan tanpa
gerbang aktivasi satu APK yang beredar di grup WhatsApp langsung menjadi
seratus pemakai tanpa satu rupiah pun kembali.

Yang dibangun adalah gerbang penjualan **yang tidak melanggar janji
intinya**: perangkat kasir tetap tidak pernah menyentuh jaringan, bahkan
saat aktivasi. Kode ditukar lewat **manusia** (WhatsApp dari HP mana pun),
bukan lewat jaringan aplikasi. Tidak ada server, tidak ada akun, tidak ada
telemetri.

Empat hal yang menghabiskan sebagian besar usaha — keempatnya kelas cacat
yang baru ketahuan setelah pembeli sudah membayar dan marah:

1. **Salah ketik vs kode palsu.** Tanda tangan Ed25519 hanya bisa menjawab
   "sah/tidak sah". CRC-16 ditambahkan **khusus** supaya aplikasi bisa
   berkata *"Kode salah ketik atau belum lengkap"* alih-alih menuduh
   pembeli yang sudah membayar memakai kode bajakan (K-6.7). Diuji pada
   **seluruh 120 posisi karakter**.
2. **Kode 120 karakter.** Tidak dipendekkan dengan mengorbankan keamanan
   (K-6.3). Dilawan dengan UX: **Pindai QR → Tempel → Ketik**, dengan
   pengetikan sebagai jalan terakhir, alfabet tanpa karakter kembar,
   normalisasi saat diketik, dan 24 segmen progres kelompok.
3. **Mundur-jam.** Jam perangkat tidak tepercaya, tapi menguncinya juga
   salah. Solusinya jam **monoton** dari tiga saksi — termasuk
   `MAX(sales.created_at)` yang **ikut terbawa restore backup** — dan
   aturan tegas: jam kacau **tidak pernah** jadi alasan mengunci selama
   masa berlaku belum lewat (K-6.8).
4. **Tidak menyandera data.** Lisensi tahunan yang habis hanya mengunci
   layar Kasir; Riwayat, Laporan, Export, Backup, dan Pengaturan tetap
   terbuka dengan navigasi bawah yang tetap berfungsi. Layar trial
   berakhir tetap menyediakan **"Cadangkan Data"** (K-6.11).

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **592/592 lulus**, termasuk **89 test baru M10**.
  Tidak ada satu pun ekspektasi test M0–M9 yang diubah.
- `flutter build apk --release --split-per-abi` → **sukses**;
  arm64-v8a **30,8 MB**, armeabi-v7a **26,9 MB** (AC-6.22 < 40 MB).
- **Tidak ada perubahan skema database.** `schemaVersion` tetap **1**;
  **nol** nilai lisensi masuk database (K-6.1).
- Dependency baru: `cryptography ^2.9.0` (murni Dart) di `dependencies`;
  `qr ^4.0.0` + `image ^4.3.0` di `dev_dependencies` (hanya untuk tool
  penjual, tidak ikut APK).

---

## 2. Apa yang Dibangun

### 2.1 `lib/core/license/` — inti murni Dart

Sembilan berkas, **tanpa satu pun impor `package:flutter/*`**. Batasan itu
bukan estetika: `tool/license_generator.dart` mengimpor berkas yang sama
persis, sehingga penerbit dan verifikator **tidak mungkin** menafsirkan
format secara berbeda (K-6.12). "Lisensi sah ditolak aplikasi" adalah
kerusakan terparah dari fitur ini, dan satu-satunya cara menutupnya
adalah tidak pernah punya dua implementasi.

| Berkas | Isi |
|---|---|
| `crockford_base32.dart` | Alfabet 32 karakter tanpa `I`/`L`/`O`/`U`, encode/decode bit-packing, normalisasi pemaaf (huruf kecil, `I`/`l`→`1`, `O`→`0`, buang `-`/spasi), pengelompokan lima |
| `crc16.dart` | CRC-16/CCITT-FALSE — pembeda salah ketik vs kode palsu |
| `device_code.dart` | `SHA-256("kasirwarung.device.v1\|" + SSAID)` → 45 bit → 9 karakter + 1 karakter cek; format `KW-XXXXX-XXXXX`; deteksi SSAID cacat; petunjuk perangkat 16 bit |
| `license_payload.dart` | Muatan 9 byte (versi, jenis, terbit, kedaluwarsa, tenggang, petunjuk) + aritmetika hari sejak 2020-01-01 UTC |
| `license_token.dart` | Rakit/bongkar token 75 byte → 120 karakter, pesan yang ditandatangani, awalan `KW1-` |
| `license_verifier.dart` | Verifikasi Ed25519 atas **daftar** kunci publik + empat jenis penolakan berpesan sendiri |
| `license_issuer.dart` | Sisi penandatangan (dipakai tool & vektor uji) |
| `license_status.dart` | Enam keadaan + jam monoton `waktuAcuan` |
| `license_keys.dart` | Daftar kunci **publik** tepercaya |

**Karakter cek kode perangkat** memakai bobot posisi ganjil naik dua-dua
(1, 3, 5, …, 19) modulo 32. Konsekuensinya: **setiap** salah ketik satu
karakter pasti tertangkap, dan tertukarnya dua karakter bersebelahan
tertangkap kecuali bila keduanya kebetulan berselisih tepat 16 pada
alfabet — batas matematis skema linier modulo 32, ditulis apa adanya di
kode dan diukur di test (< 12% dari seluruh pertukaran bersebelahan).
Sisa risikonya ditutup perintah `--verifikasi` di sisi penjual.

### 2.2 Kode perangkat — MethodChannel sendiri

`MainActivity.kt` (yang sudah ada) bertambah ±20 baris: satu
`MethodChannel("kasirwarung/device")` dengan metode `ssaid` yang membaca
`Settings.Secure.ANDROID_ID`. **Nol dependency platform baru** — alasan
yang sama persis dengan K-9.1, dan sekaligus menghindari seluruh kelas
kegagalan `namespace`/AGP yang pernah menghentikan M0 & M6.

Sisi Dart (`data/services/device_id_service.dart`) tidak pernah
menampilkan atau mengirim SSAID mentah — ia langsung di-hash. Bila SSAID
tidak terbaca atau bernilai cacat yang terkenal (`9774d56d682e549c`, nol
semua), sebuah pengenal acak dibangkitkan **sekali** dan disimpan di
`shared_preferences`, dengan konsekuensinya dinyatakan terus terang di
kartu kode perangkat.

### 2.3 Penyimpanan & keadaan

Seluruh status lisensi hidup di `shared_preferences`
(`features/license/providers/license_store.dart`), **tidak pernah** di
tabel `settings`/database (K-6.1). Alasan pertama yang menentukan: tabel
`settings` ikut terbawa `backup → restore`, jadi satu file backup yang
beredar akan membawa serta lisensi berbayarnya.

Jenis, tanggal terbit, kedaluwarsa, dan masa tenggang **sengaja tidak
disimpan terpisah** — semuanya diturunkan ulang dengan memverifikasi
token di setiap *cold start*. Tidak ada dua sumber kebenaran yang bisa
melenceng.

Saksi `license_last_seen_at` dijaga **hanya boleh maju**; menulis nilai
yang lebih kecil sama saja memberi hadiah kepada jam yang dimundurkan.

### 2.4 Gerbang di lapisan router

`appRouterProvider` (menggantikan singleton `appRouter`) memasang
`redirect` + `refreshListenable` di **luar** `StatefulShellRoute` (K-6.9).
Fungsi keputusannya, `licenseRedirect(state, location)`, adalah fungsi
murni yang bisa diuji tanpa merender apa pun:

| Keadaan | Perilaku rute |
|---|---|
| `belumAktif` | seluruh rute → `/aktivasi` |
| `kedaluwarsaTrial` | seluruh rute → `/lisensi-berakhir` |
| `kedaluwarsaTahunan` | **tidak ada rute yang dikunci** — hanya isi layar Kasir yang diganti |
| `aktif` / `akanBerakhir` / `masaTenggang` | normal; layar gerbang tidak bisa "nyangkut" |

Beralih dari singleton ke provider punya bonus yang tidak direncanakan:
lokasi navigasi tidak lagi bocor antar `testWidgets` dalam satu proses —
persis masalah yang dulu memaksa `pin_gate_active_test.dart` dan
`pin_gate_inactive_test.dart` dipisah ke dua berkas.

Evaluasi lisensi berjalan **sebelum `runApp()`** (pola sama dengan tema,
AC-5.5) sehingga frame pertama sudah benar, lalu diulang setelah frame
pertama (saat itu database sudah terbuka, saksi `MAX(sales.created_at)`
ikut dihitung) dan setiap `AppLifecycleState.resumed`.

### 2.5 UI

Semuanya memakai `context.palette`; gerbang `no_hardcoded_colors_test.dart`
tetap hijau tanpa satu pun tambahan allowlist.

- **Layar Aktivasi** (`/aktivasi`) — dibaca dari atas ke bawah persis
  seperti urutan pekerjaan pembeli: *ini kode saya → saya kirim ke penjual
  → saya masukkan balasannya → saya tekan AKTIFKAN*. `AppIconBadge` kunci
  `xl`, judul `headlineMedium`, kartu kode perangkat `AppCard(elevated)`
  dengan angka tabular besar + tombol **Salin** & **Kirim**, tiga jalur
  masuk kode sebagai tombol seberat sama, kolom kode, baris status, lalu
  **satu** CTA `buttonHeightLarge` 60. Konten dibatasi `maxContentWidth`.
- **Masukan kode** (`license_code_field.dart`) — normalisasi saat diketik,
  pemisah kelompok lima otomatis, dan 24 segmen progres yang mengubah
  "kode ini panjang sekali" menjadi "tinggal sedikit". Memakai keyboard
  sistem (`textCapitalization: characters`, `autocorrect: false`,
  `enableSuggestions: false`); keypad khusus 32 tombol ditolak karena akan
  memaksa target sentuh di bawah 48dp.
- **Umpan balik verifikasi** mengikuti `pin_entry_screen.dart`: tombol
  tidak diganti spinner (bikin layar melompat), hanya dinonaktifkan
  sementara baris status berubah "Memeriksa kode…". Kode ditolak →
  `AppPill(tone: danger)` berlabel pendek + kalimat spesifik +
  `HapticFeedback.heavyImpact`.
- **Layar "Masa coba berakhir"** (`/lisensi-berakhir`) — nada menenangkan,
  bukan menghukum: *"Semua data Anda masih tersimpan aman dan akan
  langsung kembali setelah aplikasi diaktifkan."* CTA "Masukkan Kode
  Aktivasi", tombol tersier **"Cadangkan Data"** yang melewati gerbang PIN
  bila PIN aktif.
- **Layar Kasir terkunci** — `EmptyState` **di dalam shell**, navigasi
  bawah tetap ada dan tetap berfungsi. Ini pesan visual yang penting:
  yang terkunci adalah jualannya, bukan datanya.
- **Banner** di layar Kasir, di atas daftar produk sehingga **tidak pernah**
  menutupi bar keranjang atau tombol "Bayar": `warning` "berakhir N hari
  lagi" (bisa ditutup untuk sesi berjalan), `danger` masa tenggang
  (**tidak** bisa ditutup), `info` jam mundur.
- **Kartu "Lisensi" di Pengaturan** — paling bawah, di bawah Keamanan,
  karena ini bukan pengaturan harian. Menjawab empat pertanyaan yang
  benar-benar ditanyakan pemilik warung: *masih aktif? jenisnya apa? habis
  kapan? kalau ganti HP bagaimana?*

### 2.6 Tool penjual — `tool/license_generator.dart`

CLI Dart di dalam repo, dijalankan di laptop penjual, memakai jalur kode
yang sama dengan aplikasi. Empat perintah: `--buat-kunci`, penerbitan,
`--verifikasi`, `--daftar`. Rincian pemakaiannya di §6.

Tiga penjaga dipasang di jalur penerbitan, berurutan:

1. **Karakter cek kode perangkat diperiksa lebih dulu** — salah ketik
   ketahuan sebelum kode diterbitkan, bukan setelah bolak-balik WhatsApp.
2. **Peringatan trial berantai** — `lisensi-terbit.csv` dibaca, dan bila
   perangkat itu sudah pernah menerima kode (apalagi trial), penjual
   diperingatkan sebelum menerbitkan yang kedua. Tanpa server, ini
   satu-satunya penjaga yang ada, dan itu diterima secara sadar.
3. **Verifikasi ulang lewat jalur aplikasi** sebelum kode dicetak ke
   layar. Kode yang gagal diverifikasi ulang tidak pernah sampai ke
   pembeli.

---

## 3. Keputusan Teknis

### 3.1 Deteksi mode build memakai `bool.fromEnvironment`, bukan `kDebugMode`

Rencana M10 menulis "kunci uji hanya masuk daftar saat `kDebugMode`".
Pelaksanaannya memakai `const bool.fromEnvironment('dart.vm.product')`
karena `kDebugMode` datang dari `package:flutter/foundation.dart`, dan
`license_keys.dart` **wajib** tetap murni Dart agar bisa diimpor
`tool/license_generator.dart` (K-6.12). Semantiknya identik, sifat
`const`-nya sama, dan pembuangannya oleh compiler AOT sudah diverifikasi
empiris di APK release (§4.4).

### 3.2 Keadaan `gerbangDimatikan` sebagai default provider, bukan `if (kDebugMode)`

`licenseBootstrapProvider` punya nilai default
`LicenseStatus.gerbangDimatikan()` supaya seluruh widget test M0–M9 — yang
tidak tahu-menahu soal lisensi — tetap bisa membangun `KasirApp` tanpa
diubah satu baris pun. Kenyamanan itu punya harga: kalau `main()` suatu
hari berhenti meng-override, aplikasi rilis akan terbuka lebar dan tidak
ada satu pun test perilaku yang gagal karenanya.

Karena itu bendera ini sengaja hidup **di dalam keadaannya sendiri**
(bukan sebagai cabang `if (kDebugMode)` yang tersebar di jalur gerbang),
dan `license_bootstrap_wiring_test.dart` menjaga empat hal di tingkat
sumber: `main()` memanggil `evaluateLicense` **sebelum** `runApp()`,
selalu meng-override ketiga provider lisensi, blok `overrides` tidak
dibungkus kondisi apa pun, dan kata `gerbangDimatikan` tidak pernah muncul
di `main.dart`.

### 3.3 Petunjuk perangkat diperiksa sebelum tanda tangan

Urutan pemeriksaan verifier disengaja: bentuk → CRC → versi → jenis →
petunjuk perangkat → tanda tangan. Petunjuk 16 bit **bukan pengaman**
(pengamannya adalah kode perangkat yang ikut ditandatangani); ia ada
semata-mata supaya "kode ini diterbitkan untuk perangkat lain" bisa
dibedakan dari "kode tidak sah". Yang paling sering terjadi (salah ketik)
diperiksa paling awal.

### 3.4 Gerbang penjualan di build layar Kasir, bukan di `SaveSaleUsecase`

Konsekuensi langsung dari K-6.10/AC-6.18. Sheet pembayaran hidup di route
**di atas** layar Kasir, sehingga transaksi yang sudah berjalan selesai
apa adanya dan kunci baru berlaku pada frame berikutnya. Menaruh
pemeriksaan di usecase akan membuat aplikasi menolak menyimpan saat uang
pembeli sudah di tangan kasir — kerusakan yang tidak sebanding dengan
satu hari lisensi. Diuji langsung di `license_mid_transaction_test.dart`.

### 3.5 `/aktivasi` dialihkan juga saat trial habis

Rencana awal membiarkan `/aktivasi` terbuka pada keadaan
`kedaluwarsaTrial`. Ternyata itu membuat gerbang bisa "nyangkut": layar
aktivasi yang tampil karena `belumAktif` akan bertahan begitu keadaan
berubah menjadi `kedaluwarsaTrial`, dan pengguna kehilangan tombol
"Cadangkan Data". Sekarang `/aktivasi` ikut dialihkan ke
`/lisensi-berakhir`, dan layar aktivasi dibuka dari sana sebagai halaman
**bertumpuk** (`ActivationScreen.show`) — pembeli selalu punya jalan
kembali. Pola yang sama dipakai tombol "Masukkan Kode Baru" di Pengaturan
dan "Perpanjang" di banner.

### 3.6 Vektor uji dibekukan, bukan dibangkitkan ulang

`test/fixtures/license_vectors.dart` memuat sembilan kode sebagai
konstanta. Kalau vektornya dibangkitkan ulang tiap test berjalan, maka
perubahan tak sengaja pada format muatan, urutan byte, tabel CRC, atau
alfabet Base32 akan tetap hijau — padahal itu persis perubahan yang
merusak kompatibilitas dengan kode yang **sudah** ada di tangan pembeli.

---

## 4. Hasil Verifikasi

### 4.1 `flutter analyze`

```
No issues found!
```

### 4.2 `flutter test`

**592/592 lulus** (baseline 503 + 89 test baru M10), tanpa mengubah satu
pun ekspektasi test M0–M9.

| Berkas test baru | Jumlah | Menutup |
|---|---|---|
| `test/core/license/device_code_test.dart` | 13 | Alfabet Crockford, kode perangkat, karakter cek (semua salah ketik satu karakter & pertukaran bersebelahan), SSAID cacat |
| `test/core/license/license_verifier_test.dart` | 16 | Vektor uji tetap (AC-6.8), salah ketik **seluruh 120 posisi** (AC-6.6), pemalsuan muatan & tanda tangan dengan CRC dihitung ulang (AC-6.7), perangkat lain (AC-6.5), versi terlalu baru (AC-6.21), normalisasi masukan (AC-6.9) |
| `test/core/license/license_status_test.dart` | 17 | Trial hari 1/2/3/4 (AC-6.10), lifetime, tenggang tahunan hari 1/7/8 (AC-6.13, AC-6.14), jam monoton & mundur-jam (AC-6.16) |
| `test/core/license/license_key_governance_test.dart` | 9 | Daftar kunci siap rotasi (AC-6.20), kunci uji tidak masuk build release, tidak ada kunci privat/CSV di repo, `.gitignore` (AC-6.19) |
| `test/features/license/license_router_gate_test.dart` | 9 | Gerbang router untuk seluruh rute termasuk navigasi langsung (AC-6.1), layar trial berakhir (AC-6.15), Kasir terkunci sementara Riwayat tetap terbuka (AC-6.14) |
| `test/features/license/license_activation_flow_test.dart` | 8 | Kode perangkat konsisten (AC-6.2), aktivasi sukses (AC-6.4), pesan spesifik per jenis kesalahan, data utuh setelah trial → lifetime (AC-6.12), kode bukan sekali pakai (K-6.6), trial tidak bisa direset (AC-6.11) |
| `test/features/license/license_storage_test.dart` | 9 | Kunci penyimpanan, saksi hanya maju, `evaluateLicense`, backup tidak memuat jejak lisensi (AC-6.17) |
| `test/features/license/license_mid_transaction_test.dart` | 1 | Lisensi berakhir saat keranjang berisi → transaksi tetap tersimpan (AC-6.18) |
| `test/features/license/license_bootstrap_wiring_test.dart` | 7 | Pemasangan gerbang di `main()` & router tidak bisa hilang diam-diam |

Seluruhnya berjalan **tanpa perangkat, tanpa jaringan, dan tanpa berkas
apa pun di luar repo**.

### 4.3 `flutter build apk --release --split-per-abi`

```
✓ Built app-armeabi-v7a-release.apk (26.9MB)
✓ Built app-arm64-v8a-release.apk  (30.8MB)
✓ Built app-x86_64-release.apk     (33.3MB)
```

Dua ABI yang benar-benar dipakai HP Android sekarang berada di bawah
batas 40 MB (AC-6.22). APK gabungan (tanpa `--split-per-abi`) 83,9 MB
karena memuat ketiga ABI sekaligus — distribusi ke pembeli **wajib**
memakai APK per-ABI atau App Bundle.

### 4.4 Kunci uji tidak ada di build release (AC-6.19)

Diperiksa langsung pada berkas APK, bukan disimpulkan dari kode:

```
$ grep -a "BvM36lmeMEfo0mWp8tNTCJeq0ds02eyT18BcLyww0k0=" app-arm64-v8a-release.apk
(tidak ada)
$ grep -a "rsBd/CBPjDklHlV7AKK0NTlGi/d4uZ6C9m2L2+6feS4=" app-arm64-v8a-release.apk
(ada)
```

Kunci **uji** dibuang compiler AOT; kunci **publik produksi** ada. Persis
yang diinginkan.

### 4.5 Tool penjual — demo penerbitan nyata

```
$ dart run tool/license_generator.dart --device KW-TAAEV-9ASMB --jenis coba \
    --nama "Warung Bu Ani (demo)" --catatan "demo M10"

✓ Kode aktivasi diterbitkan.
  Perangkat    : KW-TAAEV-9ASMB
  Jenis        : Coba
  Terbit       : 2026-08-12
  Kedaluwarsa  : 2026-08-15
  Masa tenggang: 0 hari
  QR           : ~/.kasir-warung/terbit/lisensi-KW-TAAEV-9ASMB.png
  Catatan      : lisensi-terbit.csv diperbarui

$ dart run tool/license_generator.dart --verifikasi "KW1-040GJ-…" --device KW-TAAEV-9ASMB
✓ Kode SAH untuk KW-TAAEV-9ASMB.

$ dart run tool/license_generator.dart --verifikasi "KW1-040GJ-…" --device KW-X3G2C-4BNT0
✗ Kode DITOLAK (perangkatLain).
  Pesan yang dilihat pembeli:
  "Kode ini diterbitkan untuk perangkat lain. …"
```

---

## 5. Tata Kelola Kunci Penerbit (WAJIB DIBACA)

Kunci privat penerbit adalah **aset paling berharga proyek ini di luar
kode sumbernya**. Bagian ini adalah prosedur, bukan penjelasan.

### 5.1 Lokasi kunci produksi

```
~/.kasir-warung/license_ed25519.key        ← KUNCI PRIVAT (32 byte, base64)
~/.kasir-warung/lisensi-terbit.csv         ← buku penerbitan (nama & WA pembeli)
~/.kasir-warung/terbit/lisensi-KW-*.png    ← QR yang sudah diterbitkan
```

Kunci publik pasangannya sudah tertanam di aplikasi:

```
lib/core/license/license_keys.dart → kProductionPublicKeys
  'rsBd/CBPjDklHlV7AKK0NTlGi/d4uZ6C9m2L2+6feS4='   (dibuat 2026-08-12)
```

> **Catatan lokasi.** Instruksi milestone menyebut `~/.kasir_warung_lisensi/`
> sementara [prd-v1.1.md §6.3.B](prd-v1.1.md) menyebut `~/.kasir-warung/`.
> Yang dipakai adalah **`~/.kasir-warung/`** (PRD, sumber kebenaran).
> Keduanya bermaksud sama: di luar repo, di direktori home penjual. Tool
> menerima `--dir <path>` bila lokasinya perlu dipindah.

### 5.2 Instruksi backup — lakukan SEKARANG, bukan nanti

1. Salin `~/.kasir-warung/license_ed25519.key` ke **minimal dua tempat
   luring**, misalnya:
   - USB terenkripsi yang disimpan di rumah (bukan di tas laptop), dan
   - catatan tercetak / pengelola kata sandi (isinya hanya 44 karakter
     base64 — muat di satu baris).
2. **Bukan** ke Google Drive akun yang sama dengan laptop ini, **bukan**
   ke repositori privat, **bukan** lewat chat/email ke diri sendiri.
3. Cadangkan juga `lisensi-terbit.csv` secara berkala: ia adalah
   satu-satunya bukti pembelian pelanggan, dan satu-satunya penjaga
   terhadap trial berantai.

### 5.3 Kalau kunci HILANG

Kode yang sudah beredar **tetap sah selamanya** — aplikasi hanya butuh
kunci publik. Yang hilang adalah kemampuan **menerbitkan kode baru**.

Pemulihan:
1. `dart run tool/license_generator.dart --buat-kunci --dir <lokasi baru>`
2. **Tambahkan** kunci publik baru ke `kProductionPublicKeys` — jangan
   buang yang lama.
3. Rilis pembaruan aplikasi. Pelanggan lama tidak terganggu; pelanggan
   baru harus memakai versi ≥ rilis itu.

### 5.4 Kalau kunci BOCOR

Siapa pun bisa menerbitkan kode untuk perangkat mana pun — masih terikat
per perangkat (bukan "satu kode untuk semua"), tapi cukup untuk membuat
keygen.

Tanggapan:
1. Terbitkan kunci baru.
2. **KELUARKAN kunci lama** dari `kProductionPublicKeys`.
3. Rilis pembaruan aplikasi secepatnya.

Konsekuensinya diakui terus terang: **seluruh pemasangan lama yang tidak
pernah diperbarui tetap bisa dibobol.** Karena itu aturan "tidak pernah
di-commit" bukan formalitas.

### 5.5 Penjaga otomatis

- `.gitignore` menutup `*.key`, `*.pem`, `lisensi-terbit.csv`,
  `lisensi-*.png`.
- `license_key_governance_test.dart` gagal bila ada nilai 32-byte base64
  tak dikenal di dalam repo, bila ada berkas `.key`/`.pem`/CSV penerbitan
  di dalam repo, bila `.gitignore` kehilangan polanya, atau bila benih
  kunci uji bocor keluar dari `test/fixtures/`.
- Kunci **uji** (`test/fixtures/license_test_keys.dart`) sengaja
  di-commit — ia bukan kunci penerbit, tidak pernah menandatangani lisensi
  yang beredar, dan tidak pernah masuk daftar tepercaya build release.

---

## 6. Panduan Alur Penjual (saat ada pembeli)

### 6.0 Sekali seumur produk

```bash
dart run tool/license_generator.dart --buat-kunci
```

Tempel kunci publik yang dicetak ke `kProductionPublicKeys`, lalu
cadangkan kunci privatnya sesuai §5.2. **Sudah dilakukan pada
2026-08-12** — jangan diulang kecuali sedang merotasi kunci.

### 6.1 Pembeli menghubungi (biasanya lewat WhatsApp)

Pembeli mengirim pesan yang dibuat aplikasi sendiri lewat tombol
**"Kirim"** di layar Aktivasi:

> Halo, saya mau aktivasi Kasir Warung. Kode perangkat saya:
> KW-4T7QP-9M2XK

### 6.2 Terbitkan kodenya (satu perintah)

```bash
dart run tool/license_generator.dart \
  --device KW-4T7QP-9M2XK \
  --jenis tahunan \
  --nama "Warung Bu Ani" \
  --catatan "WA 0812xxxx, transfer 12 Agu"
```

`--jenis` menerima `coba` (3 hari), `selamanya`, atau `tahunan`
(365 hari + tenggang 7). Bila perlu, `--hari N` dan `--tenggang N`
mengubah keduanya; nilainya ikut ditandatangani sehingga kelonggaran
khusus tidak butuh rilis aplikasi baru (K-6.13).

Yang perlu diperhatikan di keluarannya:

- Tool **menolak** kode perangkat yang gagal karakter cek → minta pembeli
  kirim ulang, jangan menebak.
- Tool **memperingatkan** bila perangkat itu sudah pernah dapat kode,
  terutama trial. Itu keputusanmu, tapi harus keputusan yang disadari.

### 6.3 Kirim ke pembeli

Kirim **dua-duanya**:
1. Blok teks 120 karakter yang dicetak di terminal (bisa langsung
   di-*copy paste* ke WhatsApp), dan
2. Berkas QR `~/.kasir-warung/terbit/lisensi-KW-4T7QP-9M2XK.png`.

Pembeli memilih sendiri jalur termudah: **Pindai QR** (kode sampai di HP
lain), **Tempel** (WhatsApp ada di HP kasir itu sendiri), atau **Ketik**
(jalan terakhir yang selalu bekerja).

### 6.4 Kalau pembeli melapor "kode saya ditolak"

```bash
dart run tool/license_generator.dart --verifikasi "<kode yang dia tempel>" \
  --device KW-4T7QP-9M2XK
```

Perintah ini menjalankan **jalur verifikasi yang sama persis** dengan
aplikasi dan mencetak kalimat yang dilihat pembeli. Terjemahannya:

| Hasil | Artinya | Jawab pembeli |
|---|---|---|
| `salahKetik` | kode belum lengkap / ada karakter tertukar | "Coba tempel ulang, atau pindai QR-nya" |
| `perangkatLain` | kode diterbitkan untuk HP lain | "Kirim kode perangkat HP yang dipakai sekarang" |
| `tidakSah` | tanda tangan tidak cocok kunci mana pun | kodenya bukan dari kamu — periksa dari mana ia dapat |
| `versiTerlaluBaru` | aplikasinya lebih tua dari format kode | "Perbarui aplikasinya dulu" |

### 6.5 Melihat catatan penjualan

```bash
dart run tool/license_generator.dart --daftar
dart run tool/license_generator.dart --daftar --jenis coba
```

### 6.6 Pembeli ganti HP

Kode perangkat berubah (SSAID baru), jadi ia butuh kode baru. Aplikasi
**tidak punya** transfer otomatis (K-6.15) — memberi atau tidak adalah
kebijakan komersialmu, dan `--daftar` memberi bukti pembelian
sebelumnya dalam hitungan detik.

---

## 7. Sisa Pekerjaan Manual (Device Fisik)

Tiga item checklist M10 sengaja **tidak dicentang** karena butuh perangkat
Android fisik + APK release yang ditandatangani kunci rilis sebenarnya
(kode perangkat APK debug berbeda dengan APK release). Semuanya sudah
punya padanan otomatis yang berjalan tanpa perangkat; yang tersisa murni
verifikasi perangkat keras:

1. **Aktivasi lewat tiga jalur & pengukuran waktunya** — pindai QR dengan
   kamera nyata, tempel dari WhatsApp, ketik manual; target PRD §11.1
   ≤ 30 detik (QR/tempel) dan ≤ 2 menit (ketik).
2. **SSAID bertahan melewati uninstall–reinstall** (AC-6.3, AC-6.11) —
   uninstall → install APK release bertanda tangan sama → kode perangkat
   harus **sama**, dan kode trial lama harus **tetap** kedaluwarsa.
   Ini satu-satunya AC yang tidak bisa disimulasikan sama sekali.
3. **Mundur-jam & performa di HP** — mundurkan jam 1 tahun (banner tampil,
   sisa masa berlaku tidak bertambah), ukur cold start < 3 detik (AC-6.22).

Dijadwalkan ikut sesi uji-terima M11, yang memang sudah mensyaratkan
penerbitan kode untuk ≥ 2 perangkat nyata.

---

## 8. Dampak untuk Milestone Berikutnya

- **M11 (rilis v1.1.0)** — gerbang penjualan sekarang ada, jadi butir
  "GERBANG PENJUALAN — M10 wajib tuntas" tinggal verifikasi ulang di APK
  release bertanda tangan rilis. Distribusi **wajib** per-ABI/App Bundle
  (§4.3). Tambahkan juga pemeriksaan `grep` kunci uji pada APK final
  (§4.4) ke checklist rilis.
- **M13 (multi-user PIN)** — urutan gerbang **lisensi → masuk → shell**
  sudah disiapkan: `licenseRedirect` adalah fungsi murni yang tinggal
  dirangkai dengan gerbang login berikutnya di `redirect` yang sama.
- **Router bukan singleton lagi.** Test baru tidak perlu lagi dipisah ke
  berkas berbeda hanya untuk menghindari kebocoran lokasi navigasi.
- **Jalur evolusi backend** (PRD §6.8) tetap terbuka tanpa perubahan
  format: byte `versi` di muatan dan **daftar** kunci publik adalah dua
  kait yang sudah terpasang.

---

## 9. Cara Menjalankan

```bash
# Verifikasi lengkap
flutter analyze
flutter test
flutter build apk --release --split-per-abi

# Tool penjual
dart run tool/license_generator.dart --bantuan
```

**Selama pengembangan**, aplikasi berjalan tanpa gerbang di widget test
(default `licenseBootstrapProvider`), tapi **tidak** di `flutter run` —
`main()` selalu mengevaluasi lisensi sungguhan. Untuk membuka APK debug
di perangkat, terbitkan kode untuk kode perangkat yang tampil di layar
Aktivasi; kode perangkat APK debug memang berbeda dengan APK release
karena kunci penanda tangannya berbeda.
