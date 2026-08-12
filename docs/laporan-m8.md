# Laporan Milestone 8 — Cetak Struk ke Printer Thermal Bluetooth 58mm

**Tanggal:** 12 Agustus 2026
**Acuan:** [prd-v1.1.md §3](prd-v1.1.md) · [plan-v1.1.md](plan-v1.1.md) ·
[architecture.md](architecture.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md) ·
[laporan-m7.md](laporan-m7.md)

---

## 1. Ringkasan

Seluruh checklist Milestone 8 selesai kecuali satu item yang memang
menuntut printer fisik. Struk sekarang bisa keluar di kertas: printer
dipasang sekali dari Pengaturan, tombol **Cetak** ada di layar sukses
transaksi, dan **Cetak Ulang** ada di detail transaksi lama — lengkap
dengan penanda `** CETAK ULANG **` dan `** DIBATALKAN **`.

Yang menentukan bentuk pekerjaan ini bukan fitur cetaknya, melainkan satu
kalimat di PRD §3.3.B: **kegagalan printer tidak boleh pernah menyentuh
data penjualan**. Printer adalah satu-satunya bagian aplikasi ini yang
bergantung pada benda di luar HP — benda yang kehabisan kertas, kehabisan
baterai, dan dimatikan orang. Karena itu seluruh jalur cetak dirancang
sebagai lampiran yang bisa gagal diam-diam di belakang transaksi yang
sudah aman tersimpan, bukan sebagai langkah dalam alur penyimpanan.

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **502/502 lulus**, tanpa satu pun test M0–M7 diubah.
  57 di antaranya test baru M8 (43 unit builder + sanitasi, 6 raster,
  8 widget alur cetak).
- `flutter build apk --release` → **sukses** dengan dua dependency baru.
- Manifest release hasil merge: `BLUETOOTH_CONNECT`, `BLUETOOTH`,
  `BLUETOOTH_ADMIN`, `CAMERA`, `ACCESS_NETWORK_STATE`. **Tidak ada**
  `BLUETOOTH_SCAN`, **tidak ada** izin lokasi, **tidak ada** `INTERNET`
  (AC-3.11 hijau).
- Tidak ada perubahan skema database. `schemaVersion` tetap **1**,
  backup v1.0 ↔ v1.1 tetap kompatibel penuh (PRD §3.5).
- `AppColors.*` baru di `lib/features/` → **0**; gerbang
  `no_hardcoded_colors_test.dart` dari M7 tetap hijau.

---

## 2. Apa yang Dibangun

### 2.1 Dependency: commit terpisah yang divalidasi build lebih dulu

Sesuai perintah plan M8 poin 1, dua dependency ditambahkan dan
`flutter build apk --release` dijalankan **sebelum satu baris kode fitur
ditulis**:

```yaml
print_bluetooth_thermal: ^1.2.2   # transport Bluetooth Klasik (SPP)
esc_pos_utils_plus: ^2.0.4        # utilitas ESC/POS murni Dart
```

Resolusi bersih terhadap `excel ^4.0.6`, `file_picker ^12`, dan
`mobile_scanner ^7.4.0` (`image` ter-resolve ke 4.3.0, `xml` tetap
6.6.1). `android.builtInKotlin=false` **tidak disentuh** — baris itulah
yang membuat plugin berpola Gradle lama masih lolos hari ini.

**Catatan diagnostik yang perlu diingat orang berikutnya.** Percobaan
build pertama GAGAL dengan error Kotlin yang terlihat mengerikan:

```
e: .../share_plus-13.3.0/.../Share.kt:185:41
   Unresolved reference 'SharePlusPendingIntent'.
> Task :share_plus:compileReleaseKotlin FAILED
```

Ini **bukan** inkompatibilitas package printer, walau kebetulan muncul
tepat setelah dependency printer ditambahkan — dan bukan pula mode
kegagalan `namespace` yang pernah menghantam proyek ini di M0 & M6.
Simbol yang "hilang" itu berada di file tetangga dalam modul yang sama;
penyebabnya artefak **incremental-compile basi** di direktori `build/`.
Menghapus `build/share_plus` lalu membangun ulang langsung sukses, dan
seluruh build berikutnya (termasuk dengan seluruh kode fitur) juga
sukses. Aturannya: sebelum mencoret kandidat package karena kegagalan
Kotlin, `flutter clean` dulu — kandidat hanya dicoret kalau gagal pada
pohon build yang bersih.

### 2.2 Izin Android: minimal, dan yang berlebih dicabut

`android/app/src/main/AndroidManifest.xml` mendeklarasikan **hanya**
`BLUETOOTH_CONNECT` (+ `BLUETOOTH`/`BLUETOOTH_ADMIN` dengan
`maxSdkVersion="30"`).

Manifest bawaan `print_bluetooth_thermal` ternyata **ikut membawa
`BLUETOOTH_SCAN` dan `INTERNET`** walau jalur kode yang dipakai aplikasi
ini tidak pernah memindai maupun menyentuh jaringan. Keduanya dicabut
lewat `tools:node="remove"`:

| Izin | Dicabut di | Alasan |
|---|---|---|
| `BLUETOOTH_SCAN` | `src/main` | AC-3.11; memicu pertanyaan Play Store, tidak pernah dipakai |
| `INTERNET` | **`src/release`** | janji "100% offline" (prd.md §1); **sengaja hanya di release** — build debug tetap butuh INTERNET untuk hot reload |

Diverifikasi langsung pada manifest hasil merge build release, bukan
diasumsikan (§4.3).

### 2.3 `EscPosReceiptBuilder` — murni Dart, teruji sampai byte

`lib/data/services/printing/esc_pos_receipt_builder.dart` mengubah
`SaleResult` + `StoreProfile` + `PrinterSettings` menjadi `List<int>`.
**Tanpa satu pun import platform** (K-3.2): tidak menyentuh `dart:ui`,
`package:flutter`, maupun plugin Bluetooth. Konsekuensinya disengaja —
satu-satunya cara lain memverifikasi tata letak struk adalah membuang
gulungan kertas satu per satu sambil menebak.

API-nya dua lapis supaya bisa diuji dengan tepat:

- `buildLines(...)` → `List<EscPosLine>`: teks final tiap baris (sudah
  disanitasi, sudah diratakan) beserta gayanya. Diuji sebagai teks yang
  enak dibaca manusia.
- `build(...)` / `encodeLine(...)` → `List<int>`: byte ESC/POS. Diuji
  sebagai vektor uji byte-per-byte.

Aturan format yang diterapkan (PRD §3.3.D):

- 32 karakter untuk 58mm, 48 untuk 80mm (K-3.6).
- Nama produk > lebar kertas dibungkus **di batas kata**; kata tunggal
  yang memang lebih panjang dari satu baris dipenggal keras.
- Nominal rata kanan dengan **padding spasi**, bukan tab.
- Rupiah **tanpa prefiks "Rp"**; pemisah ribuan titik dari
  `CurrencyFormatter`.
- Qty pecahan pakai koma (`0,5`), bulat tanpa desimal (`2`).
- Bila label kiri terlalu panjang, **yang dipotong label**, tidak pernah
  nominalnya — itu angka uang.

Perintah ESC/POS dibatasi ke subset paling luas didukung klon murah:
`ESC @`, `ESC t 0` (CP437), `ESC a`, `ESC E`, `GS ! 0x01` (tinggi ganda
saja — lebar ganda akan memotong jumlah kolom jadi separuh dan merusak
perataan), `GS v 0` (logo). **Tanpa auto-cut, tanpa QR native, tanpa
laci kas** (K-3.8) — dan ada test yang memindai byte hasil untuk
memastikan ketiganya benar-benar tidak ada.

### 2.4 Sanitasi ASCII (K-3.7, AC-3.4)

`receipt_text_sanitizer.dart`, juga murni Dart tanpa satu pun import.
Aturannya sengaja sederhana dan bisa dibaca orang lain:

1. karakter berpadanan wajar dipetakan (`×`→`x`, `–`/`—`/`→`→`-`,
   `’`→`'`, `…`→`...`, U+00A0→spasi);
2. huruf latin beraksen diturunkan ke huruf dasar (`Café`→`Cafe`);
3. sisanya (emoji, aksara non-latin) diganti **spasi** — diganti, bukan
   dibuang, supaya panjang teks tidak berubah diam-diam dan menggeser
   kolom nominal yang sudah dihitung.

Testnya secara khusus mengejar jebakan yang disebut PRD: keluaran `intl`
locale `id_ID`. Hari ini `id_ID` kebetulan tidak menghasilkan spasi
tak-putus, jadi test itu saja akan lulus tanpa membuktikan apa pun —
karena itu ditambahkan kasus locale `fr` yang **memang** memakai U+00A0
sebagai pemisah ribuan, sebagai bukti bahwa sanitasinya benar-benar
menangkapnya dan bukan kebetulan lolos.

### 2.5 `ReceiptPrinter` + implementasi Bluetooth (K-3.1)

`receipt_printer.dart` mendefinisikan kontrak transport;
`bluetooth_receipt_printer.dart` adalah **satu-satunya berkas di seluruh
aplikasi** yang meng-import package Bluetooth. Yang dijaga di sana:

- **Mutex satu job** (`_busy`) — dua job tumpang tindih merusak stream
  SPP dan mengeluarkan struk ganda.
- **Timeout eksplisit**: koneksi 8 detik, tulis 10 detik. Tanpa itu,
  printer yang mati membuat kasir mengira aplikasi hang tepat saat
  antrian panjang (AC-3.6).
- **Koneksi selalu ditutup di `finally`**, termasuk saat gagal — soket
  SPP menggantung membuat percobaan berikutnya gagal dengan alasan yang
  salah, dan pengguna mengejar masalah yang tidak ada.
- Urutan pemeriksaan **izin dulu, radio kemudian**: kalau dibalik, HP
  Android 12+ yang izinnya belum diberikan akan dilaporkan "Bluetooth
  mati" — pesan yang mengarahkan ke tindakan yang salah.
- Tidak pernah melempar exception mentah; semuanya jadi
  `PrinterException` berbahasa Indonesia dengan `PrinterFailure` yang
  bisa dibedakan layar.

### 2.6 Pengaturan: kartu "Printer Struk" + dua sheet

Kartu baru di grup **PERANGKAT** (`printer_section.dart`), pola
`SettingsCard` yang sudah ada, status lewat `AppPill`
(Terpasang/Belum terpasang/Gagal terhubung).

Susunannya mengikuti urutan pertanyaan pemilik warung, bukan urutan tabel
di PRD: **printernya mana** → **keluar sendiri atau tidak** → **coba
dulu** → (jarang) **atur tampilan struknya**. Setelan rinci — lebar
kertas, salinan, logo, kalimat penutup, baris feed — sengaja
disembunyikan satu tap di balik "Atur Tampilan Struk"
(`receipt_format_sheet.dart`): itu setelan yang disentuh sekali seumur
hidup, dan menaruh tujuhnya sekaligus di depan mengubah kartu ini jadi
formulir yang menakutkan.

Sheet format memuat **pratinjau langsung** memakai `ReceiptWidget` yang
sudah ada. Widget itu memaksa dirinya bertema terang sejak M7 (K-5.3),
jadi pratinjaunya otomatis tetap di atas kertas putih walau aplikasi
sedang mode gelap — tanpa kode tambahan. Bukan kelalaian tema melainkan
penerapannya: kertas thermal tidak punya mode gelap.

Sheet perangkat (`printer_device_sheet.dart`) menampilkan printer
**bonded** saja, baris ≥ 56dp. Layar kosongnya bukan jalan buntu
melainkan petunjuk arah: panduan 3 langkah (nyalakan printer → pasangkan
lewat Pengaturan Bluetooth, PIN biasanya 1234/0000 → kembali ke sini) +
tombol pintasan ke Pengaturan Bluetooth Android (AC-3.16).

### 2.7 Cetak & cetak ulang

`PrintReceiptButton` (`features/pos/widgets/`) dipakai kedua layar dan
membawa statusnya **di dalam tombolnya sendiri**: `Menghubungkan… →
Mencetak… → Tercetak ✓` atau `Gagal — Coba Lagi` + kalimat sebabnya +
(bila relevan) pintasan ke Pengaturan Android. Statusnya sengaja tidak
dibuang ke SnackBar: kasir sedang menatap tombol yang baru ia tekan, dan
SnackBar menghilang sendiri sebelum sempat dibaca kalau tangan sedang
menghitung uang.

- **Layar sukses transaksi**: tombol `OutlinedButton` tinggi 52 di atas
  pasangan "Bagikan Teks"/"Bagikan Gambar". Ketiganya sekunder; CTA
  "Transaksi Baru" tetap satu-satunya tombol menonjol di layar itu.
  Cetak otomatis (default **mati**) berjalan di `addPostFrameCallback`
  supaya momen puncak tetap tampil seketika — kertas menyusul.
- **Detail transaksi**: "Cetak Ulang" berdiri sendiri **di atas** dua
  tombol bagikan di action bar. Inilah aksi yang dicari orang saat struk
  pertama hilang atau kertasnya macet; menaruhnya sebagai opsi ketiga
  berarti membuatnya dicari.

---

## 3. Keputusan Teknis

### 3.1 K-3.10 (baru) — byte ESC/POS ditulis sendiri, `Generator` dari `esc_pos_utils_plus` tidak dipakai di builder

`CapabilityProfile.load()` milik `esc_pos_utils_plus` membaca profil dari
asset lewat `rootBundle`, yaitu **dependency platform**. Memakainya di
`EscPosReceiptBuilder` akan melanggar K-3.2 secara harfiah dan membuat
builder tidak bisa diuji unit tanpa binding Flutter — padahal justru
pengujian penuh itulah satu-satunya alasan K-3.2 ada.

Karena itu builder memancarkan sendiri subset perintah yang ia butuhkan
(enam perintah, semuanya di §2.3). Ini bukan penulisan ulang library:
perintah yang dipakai memang cuma segelintir, justru karena PRD §3.7.2
melarang perintah eksotis. Imbalannya besar — vektor uji byte-per-byte
tanpa perangkat, dan tidak ada perilaku printer yang bersembunyi di balik
tabel profil pihak ketiga.

`esc_pos_utils_plus` tetap dipertahankan sebagai dependency karena
dikunci PRD §3.7.1 dan menjadi **jalur cadangan resmi** bila kelak
dibutuhkan raster/barcode yang lebih rumit dari `GS v 0` — dipakai dari
lapisan platform, bukan dari builder.

### 3.2 Logo dimuat lewat codec bawaan Flutter, bukan package gambar tambahan

PRD §3.3.E meminta logo dicetak sebagai raster 1-bit `GS v 0` lebar ≤ 384
dot. Jalur paling lazim adalah `package:image`, tapi menambahkannya
berarti dependency ketiga di luar dua yang dikunci PRD.

Yang dipakai: `ui.instantiateImageCodec` dari `dart:ui` (bagian dari
Flutter sendiri) untuk membaca file & menurunkan lebarnya, lalu
`EscPosRaster` — murni Dart — untuk mengemasnya jadi byte `GS v 0`.
Pemisahannya membuat encoder rasternya ikut bisa diuji unit penuh.

Dua batas dipasang sengaja: lebar dipotong ke lebar area cetak (piksel di
luar area **tidak dibuang** printer melainkan menggulung ke baris
berikutnya dan menghasilkan logo tercabik), dan tinggi dibatasi 240 dot
supaya logo salah pilih — mis. foto 4000px — tidak memuntahkan setengah
gulungan kertas. Gagal memuat logo tidak pernah menggagalkan struk:
struk tanpa logo masih struk yang sah, sedangkan struk yang tidak keluar
sama sekali adalah pembeli yang menunggu di depan kasir.

### 3.3 `PrinterException` tidak didaftarkan di `AppErrorMessage`

`AppErrorMessage.from` memakai **daftar putih** exception domain, dan
tinggal di `core/utils/`. Mendaftarkan `PrinterException` di sana berarti
`core/` harus mengimpor `data/` — arah dependensi yang dilarang
[architecture.md §3](architecture.md).

Konsekuensinya diterima dan didokumentasikan di berkasnya: **setiap**
pemanggil wajib menangkap `PrinterException` secara eksplisit
(`PrintJobController`, `PrinterDeviceSheet`), dan yang lupa akan mendapat
pesan generik alih-alih pesan berguna. `toString()` tetap mengembalikan
pesannya sebagai jaring pengaman terakhir.

### 3.4 Status "Tercetak ✓" punya umur

Perayaan yang menetap selamanya berhenti jadi perayaan dan mulai jadi
tombol rusak: kasir yang butuh lembar kedua menatap tombol bertulis
"Tercetak ✓" dan tidak tahu ia masih boleh ditekan. Status sukses karena
itu bertahan 1,8 detik (`PrintJobController.successLinger`) lalu tombol
kembali ke "Cetak Ulang".

Timernya disimpan dan dibatalkan di `dispose()` — tanpa itu, layar yang
ditutup tepat setelah struk keluar meninggalkan timer hidup yang
menyentuh notifier mati (dan, kebetulan, membuat widget test gagal
dengan "A Timer is still pending").

### 3.5 Tiga gerbang untuk AC-3.7, bukan satu

"Dua tap cepat = satu struk" dijaga berlapis, karena tiap lapis menutup
kasus yang berbeda:

1. **Tombol dinonaktifkan** selama `job.isRunning` — menutup tap ganda
   biasa.
2. **`PrintJobController` menolak** bila `state.isRunning` — menutup
   pemanggilan program (mis. cetak otomatis yang beririsan dengan tap
   manual).
3. **Mutex di transport** (`BluetoothReceiptPrinter._busy`) — menutup dua
   layar berbeda yang memanggil bersamaan; ini satu-satunya lapis yang
   benar-benar melindungi soket SPP.

Yang diuji di widget test adalah lapis 1+2 lewat UI sungguhan; lapis 3
diuji lewat printer palsu yang melempar `busy` bila dimasuki dua kali.

### 3.6 `printJobProvider` sebagai `family` per layar

Kunci `family` adalah penanda layar (`'checkout'`, `'sale-42'`,
`'settings'`), supaya status "Tercetak ✓" di layar sukses tidak ikut
terbawa ke tombol "Cetak Ulang" di detail transaksi lain. Mutex
sesungguhnya tetap satu, di `receiptPrinterProvider` yang memang instance
tunggal se-aplikasi.

---

## 4. Hasil Verifikasi

### 4.1 Test unit builder & sanitasi (43 test)

`test/data/services/printing/esc_pos_receipt_builder_test.dart` +
`receipt_text_sanitizer_test.dart`:

| Kelompok | Yang dibuktikan |
|---|---|
| Lebar kertas | 58mm = 32 kolom, 80mm = 48; **tidak ada** baris melebihi lebar kertas; garis pemisah tepat selebar kertas |
| Perataan nominal | Baris `TOTAL` tepat 32 karakter & berakhir di nominal; tanpa tab; nominal tidak pernah terpotong walau labelnya ekstrem; **tidak ada** "Rp" di mana pun |
| Nama panjang | Dibungkus di batas kata (teks utuh saat digabung kembali); kata 70 karakter dipenggal jadi 32+32+6 |
| Penanda | `** CETAK ULANG **` tepat di bawah nomor struk; struk normal tidak memuat penanda apa pun |
| Void (AC-3.9) | `** DIBATALKAN **` ada, baris `Kembali` **tidak ada**, baris `Tunai` tetap ada |
| Sanitasi (AC-3.4) | Seluruh baris ASCII murni walau input memuat `“ ” — × → ✅ 中 Café №`; keluaran `CurrencyFormatter` aman; locale ber-NBSP dijinakkan |
| Byte | Vektor uji `encodeLine` byte-per-byte; awalan `ESC @` + CP437; feed sesuai pengaturan; **tidak ada** auto-cut / QR native / laci kas |

### 4.2 Test widget alur cetak (8 test)

`test/features/pos/print_receipt_flow_test.dart`, memakai printer palsu —
tidak ada satu pun test yang butuh Bluetooth:

- **AC-3.7**: dua tap cepat → `printer.jobs.length == 1`.
- Cetak otomatis **mati** (default) → tidak ada struk keluar sendiri.
- Cetak otomatis nyala → satu struk keluar sendiri, tombol jadi
  "Cetak Ulang".
- Jumlah salinan dipatuhi (3 salinan → 3 job).
- **AC-3.5**: Bluetooth mati → "Bluetooth mati. Nyalakan dulu untuk
  mencetak." + tombol "Buka Pengaturan Bluetooth Android", tanpa crash.
- **AC-3.6**: printer tidak terjangkau → pesan muncul, **layar sukses
  tetap utuh** (nomor struk, "Pembayaran berhasil disimpan", CTA
  "Transaksi Baru"), dan tombol cetak aktif kembali — bukan mati permanen.
- Printer belum terpasang → pesan mengarahkan ke Pengaturan, nol job.
- Cetak ulang → job kedua memuat `** CETAK ULANG **`, job pertama tidak.

### 4.3 Manifest hasil merge (AC-3.11)

Diperiksa pada `build/app/intermediates/merged_manifest/release/`:

```
android.permission.ACCESS_NETWORK_STATE
android.permission.BLUETOOTH
android.permission.BLUETOOTH_ADMIN
android.permission.BLUETOOTH_CONNECT
android.permission.CAMERA
```

Tidak ada `BLUETOOTH_SCAN`, tidak ada `ACCESS_FINE_LOCATION`/
`ACCESS_COARSE_LOCATION`, tidak ada `INTERNET`.
(`ACCESS_NETWORK_STATE` sudah ada sejak sebelum M8, dibawa plugin lain.)

### 4.4 Analyze, test, build

```
flutter analyze          → No issues found!
flutter test             → 502/502 lulus
flutter build apk --release → sukses
```

Tidak ada test M0–M7 yang diubah.

---

## 5. Sisa Pekerjaan Manual (Device & Printer Fisik)

Satu item checklist M8 sengaja **dibiarkan tidak tercentang** karena
tidak mungkin diverifikasi tanpa perangkat keras:

- Uji minimal **3 merek printer 58mm berbeda** (mis. Zjiang ZJ-58xx,
  Goojprt PT-210, POS-5890/Panda).
- **AC-3.1** — pemasangan + cetak uji ≤ 6 tap (di luar dialog izin
  sistem).
- **AC-3.2** — struk 5 item terbaca utuh, tidak ada karakter terpotong di
  kanan, tidak ada baris melipat tak terduga.
- **AC-3.3** — tap "Cetak" → kertas mulai keluar ≤ 5 detik pada printer
  bonded.
- **AC-3.4 di kertas sungguhan** — tidak ada mojibake (sudah dijamin di
  level byte oleh test, tapi codepage printer nyata perlu dilihat).
- **AC-3.12** — pemasangan bertahan setelah force-close.
- **AC-3.13** — backup → restore di HP lain: pengaturan printer ikut
  terbawa; koneksi otomatis gagal dengan pesan wajar bila printernya tidak
  ada, tanpa memblokir aplikasi.
- **AC-3.14** — ukuran APK release < 40 MB. Catatan: APK "fat" gabungan
  berukuran ~82 MB, tapi yang dipasang pengguna adalah APK per-ABI
  (`--split-per-abi`) yang pada build sebelum M8 berukuran ~29,6 MB
  (arm64) dan ~25,6 MB (armeabi-v7a). Angka pastinya setelah M8 perlu
  diukur ulang saat pembuatan APK rilis.
- **AC-3.10 di HP Android 12+ sungguhan** — penolakan izin
  `BLUETOOTH_CONNECT` menampilkan penjelasan + pintasan, bukan crash.
  Alurnya sudah ada di kode & diuji dengan printer palsu; yang belum
  diuji adalah perilaku dialog izin sistem yang asli.

Selain itu, **pintasan "Buka Pengaturan Bluetooth Android"** memanggil
`MethodChannel('kasir_warung/system')` yang **belum punya penerima di
sisi Android** — panggilannya sengaja dibungkus `try/catch` sehingga
tidak pernah crash, tapi hari ini ia tidak melakukan apa-apa. Panduan 3
langkah di layar tetap lengkap dan bisa dikerjakan manual. Menambahkan
handler Kotlin-nya (satu `Intent(Settings.ACTION_BLUETOOTH_SETTINGS)`)
adalah pekerjaan kecil yang paling wajar dikerjakan bersamaan dengan uji
device fisik di atas — lihat §6.

---

## 6. Dampak untuk Milestone Berikutnya

- **M9 (Impor Excel):** tidak beririsan. Satu-satunya sentuhan bersama
  adalah layar Pengaturan, dan kartu printer berdiri di grup terpisah
  (PERANGKAT).
- **M11 (Rilis v1.1.0):** checklist rilis harus memuat (a) pengukuran
  ulang ukuran APK per-ABI (AC-3.14), (b) pemasangan handler
  `MethodChannel` pintasan Pengaturan Bluetooth, (c) uji 3 merek printer.
- **M12 (Pelanggan & Poin):** baris "Poin Anda: N" masuk ke
  `EscPosReceiptBuilder.buildLines` tepat setelah kalimat penutup —
  tempatnya sudah disiapkan, dan test lebar kolomnya akan langsung
  menjaga baris baru itu.
- **M13 (Multi-user):** baris "Kasir: <nama>" masuk di blok identitas
  transaksi, setelah tanggal. Sama seperti di atas: satu baris, dijaga
  test yang sudah ada.
- **Jalur cadangan BLE** (bila printer di lapangan ternyata BLE-only):
  ganti `BluetoothReceiptPrinter` dengan implementasi `ReceiptPrinter`
  lain memakai `universal_ble`. Byte struk, seluruh UI, dan seluruh test
  builder tidak tersentuh. **`flutter_blue_plus` tetap dilarang** —
  lisensi komersialnya berbayar.

---

## 7. Cara Menjalankan

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Untuk mencoba di device:

1. Nyalakan printer thermal, pasangkan lewat **Pengaturan Bluetooth
   Android** (PIN biasanya `1234` / `0000`).
2. Buka aplikasi → **Setelan** → grup **PERANGKAT** → kartu
   **Printer Struk** → **Hubungkan Printer** → pilih perangkat.
3. Tekan **Cetak Uji**. Kalau garis penggarisnya lurus dan angkanya rata
   kanan, printer siap dipakai.
4. Lakukan satu transaksi → layar sukses → **Cetak Struk**.
5. Untuk struk lama: **Riwayat** → pilih transaksi → **Cetak Ulang**.
