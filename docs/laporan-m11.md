# Laporan Milestone 11 — Polish & Rilis v1.1.0 (Tier 1)

**Tanggal:** 12 Agustus 2026
**Acuan:** [plan-v1.1.md](plan-v1.1.md) "Milestone 11" · [prd-v1.1.md §10](prd-v1.1.md)
(AC-10.2 s.d. AC-10.6) · [laporan-m8.md §5](laporan-m8.md) ·
[laporan-m10.md §7](laporan-m10.md) · [ui-redesign-foundation.md](ui-redesign-foundation.md)

---

## 1. Ringkasan

M11 tidak menambah satu pun fitur. Ia menutup dua lubang yang sengaja
ditinggalkan milestone sebelumnya, menyapu sisa-sisa kasar di alur baru
M7–M10, dan menaikkan versi ke rilis berbayar pertama.

Yang paling penting di antara semuanya adalah **gerbang migrasi
(AC-10.2)**, dan alasannya halus: guard ini tidak melindungi versi
sekarang, melainkan versi yang **belum ada**. Ketika M12 menaikkan
`schemaVersion` ke 2, file backup dari M12 akan sampai ke HP yang masih
menjalankan v1.1. Satu-satunya kode yang bisa menolaknya adalah kode yang
**sudah lebih dulu beredar** di HP tersebut. Karena itu urutannya tidak
bisa dibalik: guard harus rilis di v1.1.0, sebelum skema pernah naik
sekali pun. Melewatkannya berarti setiap pengguna v1.1 yang me-restore
backup v1.2 akan membuka database yang tabelnya asing — dengan data
warungnya di dalamnya.

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **608/608 lulus**. Baseline 592 utuh; **tidak satu pun
  ekspektasi test M0–M10 diubah**. 16 test baru M11.
- `flutter build apk --release --split-per-abi` → **sukses**, R8 aktif.
  **26,9 / 30,8 / 33,3 MB** per-ABI — ketiganya di bawah batas 40 MB
  (AC-3.14, PRD §11.1).
- `version:` di `pubspec.yaml` → **`1.1.0+2`**.
- `schemaVersion` tetap **1**. Backup v1.0 ↔ v1.1 kompatibel penuh dua arah.
- Kunci uji lisensi **tidak ada** di APK release; kunci produksi **ada**
  (diverifikasi pada `libapp.so` terekstrak, bukan pada zip terkompresi —
  lihat §4.4).

**Tag `v1.1.0` TIDAK dibuat oleh agent M11.** Tidak ada `git commit`,
`git push`, maupun `git tag` yang dijalankan; seluruh perubahan
ditinggalkan di working tree. Pembuatan tag adalah pekerjaan orkestrator.

---

## 2. Apa yang Dikerjakan

### 2.1 Gerbang wajib — guard versi skema backup (AC-10.2)

Sebelum M11, `BackupService.validateBackupFile` **membaca**
`PRAGMA user_version` tapi tidak pernah membandingkannya. Nilai itu dibaca
semata sebagai bukti file tidak korup.

Perubahannya berpasangan di dua berkas:

**`lib/data/db/app_database.dart`** — versi skema diangkat jadi konstanta
tingkat pustaka, satu-satunya sumber kebenaran:

```dart
const int kAppSchemaVersion = 1;
...
@override
int get schemaVersion => kAppSchemaVersion;
```

Kenapa konstanta, bukan membaca `AppDatabase.schemaVersion` langsung:
`BackupService` seluruhnya statis dan memvalidasi file **sebelum** ada
koneksi database yang dibuka. Ia butuh angka itu tanpa memegang instance.
Konstanta juga membuat kenaikan versi di M12 otomatis merambat ke guard —
tidak ada angka kedua yang bisa lupa diperbarui.

**`lib/data/services/backup_service.dart`** — perbandingannya sendiri:

```dart
final versionRows = sqliteDb.select('PRAGMA user_version');
final fileVersion =
    versionRows.isEmpty ? 0 : (versionRows.first['user_version'] as int? ?? 0);
if (fileVersion > kAppSchemaVersion) {
  throw const FileBackupTidakValidException(versiLebihBaruMessage);
}
```

Pesannya dikonstankan sebagai `BackupService.versiLebihBaruMessage`
supaya test menguji kalimat yang **persis sama** dengan yang dilihat
pengguna, bukan salinan yang bisa menyimpang:

> "File backup berasal dari versi aplikasi yang lebih baru. Perbarui
> aplikasi ini terlebih dahulu."

Arah perbandingannya sengaja **asimetris**. File yang lebih baru ditolak;
file yang **sama atau lebih lama diterima apa adanya**, karena Drift hanya
bisa migrasi maju dan migrasi itu memang berjalan otomatis lewat
`MigrationStrategy` saat `AppDatabase` dibuka setelah `restoreFrom`
(AC-10.3). Menolak file lama akan mematahkan janji kompatibilitas backup
v1.0 → v1.1 yang justru dijaga Tier 1.

Guard ditempatkan **setelah** pemeriksaan tabel wajib. Urutan ini penting
untuk kualitas pesan: file yang bukan backup Kasir Warung sama sekali
harus mendapat pesan "tabel wajib tidak lengkap", bukan pesan versi yang
menyesatkan pengguna untuk memperbarui aplikasi tanpa guna.

### 2.2 Gap M8 — handler Kotlin `kasir_warung/system`

Tombol "Buka Pengaturan Bluetooth Android" memanggil
`MethodChannel('kasir_warung/system')` yang **tidak punya penerima**
(laporan-m8.md §5). Panggilannya dibungkus `try/catch`, jadi ia tidak
pernah crash — ia hanya tidak melakukan apa-apa, diam-diam.

`MainActivity.kt` sekarang mendaftarkan **dua** channel yang berdiri
sendiri-sendiri. Tidak ada bentrok dengan channel SSAID milik M10:
namanya berbeda (`kasirwarung/device` vs `kasir_warung/system`), dan
masing-masing `MethodChannel` punya handler sendiri di atas
`binaryMessenger` yang sama — pola yang memang didukung Flutter.

```kotlin
MethodChannel(messenger, CHANNEL_SYSTEM).setMethodCallHandler { call, result ->
    if (call.method == METHOD_OPEN_BLUETOOTH_SETTINGS) {
        result.success(openBluetoothSettings())
    } else {
        result.notImplemented()
    }
}
```

`openBluetoothSettings()` mencoba `Settings.ACTION_BLUETOOTH_SETTINGS`,
lalu jatuh ke `Settings.ACTION_SETTINGS` bila ROM-nya tidak
mengekspor layar itu, dan akhirnya mengembalikan `false`. Kegagalan
**tidak** dilaporkan sebagai error channel: pintasan ini cuma mempercepat
panduan tiga langkah yang sudah tercetak di layar, jadi ROM aneh cukup
dijawab `false` tanpa dialog teknis.

Sisi Dart ikut disesuaikan — `openAndroidBluetoothSettings()` sekarang
mengembalikan `Future<bool>` dan channel-nya diekspos sebagai
`PrinterDeviceSheet.systemChannel` supaya bisa diuji.

### 2.3 Sapu regresi & polish M7–M10

Enam cacat nyata ditemukan dan diperbaiki. Tidak ada fitur baru.

**a. `ImporProdukException` tidak dikenali `AppErrorMessage`.** Doc di
`import_exceptions.dart` menjanjikan "`AppErrorMessage.from` cukup
mengenali tipe ini saja" — tapi induknya tidak pernah didaftarkan.
Akibatnya pesan spesifik seperti *"Kolom wajib tidak ditemukan:
harga_jual. Perbaiki judul kolom di baris pertama file…"* berubah jadi
*"Terjadi kesalahan tak terduga. Coba lagi."* begitu error lewat jalur
error umum. Kontrak yang tertulis tapi tidak berlaku. Diperbaiki dengan
satu baris + test untuk seluruh turunannya.

**b. `PrinterException` sengaja TIDAK didaftarkan.** Ini diperiksa, bukan
dilewatkan: mendaftarkannya berarti `core/` mengimpor `data/` — arah
dependensi yang dilarang architecture.md §3. Seluruh pemanggil printer
sudah menangkap `PrinterException` secara eksplisit dan membaca
`.message` (`printer_providers.dart:128,155`,
`printer_device_sheet.dart:273-276`), jadi konsekuensinya sudah
ditanggung di tempatnya. Alasannya dicatat sebagai komentar di
`error_message.dart` supaya tidak "diperbaiki" keliru nanti.

**c. Cabang error `receipt_format_sheet.dart` adalah jalan buntu.** Ia
merender `Text('Pengaturan gagal dimuat: $e')` — exception mentah
berbahasa Inggris, tanpa ikon, tanpa "Coba Lagi". Sheet ini tidak punya
jalan keluar lain selain ditutup, jadi kegagalan provider mengunci
pengguna. Diganti `AppErrorView` dengan `onRetry`, sama seperti
`printer_section.dart`.

**d. SnackBar sesudah `pop()` di `receipt_format_sheet._save()`.**
`ScaffoldMessenger.of(context)` dipanggil memakai context sheet yang baru
saja dilepas dari pohon. Messenger sekarang diambil **sebelum** pop.

**e. `AppTextStyles.moneyLarge` di `import_summary_card.dart`.** Gaya
statis ini memanggang `AppColors.ink` — palet **terang** — ke dalam
`TextStyle`. Hari ini tidak terlihat karena `.copyWith(color:)` selalu
menimpanya, tapi itu perangkap: hapus `.copyWith` dan ia jadi pulau putih
di mode gelap. Diganti `context.textStyles.moneyLarge`.

**f. Dua pesan error dengan titik bersarang.** `product_import_screen.dart`
menyisipkan `AppErrorMessage.from(e)` — yang **sudah** kalimat lengkap
dua bagian — ke dalam tanda kurung di tengah kalimat lain, menghasilkan
*"File tidak bisa dibaca (Terjadi kesalahan tak terduga. Coba lagi.).
Pastikan…"*. Kalimatnya dirapikan; panduan tindakannya dipertahankan.

**Yang diperiksa dan ternyata sudah bersih:** target sentuh (tidak ada
satu pun widget interaktif di M7–M10 yang menimpa ke bawah 48dp; tema
global sudah memaksa `FilledButton` ≥ 52 dan icon button ≥ 48), empty
state (`_PairingGuide`, `PosLockedView`, `EmptyState` wizard impor semua
memakai komponen bersama), dan kebocoran error di seluruh berkas M7–M10
selain (c) dan (f).

### 2.4 Gerbang otomatis diperkuat

`no_hardcoded_colors_test.dart` dari M7 punya dua celah yang baru
kelihatan saat menyapu M8–M10:

- **`Color(0x…)` / `Color.fromARGB` tidak pernah diperiksa.** Efek
  sampingnya menggelikan: entri allowlist `receipt_widget.dart` selama ini
  **mati** — berkas itu memakai `Color(0xFFFFFFFF)`, bukan
  `Colors.white` — sehingga ia memakan slot allowlist tanpa menjaga apa
  pun. Sekarang polanya diperiksa, dan allowlist-nya kembali bermakna.
- **`AppTextStyles.*` tidak pernah diperiksa**, padahal itulah bentuk
  cacat (e) di atas: warna palet terang yang menyelinap lewat gaya teks,
  tanpa pernah menuliskan `AppColors.` di berkas itu.

Keduanya kini dijaga test, jadi M12–M14 tidak bisa mengulanginya.

---

## 3. Keputusan Teknis

### 3.1 `kAppSchemaVersion` sebagai konstanta pustaka, bukan getter instance

Dipertimbangkan: membaca `AppDatabase(...).schemaVersion` di dalam
`BackupService`. Ditolak — validasi berjalan sebelum koneksi mana pun
dibuka, dan membuka `AppDatabase` hanya untuk membaca satu angka berarti
menjalankan `MigrationStrategy` pada file yang justru sedang dinilai
layak-tidaknya. Konstanta memutus lingkaran itu, dan test
`schemaVersion AppDatabase konsisten dengan kAppSchemaVersion` menjaga
keduanya tidak pernah berpisah.

### 3.2 Guard membandingkan `>`, bukan `!=`

Backup lebih lama **harus** diterima (AC-10.3) — itu inti janji
kompatibilitas Tier 1. Hanya arah "lebih baru" yang berbahaya, karena
Drift tidak punya migrasi mundur.

### 3.3 Handler Bluetooth mengembalikan `Boolean`, bukan melempar

Sisi Dart sudah membungkus panggilan dengan `try/catch` sejak M8 dan
sengaja diam saat gagal. Melempar `PlatformException` dari Kotlin hanya
akan berakhir di `catch` yang sama — jadi nilai balik `Boolean` memberi
informasi yang sama tanpa biaya exception, dan membuat perilakunya bisa
diuji langsung.

### 3.4 Versi `1.1.0+2`, bukan `1.1.0+1`

`versionCode` Android harus **naik monoton**; v1.0.0 sudah memakai `+1`.
Memakai ulang `+1` membuat pembaruan di atas pemasangan lama ditolak
sistem.

---

## 4. Hasil Verifikasi

### 4.1 `flutter analyze`

```
Analyzing aplikasi-kasir...
No issues found!
```

### 4.2 `flutter test`

**608/608 lulus.** Baseline M10 adalah 592 — seluruhnya masih hijau,
**tanpa satu pun ekspektasi test M0–M10 diubah**. 16 test baru:

| Berkas | Baru | Cakupan |
|---|---:|---|
| `test/data/services/backup_service_test.dart` | 7 | Guard AC-10.2: tolak `user_version` +1 & +5 (dengan pemeriksaan pesan persis), terima yang **sama**, terima yang **lebih lama** (AC-10.3), file non-DB dapat pesan "bukan database" **bukan** pesan versi, dan konsistensi `schemaVersion` ↔ `kAppSchemaVersion` |
| `test/features/settings/bluetooth_settings_shortcut_test.dart` | 5 | Nama channel & metode dipaku; hasil `true`/`false`/`notImplemented`/`PlatformException` semuanya ditangani tanpa lempar |
| `test/core/utils/error_message_test.dart` | 2 | Seluruh turunan `ImporProdukException` mempertahankan pesan spesifiknya |
| `test/core/constants/no_hardcoded_colors_test.dart` | 2 | `Color(0x…)`/`Color.fromARGB` telanjang & `AppTextStyles.*` statis |

Test file non-DB (`4.2` baris terakhir tabel pertama) sengaja memakai
header PNG asli, bukan teks acak — supaya yang diuji benar-benar "file
lain yang salah dipilih pengguna", bukan sekadar string yang kebetulan
bukan SQLite.

### 4.3 `flutter build apk --release --split-per-abi`

Sukses, R8 + `shrinkResources` aktif.

| ABI | Ukuran | Batas 40 MB |
|---|---:|---|
| `armeabi-v7a` | 26,9 MB | ✅ |
| `arm64-v8a` | 30,8 MB | ✅ |
| `x86_64` | 33,3 MB | ✅ |

APK "fat" gabungan ~80 MB — **bukan** yang didistribusikan. Distribusi
wajib per-ABI atau App Bundle (laporan-m10.md §4.3).

### 4.4 Kunci uji tidak ada di APK release (AC-6.8, AC-6.19)

Pemeriksaan `grep` langsung pada berkas `.apk` **tidak sahih** — APK
adalah zip, isinya terkompresi, sehingga string apa pun "tidak ditemukan"
dan hasilnya menipu. Verifikasi dilakukan pada `libapp.so` yang
diekstrak, dengan kontrol positif lebih dulu:

| String | Hasil |
|---|---|
| `"Perbarui aplikasi ini terlebih dahulu"` (pesan AC-10.2 baru) | **ADA** — kontrol positif: string Dart memang terlihat |
| `"Belum ada printer terpasang"` | **ADA** — kontrol positif kedua |
| `kasir_warung/system` | **ADA** — channel M11 ikut ter-build |
| Kunci **produksi** `rsBd/CBPjDklHlV7AKK0NTlGi/d4uZ6C9m2L2+6feS4=` | **ADA** ✅ |
| Kunci **uji** `BvM36lmeMEfo0mWp8tNTCJeq0ds02eyT18BcLyww0k0=` | **TIDAK ADA** ✅ |

Tanpa dua kontrol positif itu, "kunci uji tidak ditemukan" tidak
membuktikan apa-apa. `const bool.fromEnvironment('dart.vm.product')`
terbukti bekerja: cabang kunci uji dibuang compiler AOT.

Diperiksa juga: **tidak ada** bypass `kDebugMode` di jalur gerbang
lisensi. Satu-satunya `kDebugMode` di `lib/` ada di
`seed_data_service.dart` (data contoh), tidak menyentuh lisensi. Gerbang
memakai `LicenseStatus.gerbangDimatikan()` yang eksplisit dan dijaga
`license_bootstrap_wiring_test.dart`.

**Kunci privat penerbit ter-commit: 0.** `git ls-files` tidak memuat
`*.key`; `.gitignore` menutup `*.key`, `lisensi-terbit.csv`, dan
`lisensi-*.png`.

### 4.5 Metrik PRD §11.1 yang bisa diukur tanpa perangkat

| Metrik | Status |
|---|---|
| Ukuran APK release < 40 MB | ✅ 26,9 / 30,8 / 33,3 MB |
| Layar dengan kontras < 4.5:1 di mode gelap = 0 | ✅ `app_palette_contrast_test.dart` hijau |
| Layar yang masih "putih" di mode gelap = 0 | ✅ `no_hardcoded_colors_test.dart` hijau, kini + 2 pola baru |
| Struk yang di-share tetap putih = 100% | ✅ `receipt_widget.dart` allowlisted & disengaja (K-5.3) |
| Impor setengah masuk = 0 kasus (atomik) | ✅ dijaga test transaksi M9 |
| Baris bermasalah tak dilaporkan = 0 | ✅ test M9 + perbaikan §2.3(a) |
| Lisensi sah ditolak (false negative) = 0 | ✅ vektor uji beku M10 hijau |
| Kode salah ketik diterima (false positive) = 0 | ✅ test CRC M10 hijau |
| Trial ter-reset oleh reinstall = 0 | ✅ test otomatis hijau; konfirmasi fisik → §6 |
| Kunci privat ter-commit = 0 | ✅ diperiksa §4.4 |
| Pertambahan APK akibat lisensi < 1 MB | ✅ tidak ada dependency baru di M10/M11 |
| Cold start < 3 detik | ⏳ butuh device fisik → §6 |
| Waktu aktivasi ≤ 30 dtk / ≤ 2 mnt | ⏳ butuh device fisik → §6 |
| Cetak: ≥ 90% berhasil, ≤ 5 detik, 3 model printer | ⏳ butuh printer fisik → §6 |
| Impor 500 produk ≤ 20 detik | ⏳ butuh device fisik → §6 |

---

## 5. PENGHALANG RILIS — keystore rilis belum ada

Satu item checklist M11 **tidak bisa** diselesaikan dari lingkungan ini,
dan ia bukan sekadar "butuh device fisik" — ia butuh keputusan pemilik:

`android/app/build.gradle.kts` masih berisi bawaan Flutter:

```kotlin
release {
    // TODO: Add your own signing config for the release build.
    // Signing with the debug keys for now, so `flutter run --release` works.
    signingConfig = signingConfigs.getByName("debug")
}
```

**APK release saat ini ditandatangani kunci debug.** Konsekuensinya
mengikat langsung ke M10: kode perangkat berasal dari SSAID, yang pada
Android 8.0+ unik per **kunci penanda tangan APK**. Artinya:

1. Kode lisensi yang diterbitkan untuk APK bertanda-tangan debug
   **tidak akan berlaku** setelah APK ditandatangani kunci rilis
   sebenarnya — kode perangkatnya berubah total.
2. Janji "trial tidak bisa direset dengan pasang ulang" (AC-6.11) hanya
   berlaku bila kunci penanda tangannya **stabil selamanya**.

Keystore rilis **sengaja tidak dibuat oleh agent M11**: ia adalah rahasia
jangka panjang yang harus dimiliki, dicadangkan, dan dijaga pemilik
sendiri — kehilangannya berarti tidak bisa lagi merilis pembaruan untuk
pemasangan yang sudah beredar, selamanya. Membuatkannya secara otomatis
lalu meninggalkannya di direktori kerja adalah cara paling rapi untuk
kehilangannya.

**Yang harus dilakukan pemilik sebelum menerbitkan kode uji-terima:**
buat keystore, simpan cadangannya di luar laptop, tulis kredensialnya di
`android/key.properties` (sudah tertutup `.gitignore`), sambungkan ke
`build.gradle.kts`, lalu build ulang. Baru setelah itu kode perangkat
final muncul dan kode lisensi layak diterbitkan.

Sampai itu terjadi, dua item checklist M11 tetap terbuka: gerbang
penjualan (bagian ketiganya) dan penerbitan kode uji-terima 2 perangkat.

---

## 6. Daftar Uji-Terima Manual — Satu Sesi Device Fisik

Gabungan sisa manual M7 §5, M8 §5, M9, M10 §7, plus smoke rilis.
Kerjakan berurutan; **A harus tuntas lebih dulu** karena gerbang lisensi
menghalangi semua yang lain.

### A. Prasyarat rilis (sekali, sebelum semua)

- [ ] Keystore rilis dibuat & dicadangkan di luar laptop (§5)
- [ ] `build.gradle.kts` memakai `signingConfig` rilis; build ulang
      `--split-per-abi` sukses
- [ ] APK arm64 dipasang di **2 perangkat nyata** (idealnya 1 HP kecil
      ~5", 1 tablet)

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
      AC-6.11) — *satu-satunya AC yang tidak bisa disimulasikan*
- [ ] **Mundurkan jam 1 tahun**: banner tampil, sisa masa berlaku **tidak
      bertambah** (AC-6.8/§6.3.G)
- [ ] Lisensi berakhir → **Riwayat, Laporan, Export, Backup tetap bisa
      diakses** (K-6.11)
- [ ] Gerbang **tidak pernah** mengunci di tengah transaksi berjalan
      (AC-6.18): buka keranjang berisi, tunggu melewati batas
- [ ] Jalankan alur pembelian penuh dari sisi **penjual** dan **pembeli**;
      simpan hasilnya sebagai catatan rilis

### C. Mode gelap (M7)

- [ ] **Cold start mode gelap: tidak ada kedip putih** (AC-5.5), termasuk
      transisi dari splash hijau `#1B7A43`
- [ ] **"Ikuti Sistem"**: ubah tema Android saat aplikasi terbuka →
      ikut berubah **tanpa restart** (AC-5.3)
- [ ] Status bar & ikon sistem terbaca di **kedua** tema (AC-5.9)
- [ ] Angka & pill status terbaca di HP kecil **dalam ruangan gelap**
      (AC-5.11)
- [ ] Mode gelap di **tablet** (breakpoint 600dp, layar Kasir dua panel)

### D. Printer thermal (M8)

- [ ] Pasangkan printer di Pengaturan Bluetooth Android (PIN `1234`/`0000`)
- [ ] **Tombol "Buka Pengaturan Bluetooth Android" benar-benar membuka
      layar itu** — handler Kotlin baru M11, belum pernah diuji di
      perangkat
- [ ] **Cetak Uji**: garis penggaris lurus, angka rata kanan
- [ ] Transaksi → layar sukses → **Cetak Struk** → **≤ 5 detik** sampai
      kertas keluar
- [ ] **Cetak Ulang** dari detail transaksi lama → penanda
      `** CETAK ULANG **` muncul
- [ ] Transaksi dibatalkan → penanda `** DIBATALKAN **` muncul
- [ ] Uji pada **3 model printer 58mm berbeda** → keberhasilan **≥ 90%**
- [ ] **Printer dimatikan / kehabisan kertas saat cetak**: transaksi
      **tetap tersimpan utuh**, hanya cetaknya gagal (PRD §3.3.B) — **0
      kasus** transaksi hilang
- [ ] **Android 12+**: tolak izin `BLUETOOTH_CONNECT` → muncul penjelasan
      + pintasan, **bukan crash** (AC-3.10)

### E. Impor Excel (M9)

- [ ] Impor **500 produk** dari file valid → **≤ 20 detik**, 0 baris
      salah tafsir
- [ ] File dengan **kolom wajib hilang** → ditolak sebelum satu baris pun
      diproses, pesan menyebut nama kolomnya (AC-4.4)
- [ ] File dengan **beberapa baris rusak** → semua dilaporkan; tidak ada
      yang disembunyikan
- [ ] **Impor gagal di tengah** → **0 produk** tersimpan (atomik, AC-4.15)
- [ ] Pengisian katalog 300 produk terasa **≤ 15 menit** ujung ke ujung

### F. Backup & migrasi (M11, AC-10.2/10.3)

- [ ] Backup di HP A → **restore di HP B**: seluruh data utuh
- [ ] **Pengaturan printer ikut terbawa** restore; printer HP A tidak ada
      di HP B → gagal terhubung dengan pesan wajar, **tanpa memblokir
      aplikasi** (AC-3.13)
- [ ] Restore file **bukan backup** (mis. foto yang diganti nama `.db`) →
      pesan "bukan file database", aplikasi tidak rusak
- [ ] Restore backup **v1.0** di aplikasi v1.1 → jalan mulus (AC-10.3)

### G. Regresi alur v1.0 & smoke rilis

- [ ] Seluruh checklist [prd.md](prd.md) §4 & §5 di **HP kecil** dan
      **tablet**, **mode terang** dan **gelap**
- [ ] Alur kasir inti tetap **tiga langkah**; tidak ada tap tambahan
- [ ] **Cold start < 3 detik** diukur di HP kelas menengah
- [ ] Verifikasi kode lisensi di HP kelas menengah **< 1 detik**

---

## 7. Berkas yang Disentuh

**Kode aplikasi**

| Berkas | Perubahan |
|---|---|
| `lib/data/db/app_database.dart` | `kAppSchemaVersion` sebagai sumber kebenaran tunggal |
| `lib/data/services/backup_service.dart` | Guard AC-10.2 + `versiLebihBaruMessage` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Channel `kasir_warung/system` + `openBluetoothSettings()` |
| `lib/features/settings/widgets/printer_device_sheet.dart` | `systemChannel` diekspos; hasil `Future<bool>` |
| `lib/core/utils/error_message.dart` | `ImporProdukException` dikenali; catatan soal `PrinterException` |
| `lib/features/settings/widgets/receipt_format_sheet.dart` | `AppErrorView` + retry; messenger diambil sebelum `pop()` |
| `lib/features/products/widgets/import_summary_card.dart` | `context.textStyles.moneyLarge` |
| `lib/features/products/screens/product_import_screen.dart` | Dua pesan error dirapikan |
| `pubspec.yaml` | `version: 1.1.0+2` |

**Test**

| Berkas | Perubahan |
|---|---|
| `test/data/services/backup_service_test.dart` | +7 test guard AC-10.2 |
| `test/features/settings/bluetooth_settings_shortcut_test.dart` | **baru**, 5 test kontrak channel |
| `test/core/utils/error_message_test.dart` | +2 test kegagalan impor |
| `test/core/constants/no_hardcoded_colors_test.dart` | +2 pola gerbang |

**Dokumentasi:** `docs/plan-v1.1.md` (tracker M11), `docs/laporan-m11.md`.

---

## 8. Dampak untuk Milestone Berikutnya

- **M12 (Pelanggan & Poin, `schemaVersion` 1 → 2) kini BOLEH dimulai —
  setelah v1.1.0 benar-benar dirilis.** Guard AC-10.2 ada di kode, tapi
  yang melindungi pengguna adalah guard yang **sudah terpasang di HP
  mereka**. Prasyarat M12 berbunyi "pastikan v1.1.0 sudah dirilis", dan
  itu berarti APK bertanda tangan rilis sudah sampai ke tangan pengguna —
  bukan sekadar ada di `build/`.
- **Menaikkan `schemaVersion` sekarang cukup mengubah satu angka**
  (`kAppSchemaVersion` di `app_database.dart`); guard backup ikut naik
  otomatis, dan test konsistensinya akan menangkap bila `AppDatabase`
  sempat berpisah dari konstanta itu.
- **Gerbang warna diperkuat** — M12–M14 sekarang juga dijaga terhadap
  `Color(0x…)` mentah dan `AppTextStyles.*` statis, bukan hanya
  `AppColors.`.
- **Channel `kasir_warung/system` sudah punya penerima**, jadi kebutuhan
  platform kecil berikutnya (mis. membuka pengaturan aplikasi) tinggal
  menambah satu `if` di `MainActivity.kt`.

---

## 9. Cara Menjalankan

```bash
flutter pub get
flutter analyze                              # 0 issue
flutter test                                 # 608/608
flutter build apk --release --split-per-abi  # 26,9 / 30,8 / 33,3 MB
```

Verifikasi kunci uji tidak ikut build release (jalankan ulang setiap
rilis — `grep` pada `.apk` mentah TIDAK sahih karena zip terkompresi):

```bash
cd $(mktemp -d) && unzip -q .../app-arm64-v8a-release.apk
grep -c "Belum ada printer terpasang" lib/arm64-v8a/libapp.so   # kontrol positif, harus > 0
grep -c "BvM36lmeMEfo"                lib/arm64-v8a/libapp.so   # kunci uji, harus 0
grep -c "rsBd/CBPjDkl"                lib/arm64-v8a/libapp.so   # kunci produksi, harus > 0
```

**Tag `v1.1.0` dibuat orkestrator**, bukan dari milestone ini. Tidak ada
commit/push/tag yang dijalankan agent M11.
