# Plan v1.1 — Rencana Pengerjaan Aplikasi Kasir Warung (Post-MVP)

**Versi:** 1.1
**Acuan:** [prd-v1.1.md](prd-v1.1.md) · [plan.md](plan.md) (MVP, M0–M6 tuntas) · [architecture.md](architecture.md)

Rencana disusun sebagai **milestone berurutan lanjutan dari MVP** (M0–M6 sudah tuntas di [plan.md](plan.md)). Setiap milestone menghasilkan aplikasi yang bisa dijalankan & diuji (incremental). Checklist dicentang selama pengerjaan agar dokumen ini sekaligus menjadi tracker progres.

Empat catatan penyusunan yang mengikat:

1. **Cakupan dikunci oleh [prd-v1.1.md](prd-v1.1.md).** Enam fitur produk + satu fitur komersial (lisensi, PRD §6), dua tier, tidak lebih. Daftar "TIDAK termasuk" di tiap bab PRD dan §12 berlaku penuh.
2. **Tier 1 (M7–M10) tidak menyentuh skema database** — `schemaVersion` tetap **1**, sehingga backup v1.0 dan v1.1 saling kompatibel penuh. Migrasi skema baru dimulai di Tier 2 (M12: 1→2, M13: 2→3).
3. **Penomoran rilis.** M11 merilis Tier 1 sebagai **v1.1.0**, M15 merilis Tier 2 sebagai **v1.2.0**. PRD v1.1 tetap menjadi satu dokumen sumber untuk keduanya; pemecahan nomor rilis murni keputusan pengemasan agar Tier 1 sampai ke pengguna tanpa menunggu migrasi skema — sekaligus memberi jalan agar **AC-10.2 sudah beredar sebelum `schemaVersion` pernah naik** (lihat M11).
4. **M10 (Sistem Lisensi Offline) adalah gerbang penjualan dan syarat rilis v1.1.0.** v1.1.0 adalah rilis berbayar pertama; melepasnya tanpa gerbang aktivasi berarti melepas APK yang bebas disebarkan, dan memasang gerbang pada pengguna yang sudah terbiasa memakainya bebas jauh lebih menyakitkan daripada memasangnya sejak awal (PRD §2.2). M11 **tidak boleh** dirilis sebelum M10 tuntas.

**Mode gelap (§5 PRD) dikerjakan lebih dulu di antara Tier 1** meskipun nilai bisnisnya di bawah printer & impor. Alasannya teknis, bukan preferensi: PRD §5.1 mencatat 351 pemakaian `AppColors.*` di 44 file, dan M8/M9/M10 menambah banyak layar baru (kartu printer, sheet perangkat, wizard impor 5 langkah, layar aktivasi & layar lisensi berakhir). Menulis layar-layar itu setelah `AppPalette` ada berarti layar baru langsung sadar-tema dan tidak perlu dimigrasi dua kali. PRD §2.4 menyatakan fitur-fitur Tier 1 paralel dan hanya mewajibkan mode gelap selesai **sebelum Tier 2** — urutan ini tidak melanggarnya, hanya memanfaatkannya.

**M10 sengaja ditempatkan setelah M8/M9, bukan sebelumnya.** Gerbang aktivasi yang dipasang lebih awal akan menghalangi setiap uji manual di device fisik pada M7–M9 (setiap pemasangan APK debug menuntut kode baru), sementara nilainya baru terealisasi pada saat rilis. Yang mengikat adalah **selesai sebelum M11**, bukan dikerjakan lebih dulu.

---

## Milestone 7 — Mode Gelap & Fondasi Tema Sadar-Konteks
> Hasil: seluruh aplikasi bisa Terang / Gelap / Ikuti Sistem tanpa "pulau putih", dan seluruh layar berikutnya lahir sudah sadar-tema.

- [x] `AppPalette extends ThemeExtension<AppPalette>` di `core/constants/`: seluruh token (netral, brand, aksen, trio semantik, alias domain) sebagai field instance, dengan `const AppPalette.light()` & `const AppPalette.dark()` memakai nilai usulan PRD §5.4 (K-5.1)
- [x] Daftarkan palet di `ThemeData.extensions` pada `AppTheme.light()` + tulis `AppTheme.dark()`; akses lewat extension `context.palette`
- [x] `AppTone.colorsOf(context)` sadar-tema; getter lama `AppTone.colors` dipertahankan `@Deprecated` (mengembalikan palet terang) selama masa migrasi (K-5.6)
- [x] `AppShadows` varian gelap (alpha jauh lebih rendah, dekoratif) & `AppDecorations` mengambil warna dari `context.palette`
- [x] `themeModeProvider` + persistensi `theme_mode` di **`shared_preferences`**, bukan tabel `settings` (K-5.2) — nilai dibaca di `main()` **sebelum `runApp()`** agar frame pertama sudah bertema benar (AC-5.5)
- [x] `MaterialApp.router` menerima `theme` / `darkTheme` / `themeMode`; `SystemUiOverlayStyle` status bar ikut dibalik (AC-5.9)
- [x] Pengaturan → kartu baru **"Tampilan"** di ATAS kartu "Profil Toko": `SegmentedButton` Terang/Gelap/Ikuti Sistem (tinggi ≥ 48dp) + kalimat keterangan; default **Terang**
- [x] Migrasi langkah 2 — `core/widgets/` (`app_card`, `app_pill`, `app_data_row`, `empty_state`, `section_header`, `app_state_views`, `main_shell`)
- [x] Migrasi langkah 3 — layar per fitur berurutan: `pos` → `products` → `transactions` → `reports` → `settings` → `inventory`
- [x] `ReceiptWidget` dipaksa tema terang lewat `Theme(data: AppTheme.light(), child: ...)` saat dirender & di-capture (K-5.3)
- [x] Sapu bersih: tidak ada lagi `AppColors.*` di `lib/features/`, tidak ada `Colors.white`/`Colors.black` telanjang di `lib/features` & `lib/core/widgets` kecuali allowlist berkomentar alasan (AC-5.6)
- [x] Test kontras otomatis: setiap pasangan (teks, latar) di `AppPalette` terang & gelap ≥ 4.5:1 (≥ 3:1 untuk teks ≥18px/ikon), dengan daftar pengecualian eksplisit mis. `inkTertiary` (AC-5.8)
- [x] Test widget: pump setiap layar utama dengan `AppTheme.dark()` (AC-5.10); struk yang di-capture tetap berlatar putih di kedua tema (AC-5.7); seluruh test M0–M6 lulus **tanpa diubah** (AC-5.12)
- [ ] Uji manual device fisik: tidak ada kedip putih saat cold start mode gelap, "Ikuti Sistem" mengikuti perubahan tema Android tanpa restart, keterbacaan angka & pill status di HP kecil pada ruangan gelap (AC-5.1–5.3, AC-5.11) — **butuh uji manual device**

## Milestone 8 — Cetak Struk ke Printer Thermal Bluetooth 58mm
> Hasil: struk keluar di kertas dalam hitungan detik, dan kegagalan printer tidak pernah menyentuh data penjualan.

- [x] **Commit terpisah khusus dependency:** tambah `print_bluetooth_thermal: ^1.2.2` + `esc_pos_utils_plus: ^2.0.4`, lalu `flutter pub get` & **`flutter build apk --release` wajib sukses SEBELUM satu baris kode fitur ditulis** (AC-3.15). Gagal build → coret kandidat, jangan menambal Gradle. **Jangan hapus `android.builtInKotlin=false`** dari `android/gradle.properties`
- [x] `AndroidManifest.xml`: deklarasikan **hanya** `BLUETOOTH_CONNECT` (+ `BLUETOOTH`/`BLUETOOTH_ADMIN` dengan `maxSdkVersion="30"`); verifikasi manifest hasil merge (`app/build/outputs/logs/manifest-merger-*.txt`) tidak memuat `BLUETOOTH_SCAN` maupun izin lokasi (AC-3.11)
- [x] `EscPosReceiptBuilder` di `data/services/printing/` — **murni Dart, tanpa dependency platform** (K-3.2): `SaleResult` + `StoreProfile` → `List<int>`, 32 karakter untuk 58mm (48 untuk 80mm, K-3.6), word-wrap nama panjang, nominal rata kanan dengan padding spasi (bukan tab), tanpa prefiks "Rp", urutan sama dengan `ReceiptService.formatReceiptText`
- [x] Sanitasi **ASCII wajib** sebelum byte dibentuk (K-3.7): `×`→`x`, `–`/`—`→`-`, `’`→`'`, U+00A0→spasi biasa, sisanya diganti spasi
- [x] `abstract class ReceiptPrinter` + implementasi berbasis `print_bluetooth_thermal`; `features/` **tidak pernah** menyentuh package Bluetooth langsung (K-3.1). Mutex satu job cetak, timeout eksplisit (koneksi 8 dtk, tulis 10 dtk), seluruh operasi `async`
- [x] Key baru di tabel `settings` sesuai PRD §3.5 (`printer_address`, `printer_name`, `printer_type`, `printer_paper_width`, `printer_auto_print`, `printer_copies`, `printer_logo_path`, `receipt_footer_text`, `receipt_feed_lines`) — **`schemaVersion` tetap 1**
- [x] Pengaturan → kartu **"Printer Struk"** (pola `SettingsCard`): status `AppPill` (Terhubung / Belum terpasang / Gagal terhubung), sheet daftar perangkat **bonded** (baris ≥ 56dp), aksi "Cetak Uji" & "Lepas Printer"
- [x] Empty state daftar perangkat: panduan 3 langkah + tombol "Buka Pengaturan Bluetooth Android" (AC-3.16) — pemasangan memang dilakukan di Pengaturan Android (K-3.9)
- [x] Opsi printer: cetak otomatis (**default mati**), salinan 1–3, lebar kertas 58/80mm, logo toko sebagai raster 1-bit `GS v 0` lebar ≤ 384px, kalimat penutup, baris feed 0–6. **Tanpa QR native ESC/POS** (K-3.8)
- [x] Tombol **"Cetak"** di layar sukses sebagai `OutlinedButton` (tinggi 52) di samping "Bagikan" — tidak boleh mencuri penekanan dari CTA "Transaksi Baru"; status inline `Menghubungkan… → Mencetak… → Tercetak ✓ / Gagal — Coba Lagi`; cetak otomatis mengubah tombol menjadi "Cetak Ulang"
- [x] Pencetakan **selalu terjadi setelah transaksi tersimpan dan di luar `db.transaction()`** (K-3.4); tanpa antrean cetak persisten (K-3.5)
- [x] "Cetak Ulang" di detail transaksi dengan penanda `** CETAK ULANG **`; transaksi `voided` dicetak dengan `** DIBATALKAN **` dan tanpa baris kembalian
- [x] Penanganan kegagalan dalam Bahasa Indonesia: Bluetooth mati (+ tombol aksi), izin `BLUETOOTH_CONNECT` ditolak (penjelasan + pintasan Pengaturan aplikasi), printer tidak terjangkau — **transaksi tetap tersimpan dan tetap muncul di Riwayat** (AC-3.5, AC-3.6, AC-3.10)
- [x] Pratinjau struk di Pengaturan me-*reuse* `ReceiptWidget` dan **selalu bertema terang** meski aplikasi sedang gelap
- [x] Test unit builder (tanpa perangkat): jumlah karakter per baris, perataan nominal, pemotongan nama panjang, penanda cetak ulang/void, dan sanitasi atas keluaran `CurrencyFormatter` (`intl` locale `id_ID`, termasuk kasus U+00A0)
- [x] Test widget: dua tap cepat "Cetak" hanya menghasilkan satu job (AC-3.7); simulasi printer gagal tidak mengubah/menghapus transaksi (AC-3.6)
- [ ] Uji manual device fisik: minimal **3 merek printer 58mm berbeda**; pemasangan + cetak uji ≤ 6 tap (AC-3.1); tap "Cetak" → kertas keluar ≤ 5 detik (AC-3.3); struk 5 item terbaca utuh tanpa mojibake (AC-3.2, AC-3.4); pemasangan bertahan setelah force-close (AC-3.12); ukuran APK release tetap < 40 MB (AC-3.14) — **butuh uji manual device/printer fisik**

## Milestone 9 — Impor Produk dari Excel
> Hasil: katalog ratusan produk masuk sekali jalan, atau tidak masuk sama sekali.

- [x] Generator **"Unduh Template"** → `template_produk.xlsx` dua sheet (`Produk` dengan 9 kolom PRD §4.3.A + baris contoh bertanda, dan `Petunjuk` Bahasa Indonesia). Memakai package `excel` yang sudah ada — **tanpa dependency baru** (K-4.1)
- [x] Parser & validator (`data/services/product_import_service.dart`): pencocokan header **case-insensitive, urutan bebas**, kolom asing diabaikan, sheet `Produk` bila ada — kalau tidak, sheet pertama; kolom wajib hilang → impor ditolak sebelum apa pun diproses (AC-4.4)
- [x] Kompatibilitas file export v1.0 `produk_stok.xlsx` tanpa diedit (kolom `No` & `Status Stok` diabaikan) → siklus export → edit → import resmi didukung (AC-4.2)
- [x] Normalisasi nilai khas Indonesia (PRD §4.3.C): `Rp 12.000`/`12.000`/`12000` → `12000`; stok `1,5` dan `1.5` → `1.5`; harga selalu dibulatkan ke rupiah penuh dengan **peringatan**, bukan error
- [x] Tingkat masalah per baris **Error** (dilewati) vs **Peringatan** (tetap diimpor) sesuai PRD §4.3.D, dan aturan duplikat barcode PRD §4.3.E (ganda di dalam file → **kedua** baris error, pesan menyebut semua nomor baris)
- [x] Parsing & validasi dijalankan di **isolate** lewat `compute` dengan pola persis `ExcelExportService` (hanya tipe sendable menyeberang) — K-4.2; batas **5.000 baris** per file (K-4.4)
- [x] `ProductRepository.importProducts(...)`: seluruh penulisan dalam **satu `db.transaction()`** (K-4.5), pencocokan produk lama **hanya lewat barcode** termasuk produk nonaktif (K-4.3, K-4.7), impor **tidak pernah menghapus** produk (K-4.6)
- [x] Mode duplikat "Perbarui produk yang ada" (default) / "Lewati"; opsi "Buat kategori baru otomatis" (default nyala, kategori dibuat sekali saja)
- [x] Opsi **"Timpa stok dari file" default MATI**; bila aktif, setiap perubahan stok mencatat `stock_movements` (`opname` untuk produk lama, `adjust_in` untuk produk baru berstok awal) dengan note `"Impor Excel: <nama_file>"` (AC-4.8)
- [x] Wizard **layar penuh** 5 langkah (pilih file → membaca → pratinjau → konfirmasi → hasil) dengan indikator langkah, tab `Semua/Baru/Diperbarui/Bermasalah`, ringkasan angka besar, baris pratinjau ber-`AppPill`, CTA bawah tinggi 60
- [x] Dialog konfirmasi pola ganda seperti restore backup, termasuk tombol pintas **"Backup Dulu"**
- [x] Titik masuk ganda: menu ⋮ layar Produk dan Pengaturan → kartu Data (berdampingan dengan `export_section.dart`), keduanya membuka wizard yang sama
- [x] "Unduh Laporan Baris Bermasalah (.xlsx)" berisi nomor baris Excel, isi baris asli, dan alasan Bahasa Indonesia (AC-4.17)
- [x] Seluruh layar baru memakai `context.palette` — dilarang `AppColors.*` (gerbang AC-5.6 dari M7 tetap hijau)
- [x] Test unit tabel-kasus: normalisasi angka & boolean (AC-4.10, AC-4.11), header acak (AC-4.3), duplikat barcode (AC-4.5), mode Perbarui vs Lewati (AC-4.6, AC-4.7), kategori otomatis (AC-4.9), idempotensi re-impor file export (AC-4.2)
- [x] Test atomisitas: error disuntikkan di baris ke-50 dari 100 → **nol** produk masuk (AC-4.15); file rusak/bukan xlsx/terenkripsi → pesan jelas tanpa crash (AC-4.14); file > 5.000 baris ditolak (AC-4.13)
- [ ] Uji manual device fisik: file picker atas file dari WPS/Google Sheets; file 1.000 baris tampil di pratinjau ≤ 15 detik tanpa frame drop (AC-4.12); daftar Produk & badge stok menipis ter-refresh sendiri setelah impor (AC-4.16) — **belum bisa dicentang:** tidak ada device/emulator Android di environment ini. AC-4.16 sudah diuji di tingkat stream Drift (`watchAll` & `watchLowStockCount` memancar sendiri setelah impor); sisanya menuntut HP sungguhan

## Milestone 10 — Sistem Lisensi Offline (Aktivasi Wajib)
> Hasil: aplikasi hanya bisa dipakai setelah diaktifkan dengan kode ter-tanda-tangan yang terikat perangkat — tanpa satu pun panggilan jaringan, dan tanpa pernah menyandera data pengguna.

**Tool generator & tata kelola kunci**

- [x] **Commit terpisah khusus dependency:** tambah `cryptography: ^2.9.0` (dependencies) + `qr: ^4.0.0` & `image: ^4.3.0` (dev_dependencies, hanya untuk tool), lalu `flutter pub get` & **`flutter build apk --release` wajib sukses SEBELUM satu baris kode fitur ditulis**. Ketiganya **murni Dart tanpa modul Android** (PRD §6.7.1) sehingga kelas kegagalan `namespace` M0/M6 tidak berlaku — aturan commit gerbang tetap dijalankan, bukan diasumsikan
- [x] `tool/license_generator.dart` — CLI Dart yang dijalankan penjual, memakai **jalur kode yang sama** dengan verifier aplikasi (K-6.12): `--buat-kunci`, penerbitan (`--device --jenis --nama --catatan`), `--verifikasi <kode> --device <id>`, `--daftar`
- [x] `--buat-kunci`: pasangan kunci Ed25519 ditulis ke `~/.kasir-warung/license_ed25519.key` (**di luar repo**, menolak menimpa kunci yang sudah ada) dan mencetak kunci publik base64 siap tempel ke `lib/core/license/license_keys.dart`
- [x] Penerbitan memvalidasi **karakter cek kode perangkat lebih dulu** (salah ketik ketahuan sebelum kode diterbitkan), lalu memperingatkan bila kode perangkat itu **sudah pernah dapat trial** (baca `lisensi-terbit.csv`) — mitigasi tunggal untuk risiko trial berantai (PRD §6.7.3)
- [x] Keluaran penerbitan: kode teks 120 karakter terkelompok 5, berkas QR PNG (`qr` + `image`), dan satu baris di `lisensi-terbit.csv` (tanggal · kode perangkat · jenis · kedaluwarsa · nama · catatan)
- [x] `.gitignore` menutup `*.key`, `*.pem`, `lisensi-terbit.csv`; `docs/laporan-m10.md` §Tata Kelola Kunci memuat tata kelola PRD §6.7.2 (cadangan ≥ 2 tempat luring, akibat kunci hilang vs bocor, prosedur rotasi), dan `--buat-kunci` mencetak ringkasannya langsung di terminal
- [x] Aplikasi memuat **daftar** kunci publik tepercaya (`List<String>`), bukan satu kunci — rotasi tidak mengubah format token maupun alur verifikasi (AC-6.20). Kunci **uji** hanya masuk daftar saat build debug sehingga compiler AOT membuangnya dari build release (diverifikasi di AC-6.19). **Catatan pelaksanaan:** penjaganya bukan `kDebugMode` dari `package:flutter/foundation.dart` melainkan `const bool.fromEnvironment('dart.vm.product')` — `lib/core/license/license_keys.dart` wajib tetap murni Dart agar `tool/license_generator.dart` bisa mengimpornya (K-6.12)

**Verifikasi & model domain**

- [x] `lib/core/license/` — **murni Dart, tanpa dependency Flutter/platform**: `LicensePayload` (9 byte, PRD §6.3.D), enkode/dekode **Crockford Base32** (terima huruf kecil, `I`/`l`→`1`, `O`→`0`, abaikan `-`/spasi, awalan `KW1-` opsional), CRC-16, dan `LicenseVerifier` (Ed25519 atas `"KASIRWARUNG-LICENSE-v1" || 0x00 || deviceId || muatan`)
- [x] Hasil verifikasi berupa **tipe kesalahan yang berbeda-beda**, bukan satu `false`: `salahKetik` (CRC gagal, K-6.7) · `perangkatLain` (petunjuk perangkat cocok tapi tanda tangan tidak, atau sebaliknya) · `tidakSah` · `versiTerlaluBaru` (AC-6.21) — setiap tipe punya pesan Bahasa Indonesia sendiri
- [x] **Vektor uji tetap** di `test/fixtures/license_vectors.dart` (9 kode beku, di-commit) dengan pasangan kunci **uji** yang di-commit: ≥ 6 kode (trial/lifetime/tahunan × sah/kedaluwarsa) + kode perangkat-lain + kode versi-baru; seluruh unit test berjalan **tanpa perangkat & tanpa jaringan** (AC-6.8)
- [x] Unit test tabel-kasus: satu karakter diubah pada **seluruh 120 posisi** → selalu `salahKetik` (AC-6.6); muatan diubah + CRC dihitung ulang → selalu ditolak dan **tidak pernah** sebagai `salahKetik` (AC-6.7; byte petunjuk perangkat menghasilkan `perangkatLain`, sisanya `tidakSah`); normalisasi masukan (AC-6.9)
- [x] Kode perangkat: MethodChannel sendiri di `MainActivity.kt` yang sudah ada (`Settings.Secure.ANDROID_ID`) → `SHA-256("kasirwarung.device.v1|" + SSAID)` → 45 bit → Crockford Base32 9 karakter + **1 karakter cek berbobot posisi**, ditampilkan `KW-XXXXX-XXXXX` (K-6.5). Nol dependency platform baru; `android_id` hanya cadangan
- [x] Penanganan SSAID cacat/tak terbaca (`9774d56d682e549c`): pengenal acak dibangkitkan sekali & disimpan di `shared_preferences`, dengan konsekuensinya dinyatakan di UI bantuan (PRD §6.3.C)

**Penyimpanan, keadaan & gerbang**

- [x] Status lisensi **hanya** di `shared_preferences` — `license_token`, `license_activated_at`, `license_last_seen_at`, `license_device_id_fallback` (K-6.1). **Dilarang** menulis apa pun ke tabel `settings`/database; `schemaVersion` tetap **1**
- [x] Jenis/tanggal/kedaluwarsa/masa tenggang **tidak disimpan terpisah** — diturunkan ulang dengan memverifikasi token di setiap *cold start* (satu sumber kebenaran)
- [x] `LicenseState` enam keadaan PRD §6.3.E (`belumAktif` · `aktif` · `akanBerakhir` · `masaTenggang` · `kedaluwarsaTahunan` · `kedaluwarsaTrial`) + `licenseStatusProvider`; token dibaca & diverifikasi **sebelum `runApp()`** agar frame pertama sudah benar (pola sama dengan tema, AC-5.5)
- [x] Gerbang di **`redirect` go_router sebelum `StatefulShellRoute`** (K-6.9) dengan rute baru `/aktivasi` & `/lisensi-berakhir` di luar shell; urutan gerbang disiapkan untuk M13: **lisensi → masuk → shell**
- [x] Evaluasi ulang saat `AppLifecycleState.resumed`, dan **tidak pernah** memutus alur pembayaran yang sedang berjalan — transaksi berjalan wajib bisa diselesaikan sampai tersimpan (K-6.10, AC-6.18)
- [x] Trial 3 hari (kedaluwarsa absolut) · lifetime tanpa kedaluwarsa · tahunan 365 hari + **masa tenggang 7 hari** yang ikut ditandatangani di muatan (K-6.13); perpanjangan dihitung dari tanggal terbit kode baru (K-6.14); kode **bukan sekali pakai** (K-6.6)
- [x] **Mundur-jam:** `waktuAcuan = max(jam perangkat, license_last_seen_at, MAX(sales.created_at), license_activated_at)`; `license_last_seen_at` diperbarui saat start, resume, dan setiap penjualan tersimpan; seluruh evaluasi masa berlaku memakai `waktuAcuan` (K-6.8). Banner peringatan bila jam perangkat < acuan − 10 menit, **tanpa** mengunci aplikasi selama masa berlaku belum lewat
- [x] Pembacaan `MAX(sales.created_at)` dijalankan **setelah** database terbuka (di luar jalur frame pertama); penurunan keadaan yang dihasilkannya ditangani sendiri oleh `redirect`

**UI (seluruhnya `context.palette` — dilarang `AppColors.*`)**

- [x] **Layar Aktivasi** `/aktivasi`: `AppIconBadge` kunci `xl` + judul, kartu kode perangkat dengan `AppTextStyles.numeric` besar, tombol "Salin" & "Kirim ke Penjual" (`share_plus` yang sudah ada, teks siap kirim berisi kode perangkat), tiga jalur masuk kode **[Pindai QR] [Tempel] [Ketik]**, satu CTA `buttonHeightLarge` 60, konten dibatasi `maxContentWidth`
- [x] Pindai QR me-*reuse* `mobile_scanner` yang **sudah** dipakai untuk barcode produk — tanpa dependency baru
- [x] Masukan manual berbentuk kelompok karakter (pola visual `pin_keypad.dart`, tapi memakai keyboard sistem: `textCapitalization: characters`, `autocorrect: false`, `enableSuggestions: false`), normalisasi karakter saat diketik, pemisah kelompok otomatis
- [x] Umpan balik verifikasi mengikuti `pin_entry_screen.dart`: tombol **tidak** diganti spinner (dinonaktifkan + baris status "Memeriksa kode…"), kode salah → `AppPill(tone: danger)` dengan **pesan spesifik per tipe kesalahan** + getar + `HapticFeedback.heavyImpact`
- [x] **Layar "Masa coba berakhir"** `/lisensi-berakhir`: `EmptyState` bernada `accent`, kalimat menenangkan ("semua data Anda masih tersimpan aman"), kode perangkat, CTA "Masukkan Kode Aktivasi", **tombol "Cadangkan Data"** yang melewati gerbang PIN bila PIN aktif (K-6.11, AC-6.15)
- [x] **Layar Kasir terkunci** (tahunan setelah tenggang): `EmptyState` **di dalam shell** — navigasi bawah tetap ada & berfungsi; Riwayat, Laporan, Export Excel, Backup, dan Pengaturan **tetap terbuka** (AC-6.14)
- [x] **Banner** `AppBanner` di layar Kasir: `warning` "berakhir N hari lagi", `danger` menetap "sisa masa tenggang N hari" + tombol "Perpanjang", `info` untuk jam mundur — tidak pernah menutupi bar keranjang atau CTA "Bayar"
- [x] **Kartu "Lisensi" di Pengaturan** (`SettingsCard`, ditempatkan paling bawah): `AppPill` status, jenis lisensi, tanggal aktivasi, tanggal berakhir + sisa hari ("Selamanya" untuk lifetime), kode perangkat + Salin, tombol "Masukkan Kode Baru"

**Uji**

- [x] Test widget/router: seluruh rute (`/kasir`, `/produk`, `/riwayat`, `/laporan`, `/pengaturan`) dialihkan ke `/aktivasi` saat belum aktif, termasuk lewat navigasi langsung — penjagaan di router, bukan hanya UI (AC-6.1)
- [x] Test keadaan dengan **tanggal acuan yang disuntikkan** (bukan menunggu hari berganti): trial hari ke-1/ke-3/ke-4 (AC-6.10), tenggang tahunan hari ke-1/ke-7/ke-8 (AC-6.13, AC-6.14), jam dimundurkan 1 tahun (AC-6.16)
- [x] Test data: trial kedaluwarsa → aktivasi lifetime → jumlah produk/transaksi/pergerakan stok **identik** sebelum vs sesudah (AC-6.12); lisensi berakhir saat keranjang berisi → transaksi tetap tersimpan (AC-6.18)
- [x] Test backup: file backup dari perangkat berlisensi **tidak memuat jejak lisensi** (periksa isi tabel `settings` pada file), dan restore di perangkat lain tetap meminta aktivasi (AC-6.17)
- [x] Gerbang rilis: `git grep` pola kunci privat + verifikasi `.gitignore`, dan kunci uji **tidak** ada di build release (AC-6.19)
- [ ] Uji manual device fisik: **aktivasi sukses** lewat ketiga jalur (pindai QR, tempel, ketik manual) dan waktunya diukur (≤ 30 detik QR/tempel, ≤ 2 menit ketik manual — PRD §11.1); **kode salah ketik** memberi pesan "salah ketik", bukan "tidak sah"; **kode perangkat lain** ditolak dengan pesan yang benar
- [ ] Uji manual device fisik: **trial kedaluwarsa** (majukan tanggal HP) mengunci dengan layar ajakan beli dan "Cadangkan Data" tetap menghasilkan file yang bisa di-restore; **reinstall tidak me-reset trial** (uninstall → install APK release bertanda tangan sama → kode perangkat sama, kode trial lama tetap kedaluwarsa — AC-6.3, AC-6.11)
- [ ] Uji manual device fisik: mundurkan jam HP 1 tahun → sisa masa berlaku tidak bertambah + banner jam mundur tampil; ukuran APK release tetap < 40 MB dan cold start < 3 detik (AC-6.22)

> **Catatan M10 — item yang belum dicentang.** Tiga item terakhir butuh perangkat Android fisik + APK release yang ditandatangani kunci rilis sebenarnya (kode perangkat APK debug berbeda dengan APK release), jadi tidak bisa diselesaikan dari lingkungan pengembangan ini. Semuanya sudah punya padanan otomatis yang berjalan tanpa perangkat: gerbang router & tiga jalur masuk kode (`license_router_gate_test.dart`, `license_activation_flow_test.dart`), kedaluwarsa trial/tenggang & mundur-jam dengan tanggal acuan yang disuntikkan (`license_status_test.dart`), dan penguncian yang tidak pernah memutus transaksi (`license_mid_transaction_test.dart`). Yang tersisa murni verifikasi perangkat keras: SSAID bertahan melewati uninstall–reinstall (AC-6.3/AC-6.11), waktu aktivasi nyata (PRD §11.1), pemindaian QR lewat kamera, serta ukuran APK & cold start di HP (AC-6.22). Dijadwalkan ikut sesi uji-terima M11.

## Milestone 11 — Polish & Rilis v1.1.0 (Tier 1)
> Hasil: APK v1.1.0 siap dipakai, dan jalur migrasi Tier 2 sudah diamankan sebelum skema pernah naik.

- [x] **GERBANG WAJIB — AC-10.2:** `BackupService.validateBackupFile` **membandingkan** `PRAGMA user_version` file backup dengan `schemaVersion` aplikasi (saat ini nilai itu hanya dibaca). File lebih baru → restore ditolak dengan pesan "File backup berasal dari versi aplikasi yang lebih baru. Perbarui aplikasi ini terlebih dahulu." + unit test khusus. **Milestone yang menaikkan `schemaVersion` (M12) tidak boleh dimulai sebelum item ini rilis**, karena hanya versi yang sudah beredar duluan yang bisa menolak backup dari versi berikutnya
- [x] Verifikasi `schemaVersion` masih **1** dan backup v1.0 ↔ v1.1 saling kompatibel penuh dua arah; pengaturan printer ikut terbawa restore tanpa memblokir aplikasi bila printer tidak ada (AC-3.13, AC-10.3)
- [ ] **GERBANG PENJUALAN — M10 wajib tuntas.** Rilis berbayar pertama tidak boleh keluar tanpa gerbang aktivasi: verifikasi sekali lagi bahwa APK release **tidak** memuat kunci uji, tidak ada bypass `kDebugMode` yang tersisa di jalur gerbang, dan alur aktivasi berjalan pada APK release yang **ditandatangani kunci rilis sebenarnya** (kode perangkat dari APK debug berbeda dengan APK release) — *dua bagian pertama TUNTAS & terverifikasi pada APK release (lihat laporan-m11.md §4); bagian ketiga TERBLOKIR: `android/app/build.gradle.kts` masih menandatangani release dengan kunci debug*
- [ ] Terbitkan **kode uji-terima** untuk minimal 2 perangkat nyata lewat `tool/license_generator.dart` (satu trial, satu lifetime), jalankan seluruh alur pembelian dari sisi penjual **dan** pembeli, lalu simpan hasilnya sebagai catatan rilis — *butuh perangkat fisik + keystore rilis*
- [x] Sapu empty state, pesan error Bahasa Indonesia, kontras & target sentuh (≥ 48dp, CTA 52–60dp) pada seluruh layar baru M7–M10
- [ ] Regresi manual seluruh alur PRD v1.0 (checklist §4 & §5 [prd.md](prd.md)) + empat fitur baru, di HP kecil & tablet, pada mode terang **dan** gelap — *daftar uji-terima gabungan siap di laporan-m11.md §6*
- [x] `flutter analyze` bersih; `flutter test` seluruhnya lulus tanpa mengubah ekspektasi test M0–M6
- [ ] Build release APK (+ App Bundle bila ke Play Store), R8 aktif, ukuran < 40 MB, cold start < 3 detik diukur di device fisik — *build & R8 & ukuran TUNTAS (26,9 / 30,8 / 33,3 MB per-ABI); cold start butuh device fisik*
- [ ] Cek metrik keberhasilan PRD §11.1 satu per satu — *metrik yang bisa diukur tanpa perangkat sudah dicek (laporan-m11.md §5); sisanya masuk daftar uji-terima*
- [x] Naikkan `version:` di `pubspec.yaml` ke `1.1.0` dan tag `v1.1.0` — *`version: 1.1.0+2` sudah naik; **tag `v1.1.0` dibuat orkestrator**, bukan agent M11*

## Milestone 12 — Pelanggan & Program Poin (`schemaVersion` 1 → 2)
> Hasil: pelanggan menjadi entitas nyata dengan riwayat & poin; daftar hutang lama otomatis rapi tanpa kehilangan sepeser pun.

- [ ] **Prasyarat:** pastikan v1.1.0 (dengan AC-10.2) sudah dirilis sebelum `schemaVersion` dinaikkan
- [ ] Tabel Drift baru `customers` & `customer_point_entries`, kolom `sales.customer_id`, plus 3 index sesuai PRD §7.5 (`idx_customers_name_nocase` parsial untuk pelanggan aktif, `idx_sales_customer`, `idx_point_entries_customer`)
- [ ] `schemaVersion` 1 → 2 dengan `onUpgrade` **backfill** PRD §7.3.E dalam satu transaksi: `DISTINCT TRIM(customer_name)`, dikelompokkan case-insensitive, ejaan terbanyak menang (seri → paling awal), `customer_id` diisi untuk semua transaksi terkait. `sales.customer_name` **tidak dihapus & tidak diubah** (K-7.1, AC-10.4, AC-10.5)
- [ ] Entity + kontrak `CustomerRepository` + implementasi Drift + provider; key `settings` baru: `points_enabled` (default `0`), `points_rupiah_per_point` (`10000`), `points_value_per_point` (`500`), `points_min_redeem` (`10`)
- [ ] Buku besar poin (K-7.2) dengan tipe `earn` / `redeem` / `void_return` / `adjust` / `merge`; `customers.points` hanyalah cache yang diperbarui **di transaksi DB yang sama**; poin bilangan bulat (K-7.3); **tidak ada poin surut** (K-7.4)
- [ ] Integrasi `SaveSaleUsecase`: poin dihitung dari total **setelah diskon** dan **tidak termasuk** potongan hasil penukaran poin (AC-7.10); berlaku untuk semua metode bayar termasuk hutang (K-7.5)
- [ ] Integrasi `VoidSaleUsecase`: poin ditarik kembali & poin yang sempat ditukar dikembalikan, keduanya sebagai entri ledger terpisah dalam transaksi void yang sama; saldo tidak boleh negatif (dipatok 0 + entri bercatatan jelas)
- [ ] Penukaran poin di sheet pembayaran → **diskon level transaksi** pada `sales.discount` + entri `redeem` (K-7.6); baris "Tukar poin" muncul di struk teks **dan** struk ESC/POS (M8)
- [ ] Pemilih pelanggan menggantikan field teks bebas: bottom sheet dengan pencarian autofocus, baris ≥ 56dp, opsi "Buat pelanggan baru: <ketikan>", wajib untuk hutang (`NamaPelangganWajibException` dipertahankan, AC-7.4), dan **nol tap tambahan** bila pelanggan tidak dipilih (AC-7.5)
- [ ] Layar **Pelanggan** diakses dari tab Laporan (kartu "Hutang Pelanggan" berkembang jadi kartu "Pelanggan"); `debt_list_screen.dart` menjadi filter "Punya hutang" di dalamnya. **Navigasi bawah tetap 5 tab**
- [ ] Detail pelanggan: ringkasan (total belanja, jumlah transaksi, sisa hutang, saldo poin), riwayat belanja berpaginasi (pola `AsyncNotifier` M3), riwayat poin (`AppDataRow` +/−); aksi ubah, nonaktifkan (ditolak bila masih berhutang, AC-7.13)
- [ ] Gabungkan pelanggan (PRD §7.3.D): mode pilih, pratinjau dampak, satu transaksi DB, sumber ditandai nonaktif + `merged_into_id`, **satu arah & tidak bisa dibatalkan** (K-7.7)
- [ ] Pengaturan → kartu "Program Poin" (**default mati**, seluruh UI poin tersembunyi saat mati) + aksi pemeliharaan "hitung ulang saldo dari ledger"
- [ ] Nama pelanggan di detail transaksi menjadi tautan ke profil pelanggan
- [ ] Export Excel mendapat sheet/berkas "Pelanggan & Poin" (nama, no. HP, total belanja, sisa hutang, saldo poin) — AC-7.16
- [ ] Seluruh layar baru memakai `context.palette`; dilarang `AppColors.*`
- [ ] **Test migrasi atas snapshot database v1 nyata** (AC-10.1): `"Bu Ani"` / `"bu ani"` / `"Bu Ani "` → satu pelanggan dengan tiga transaksi (AC-7.1); total hutang sebelum vs sesudah **identik** (AC-7.2); `customer_name` lama tidak berubah setelah rename (AC-7.3)
- [ ] Test invarian: `customers.points` **selalu** sama dengan jumlah entri ledger setelah rangkaian acak jual/void/tukar/gabung (AC-7.11); penggabungan 3 pelanggan tidak menghilangkan entri (AC-7.12); aturan perolehan Rp37.000 → 3 poin, Rp9.999 → 0 poin (AC-7.7); program mati → nol elemen poin di layar mana pun termasuk struk (AC-7.6)
- [ ] Test performa: pencarian pada 2.000 pelanggan < 100 ms (AC-7.14); detail pelanggan dengan 5.000 transaksi tetap mulus (AC-7.15)
- [ ] Uji manual device fisik: alur kasir tunai tanpa memilih pelanggan tidak bertambah satu tap pun; **restore backup v1.0 di perangkat lain → migrasi jalan otomatis & total hutang sama persis**

## Milestone 13 — Multi-User dengan PIN per Kasir (`schemaVersion` 2 → 3)
> Hasil: pemilik tahu siapa yang melayani setiap transaksi, dan kasir tidak bisa melihat laba atau membatalkan transaksi.

- [ ] Tabel Drift baru `users`; `ALTER TABLE` menambah `sales.user_id`, `sales.user_name`, `sales.voided_by_user_id`, `stock_movements.user_id`; index `idx_users_name_nocase` (parsial, aktif saja) & `idx_sales_user` (PRD §8.5)
- [ ] `schemaVersion` 2 → 3, seluruhnya `ADD COLUMN` (O(1) di SQLite, non-destruktif); indikator progres bila pembuatan index > 1 detik
- [ ] Key `settings` baru: `multi_user_enabled` (**default `0`**), `auto_lock_minutes` (`0` = mati), `recovery_code_hash`, `recovery_code_salt`. Key lama `pin_hash`/`pin_salt` **dipertahankan** untuk mode single-user
- [ ] `UserRepository` + reuse `PinHasher` (SHA-256) dengan **salt per pengguna** (K-8.3); tidak ada PIN teks polos di DB maupun `shared_preferences` (AC-8.14). Sesi aktif disimpan sebagai `active_user_id` di `shared_preferences`
- [ ] Alur aktivasi (PRD §8.3.A): PIN global yang sudah ada **otomatis** menjadi PIN akun "Pemilik" (AC-8.2); bila belum ada, buat PIN Pemilik 6 digit
- [ ] **Kode pemulihan 8 karakter** ditampilkan **sekali saja**, disimpan sebagai hash, dengan tombol Salin/Bagikan dan centang wajib "Saya sudah mencatat" (K-8.4, AC-8.3)
- [ ] Layar **Masuk** sebagai rute di luar shell navigasi: kartu pengguna ≥ 64dp (avatar inisial) → keypad PIN me-*reuse* `pin_keypad.dart` / `pin_entry_screen.dart`; judul "Siapa yang bertugas?". Pilih nama dulu, baru PIN (K-8.2, AC-8.15)
- [ ] Dua peran tetap (Pemilik / Kasir) dengan matriks izin PRD §8.3.C — **tidak bisa dikustomisasi** (K-8.1)
- [ ] Penjagaan izin di **lapisan `redirect` go_router sekaligus di UI** (AC-8.4); elemen berisi laba & harga modal **disembunyikan sepenuhnya** untuk Kasir, bukan diburamkan (AC-8.5); Kasir hanya melihat Riwayat hari ini dan tidak bisa void (AC-8.6)
- [ ] Penolakan akses memakai pola `EmptyState` (ikon gembok + kalimat pengarah + tombol "Masuk sebagai Pemilik"), bukan dialog error telanjang
- [ ] "Ganti Kasir" di Pengaturan dan menu ⋮ layar Kasir (satu-satunya tambahan di layar kasir) + chip pengguna aktif di AppBar yang tidak boleh lebih menonjol dari CTA "Bayar"
- [ ] Kunci otomatis opsional (mati / 1 / 5 / 15 menit); **keranjang berjalan tidak pernah dibuang** — hanya ditutupi layar PIN (AC-8.11, AC-8.12)
- [ ] Rate limit: 5 PIN salah → keypad terkunci 30 detik, berlipat sampai maksimal 5 menit, dan **bertahan setelah aplikasi ditutup-buka** (AC-8.10). Tidak ada penghapusan data
- [ ] Jejak pengguna: `user_id` + `user_name` snapshot di setiap penjualan (K-8.6), `user_id` di setiap penyesuaian stok, `voided_by_user_id` saat void; baris `Kasir: <nama>` di struk teks & ESC/POS (M8)
- [ ] Filter "Kasir" di Riwayat dan Laporan (AC-8.9)
- [ ] Reset PIN kasir oleh Pemilik; pemulihan PIN Pemilik lewat kode pemulihan (kode lama hangus, kode baru diterbitkan)
- [ ] Mematikan multi-user: akun kasir dinonaktifkan, PIN Pemilik kembali jadi PIN global, `sales.user_id` historis **tetap dipertahankan** (AC-8.13)
- [ ] Test migrasi 2 → 3 atas snapshot database v2 (AC-10.1); test per peran termasuk percobaan akses rute langsung; test multi-user mati = perilaku v1.0 persis (AC-8.1); test nama pengguna diganti tidak mengubah `user_name` transaksi lama (AC-8.7, AC-8.8)
- [ ] Uji manual device fisik: ganti kasir saat keranjang berisi, kunci otomatis lalu buka kembali, rasa keypad PIN, restore backup schema 3 membawa seluruh akun & meminta masuk (AC-8.16)

## Milestone 14 — Grafik Penjualan di Dashboard
> Hasil: pemilik melihat tren, jam ramai, dan komposisi pembayaran dalam sekali lihat — tanpa satu pun dependency baru.

- [ ] Index `CREATE INDEX IF NOT EXISTS idx_sales_status_created ON sales(status, created_at)` lewat migrasi idempoten (`schemaVersion` **tetap 3**, tidak ada tabel/kolom baru)
- [ ] `ReportRepository.getSalesSeries({start, end, bucket, userId})` & `getHourlyDistribution({start, end, userId})` — **seluruh agregasi di SQL** (K-9.5), memakai `strftime('%Y-%m-%d', created_at / 1000, 'unixepoch', 'localtime')` agar batas hari mengikuti zona perangkat
- [ ] Widget bersama `core/widgets/app_bar_chart.dart` (`Flex`/`CustomPainter`) — **tanpa dependency grafik baru** (K-9.1); area sentuh setiap batang ≥ 48dp walau batangnya lebih sempit (AC-9.8)
- [ ] **Grafik 1 — Tren penjualan:** ember otomatis jam / hari / bulan sesuai panjang rentang, maksimum ~90 batang (K-9.4); peralih Omzet ↔ Laba (`SegmentedButton`); perbandingan periode sebelumnya ("+12% dari 7 hari sebelumnya") berwarna success/danger; tap batang → angka persis; "Lihat transaksi" → Riwayat terfilter; transaksi `voided` **selalu** dikecualikan
- [ ] **Grafik 2 — Jam ramai:** batang 0–23 atas seluruh rentang, batang tertinggi `primary` dan sisanya tonal, jam kosong tetap tampil sebagai batang nol, plus kalimat "Paling ramai: 17.00–18.00 (…)"
- [ ] **Grafik 3 — Komposisi metode bayar:** satu batang horizontal bertumpuk dengan legenda **berlabel teks** + nominal + persentase, memakai alias domain `tunai`/`nonTunai`/`hutang`. **Tanpa pie/donut** (K-9.2, AC-9.10)
- [ ] **Grafik 4 — Produk terlaris:** batang horizontal 5 teratas memakai `getTopProducts` yang sudah ada, tanpa query baru
- [ ] Grafik hidup di tab Laporan di bawah `summary_card.dart` dan **mengikuti pemilih rentang tanggal yang sudah ada** — tanpa pemilih baru (K-9.3); judul kartu kecil, angka besar `moneyLarge`, sumbu Y hanya maksimum & nol, label sumbu X dijarangkan otomatis, animasi masuk 200 ms
- [ ] `EmptyState` untuk rentang tanpa transaksi (bukan grafik kosong atau `NaN`); satu batang & nilai nol semua tetap tampil wajar (AC-9.11)
- [ ] Peralih "Laba" hanya dirender untuk Pemilik saat multi-user aktif; filter "Kasir" memengaruhi seluruh grafik konsisten dengan kartu ringkasan (AC-9.14)
- [ ] Seluruh warna diambil dari `context.palette` — tidak ada hex tetap; uji widget di kedua tema (AC-9.9)
- [ ] Test: jumlah seluruh batang **sama persis** dengan omzet kartu ringkasan untuk rentang yang sama (AC-9.2); aturan ember untuk 1/7/90/400 hari (AC-9.1); `voided` tidak menyumbang tinggi batang (AC-9.3); batas tengah malam WIB/WITA/WIT (AC-9.4); perbandingan periode sebelumnya (AC-9.7); query + render < 300 ms @ 100.000 transaksi (AC-9.5)
- [ ] Uji manual device fisik: keterbacaan di HP 5 inci (batang tidak berdesakan, label dijarangkan) dan tablet landscape (AC-9.12); pertambahan ukuran APK < 1 MB (AC-9.13)

## Milestone 15 — Polish & Rilis v1.2.0 (Tier 2)
> Hasil: APK v1.2.0 siap dipakai dengan rantai migrasi 1→2→3 yang terbukti aman.

- [ ] Pengingat backup > 7 hari ditampilkan sebelum pembaruan yang menaikkan `schemaVersion` (memanfaatkan `last_backup_at` yang sudah ada) — AC-10.6
- [ ] Verifikasi rantai migrasi **1 → 2 → 3 dalam satu jalur** dari snapshot database v1.0 nyata: tidak ada baris hilang, tidak ada `DROP COLUMN`, kegagalan mengembalikan DB ke keadaan semula dengan pesan Bahasa Indonesia (AC-10.3, AC-10.4, AC-10.5)
- [ ] Sapu empty state, pesan error, kontras & target sentuh pada seluruh layar baru M12–M14 di kedua tema
- [ ] Regresi manual: multi-user mati → aplikasi berperilaku **persis** seperti v1.0/v1.1 (AC-8.1); program poin mati → nol elemen poin (AC-7.6); alur kasir inti tetap tiga langkah
- [ ] Regresi manual seluruh alur PRD v1.0 + enam fitur produk v1.1 **dan** sistem lisensi (aktivasi, masa tenggang, layar terkunci) di HP kecil & tablet, mode terang & gelap
- [ ] `flutter analyze` bersih; `flutter test` seluruhnya lulus; cek metrik keberhasilan PRD §11.2 satu per satu
- [ ] Build release APK (+ App Bundle), R8 aktif, ukuran < 40 MB, cold start < 3 detik di device fisik
- [ ] Naikkan `version:` di `pubspec.yaml` ke `1.2.0` dan tag `v1.2.0`

---

## Urutan Ketergantungan

```
Tier 1 — schemaVersion tetap 1, backup v1.0 ↔ v1.1 kompatibel penuh

M7 (Mode Gelap) ──┬──► M8 (Printer)  ──┐
   fondasi tema   ├──► M9 (Impor)    ──┤
                  └──► M10 (Lisensi) ──┴──► M11 (Rilis v1.1.0)

   M8, M9 & M10 bisa PARALEL setelah M7 selesai — ketiganya independen,
   tidak berbagi file selain kartu di layar Pengaturan.

   M10 ditempatkan setelah M8/M9 karena gerbang aktivasi yang terpasang
   lebih awal menghalangi uji manual device fisik pada M7–M9. Yang
   mengikat: M10 SELESAI SEBELUM M11, bukan dikerjakan lebih dulu.

                              ┃
              DUA GERBANG     ┃  (1) GERBANG PENJUALAN: M10 wajib tuntas
              WAJIB DI M11    ┃      sebelum v1.1.0 dirilis — v1.1.0 adalah
                              ┃      rilis berbayar pertama (PRD §2.2).
                              ┃  (2) GERBANG MIGRASI: M11 memuat AC-10.2
                              ┃      (validasi user_version di BackupService).
                              ┃      schemaVersion TIDAK BOLEH naik sebelum
                              ┃      M11 dirilis.
                              ▼

Tier 2 — berurutan, ada migrasi skema

M11 ──► M12 (Pelanggan, 1→2) ──► M13 (Multi-user, 2→3) ──► M14 (Grafik) ──► M15 (Rilis v1.2.0)
                │                          │                    ▲
                │                          └── filter "Kasir" ───┘
                │
                └── baris "Tukar poin" & "Poin Anda" pada struk M8;
                    M13 menambah baris "Kasir: <nama>" pada struk yang sama.
```

Ketergantungan lintas milestone yang perlu diingat:
- **M7 → semua milestone berikutnya:** setiap layar baru M8–M14 wajib memakai `context.palette`; gerbang grep AC-5.6 dijaga tetap hijau.
- **M10 → M11:** tidak ada rilis berbayar tanpa gerbang aktivasi; alur aktivasi wajib diuji pada APK **release** yang ditandatangani kunci rilis sebenarnya, karena kode perangkat pada APK debug berbeda (SSAID terikat kunci penanda tangan).
- **M10 → M13:** urutan gerbang router adalah **lisensi → masuk (login) → shell**; saat M13 menambahkan layar Masuk, `redirect` lisensi tetap yang paling luar (PRD §6.3.F).
- **M8 ↔ M12 & M13:** struk cetak adalah titik temu tiga fitur — poin dan nama kasir menambah baris pada `EscPosReceiptBuilder` yang sama.
- **M13 → M14:** filter "per kasir" pada grafik bergantung pada `sales.user_id`; M14 sengaja ditempatkan setelah M13 agar filter itu tidak dikerjakan dua kali.
- **M12 → M13:** urutan migrasi skema tidak boleh ditukar (1→2 lalu 2→3), karena uji migrasi memakai snapshot versi sebelumnya.

## Definisi Selesai (per milestone)
1. Semua checklist tercentang & fitur berjalan di device nyata (HP + tablet), pada mode terang **dan** gelap.
2. Test unit/widget/DB terkait lulus (`flutter test`) dan `flutter analyze` bersih.
3. Tidak ada regresi pada milestone sebelumnya; seluruh test M0–M6 tetap lulus **tanpa mengubah ekspektasinya**.
4. Tidak ada `AppColors.*` baru di `lib/features/` (berlaku sejak M7 selesai).
5. Untuk milestone yang menaikkan `schemaVersion` (M12, M13): uji migrasi memakai *snapshot* database versi sebelumnya lulus (AC-10.1), migrasi non-destruktif dan berjalan dalam satu transaksi (AC-10.4, AC-10.5).
6. Tidak ada rahasia yang masuk repositori: kunci privat penerbit lisensi, `lisensi-terbit.csv`, dan berkas `*.key`/`*.pem` tidak pernah ter-commit (berlaku sejak M10; diperiksa dengan `git grep` di checklist rilis, AC-6.19).
7. Dokumen ini diperbarui (centang + catatan bila ada perubahan keputusan) dan laporan milestone `docs/laporan-m<N>.md` ditulis mengikuti pola M0–M6.

## Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Dependency printer membuat `flutter build apk --release` gagal (preseden: `flutter_native_splash` di M6, `win32` di M0) | Seluruh Tier 1 tertahan | Dependency masuk **commit terpisah** yang divalidasi build release **sebelum** kode fitur ditulis (M8 item 1); kandidat gagal dicoret, Gradle tidak ditambal; `android.builtInKotlin=false` tidak boleh dihapus |
| `schemaVersion` naik sebelum AC-10.2 beredar | Backup dari versi lebih baru diterima diam-diam oleh versi lama → data rusak | M11 dijadikan **gerbang wajib**: M12 tidak boleh dimulai sebelum v1.1.0 dirilis |
| Backfill pelanggan salah kelompok saat migrasi 1→2 | Total hutang berubah — kepercayaan hancur, ini soal uang | Uji migrasi atas snapshot DB v1 nyata (AC-7.1, AC-7.2), migrasi dalam satu transaksi, pengingat backup sebelum pembaruan |
| Saldo poin melenceng dari buku besar | Sengketa dengan pembeli di depan warung | Ledger sebagai sumber kebenaran (K-7.2), uji invarian saldo = jumlah ledger (AC-7.11), aksi "hitung ulang saldo dari ledger" di Pengaturan |
| Migrasi 351 pemakaian `AppColors` membengkak | M7 molor dan menahan seluruh Tier 1 | M7 dipecah 4 langkah yang masing-masing tetap bisa dibangun & diuji; langkah 1 saja sudah memberi mode gelap yang berfungsi |
| Layar baru M8–M14 menambah utang warna | "Pulau putih" di mode gelap | M7 dikerjakan lebih dulu + gerbang grep AC-5.6 dijaga di Definisi Selesai setiap milestone |
| Fragmentasi firmware printer murah | Struk berantakan di merek tertentu | Uji ≥ 3 merek berbeda, pengaturan lebar kertas & baris feed, hindari perintah eksotis (tanpa auto-cut, tanpa QR native, tanpa raster `GS ( L`) |
| Izin Bluetooth Android 12+ / pertanyaan Play Store soal izin lokasi | Fitur mati diam-diam di HP baru, atau rilis tertahan | Deklarasikan **hanya** `BLUETOOTH_CONNECT`; verifikasi manifest hasil merge pada build release (AC-3.11) |
| Impor Excel masuk sebagian | Katalog rusak & sulit dipulihkan | Satu `db.transaction()` (K-4.5), baris bermasalah tersaring sebelum commit, timpa stok default mati, konfirmasi ganda + "Backup Dulu" |
| **Lisensi sah ditolak aplikasi** (false negative) | Pembeli yang sudah membayar tidak bisa berjualan — kerusakan terparah dari M10 | Vektor uji tetap yang dijalankan tiap `flutter test` (AC-6.8), perintah `--verifikasi` pada generator yang memakai **jalur kode yang sama** untuk dukungan jarak jauh, dan aturan "bila ragu, biarkan pengguna bekerja" (K-6.8). Metrik **0 kasus** di PRD §11.1 |
| **Kunci privat penerbit ter-commit, bocor, atau hilang** | Keygen beredar / tidak bisa lagi menerbitkan kode | `.gitignore` + `git grep` di checklist rilis (AC-6.19), cadangan ≥ 2 tempat luring, dan **daftar** kunci publik tepercaya yang siap dirotasi tanpa mengubah format token (AC-6.20, PRD §6.7.2) |
| **Kode aktivasi 120 karakter dianggap merepotkan** | Pembeli menyerah saat aktivasi — penjualan gagal di langkah terakhir | Tiga jalur masuk dengan ketik manual sebagai **jalan terakhir** (QR lewat `mobile_scanner` yang sudah ada, tempel, ketik), alfabet Crockford tanpa karakter kembar, CRC-16 yang menunjukkan salah ketik alih-alih menuduh kode palsu (K-6.3, K-6.7) |
| **Gerbang lisensi mengunci di tengah transaksi** | Uang pembeli sudah di tangan, transaksi hilang di depan pelanggan | Dilarang keras: evaluasi hanya saat start & resume, transaksi berjalan wajib bisa diselesaikan sampai tersimpan (K-6.10, AC-6.18) |
| **Jam perangkat dimundurkan untuk memperpanjang trial** | Aplikasi dipakai gratis selamanya | Jam monoton dari jam perangkat + tiga saksi tersimpan, termasuk `MAX(sales.created_at)` yang ikut terbawa restore backup (K-6.8, AC-6.16) |
| **Trial berantai lewat permintaan kode trial berulang** | Pemakaian gratis tanpa henti | Kedaluwarsa trial absolut (reinstall tidak mereset, AC-6.11) + `lisensi-terbit.csv` terisi otomatis + generator memperingatkan bila perangkat itu sudah pernah dapat trial. Tanpa server tidak ada mekanisme lain — **diterima secara sadar** (PRD §6.7.3) |
| **Gerbang aktivasi menghalangi pengembangan & uji manual** | M7–M9 melambat, atau muncul godaan menanam bypass yang ikut ke rilis | M10 dikerjakan **setelah** M8/M9; kunci **uji** hanya masuk daftar tepercaya saat `kDebugMode` (dibuang R8 di release) — bukan bypass gerbang, sehingga jalur gerbang tetap teruji di debug (diverifikasi AC-6.19 & checklist M11) |
| Izin multi-user hanya disembunyikan di UI | Karyawan melihat laba atau membatalkan transaksi | Penjagaan di `redirect` go_router **dan** UI, diuji lewat percobaan akses rute langsung per peran (AC-8.4, AC-8.5) |
| Pemilik terkunci dari datanya sendiri | Kehilangan data total | Kode pemulihan offline wajib (K-8.4), ditampilkan sekali dengan centang wajib, disimpan sebagai hash |
| Salah zona waktu pada pengelompokan grafik | Angka grafik beda dengan kartu ringkasan | `'localtime'` eksplisit di SQL + uji batas tengah malam WIB/WITA/WIT (AC-9.2, AC-9.4) |
| Scope membengkak di luar [prd-v1.1.md](prd-v1.1.md) | v1.1/v1.2 molor seperti risiko MVP dulu | Patuh pada daftar "TIDAK termasuk" tiap bab PRD dan §12; usulan baru masuk backlog v1.3, bukan milestone berjalan |

## Catatan Keputusan (diisi selama proyek)

### Milestone 7 — Mode Gelap

- **K-5.7 (baru) — preferensi tema dibaca lewat abstraksi `ThemeModeStore`, bukan `SharedPreferences` mentah.** PRD K-5.2 hanya menetapkan *di mana* nilainya disimpan. Menyuntikkan `SharedPreferences` langsung sebagai provider memaksa setiap widget test menyiapkannya, yang berarti **mengubah 12 test M0–M6** — persis yang dilarang AC-5.12. Providernya karena itu menyediakan `ThemeModeStore`: `SharedPrefsThemeModeStore` di `main()` (nilai sudah dimuat sebelum `runApp()`, AC-5.5) dan `InMemoryThemeModeStore` sebagai default. Efek samping yang disengaja: kalau `main()` lupa meng-override, aplikasi tetap jalan bertema Terang alih-alih crash.
- **Token `onPrimary`, `onAccent`, dan `onSurfaceDark` ditambahkan ke `AppPalette`.** PRD §5.4 menyebut aturannya di catatan tabel ("teks di atasnya = `#06281B`, bukan putih") tapi tidak memberi token. Tanpa token, setiap layar harus mengingat aturan itu sendiri — sumber "pulau putih" berikutnya. `onSurfaceDark` khususnya menutup jebakan halus: `surfaceDark` adalah permukaan **inversi**, jadi teks di atasnya harus ikut terbalik; memakai `ink` di sana menghasilkan SnackBar terang-di-atas-terang di mode gelap.
- **`dangerBorder` & `infoBorder` dipromosikan jadi token palet.** Di v1.0 keduanya nilai mentah yang ditanam di dalam `AppToneColorsX`; mode gelap membutuhkan pasangannya, dan token setengah jalan tidak bisa diuji kontras.
- **Layar pemindai barcode dipaksa `AppTheme.dark()` di KEDUA mode aplikasi.** Chrome-nya mengambang di atas pratinjau kamera yang selalu gelap. Ini bukan pengecualian terhadap mode gelap melainkan penerapannya: warnanya tetap dari `context.palette`, cuma paletnya yang dipilih tetap.
- **Ambang uji kontras (AC-5.8) memuat dua pengecualian eksplisit, bukan satu.** Selain `inkTertiary` yang sudah disebut PRD (ambang dipakai 2.8:1 karena nilai terangnya `#8A928B` = 2.86:1 berasal dari v1.0 dan tidak boleh digeser oleh AC-5.12), `accent` `#D97E27` juga di bawah 3:1 di atas kertas sejak v1.0. Keduanya diselesaikan lewat **aturan pemakaian** yang ikut diuji — `accent` hanya boleh jadi isi, pasangan teksnya `accentText` yang wajib lolos 4.5:1.
- **`AppShadows` diakses lewat `AppShadows.of(context)`; konstanta lamanya ditandai `@Deprecated`** dan pemakaiannya ikut dijaga gerbang otomatis, sejalan dengan K-5.6 untuk `AppTone.colors`.
- **Gerbang AC-5.6 dijadikan test, bukan grep manual.** `test/core/constants/no_hardcoded_colors_test.dart` memindai `lib/features` & `lib/core/widgets` setiap `flutter test`, dengan allowlist berkomentar (saat ini hanya `receipt_widget.dart`) yang panjangnya sendiri dibatasi test. Alasannya: M8–M14 masih menambah banyak layar baru, dan gerbang yang bergantung pada ingatan orang akan bocor.

### Milestone 10 — Sistem Lisensi Offline

- **K-6.16 (baru) — deteksi mode build memakai `const bool.fromEnvironment('dart.vm.product')`, bukan `kDebugMode`.** Rencana M10 menulis "kunci uji hanya masuk daftar saat `kDebugMode`". Tapi `kDebugMode` datang dari `package:flutter/foundation.dart`, sedangkan `lib/core/license/license_keys.dart` **wajib** tetap murni Dart supaya `tool/license_generator.dart` bisa mengimpornya — dan berbagi satu jalur kode antara penerbit & verifikator adalah inti K-6.12. Semantik dan sifat `const`-nya identik; pembuangannya oleh compiler AOT diverifikasi empiris dengan `grep` atas APK release, bukan disimpulkan dari kode (laporan-m10.md §4.4).
- **K-6.17 (baru) — gerbang yang "dimatikan untuk test" adalah KEADAAN yang bisa dibaca, bukan cabang `if (kDebugMode)`.** `licenseBootstrapProvider` bernilai default `LicenseStatus.gerbangDimatikan()` supaya seluruh widget test M0–M9 tetap bisa membangun `KasirApp` tanpa diubah satu baris pun (alasan yang sama persis dengan K-5.7 untuk tema). Bahayanya nyata: kalau `main()` suatu hari berhenti meng-override, APK rilis terbuka lebar dan **tidak ada satu pun test perilaku yang gagal**. Karena itu bendera `gateDisabled` hidup di dalam keadaannya sendiri (mudah di-assert), `revalidate()` menolak menghidupkan gerbang yang sengaja dimatikan, dan `license_bootstrap_wiring_test.dart` menjaga pemasangannya di tingkat sumber: `evaluateLicense` sebelum `runApp()`, ketiga override selalu ada, blok `overrides` tidak boleh dibungkus kondisi apa pun, dan kata `gerbangDimatikan` tidak boleh muncul di `main.dart`.
- **K-6.18 (baru) — rute `/aktivasi` IKUT dialihkan saat `kedaluwarsaTrial`.** Membiarkannya terbuka (bunyi rencana awal) membuat gerbang bisa "nyangkut": layar aktivasi yang tampil karena `belumAktif` bertahan begitu keadaan berubah jadi `kedaluwarsaTrial`, dan pengguna kehilangan tombol "Cadangkan Data" — persis kelonggaran yang K-6.11 wajibkan. Layar aktivasi kini selalu dibuka sebagai halaman **bertumpuk** (`ActivationScreen.show`) dari layar trial berakhir, kartu Lisensi di Pengaturan, dan banner masa tenggang, sehingga pembeli selalu punya jalan kembali.
- **`appRouter` singleton diganti `appRouterProvider`.** `redirect` butuh akses ke keadaan lisensi, dan `go_router` hanya mau mendengarkan `Listenable` — jembatannya `licenseGateProvider`. Bonus yang tidak direncanakan: lokasi navigasi tidak lagi bocor antar `testWidgets` dalam satu proses, yaitu masalah yang dulu memaksa `pin_gate_active_test.dart` & `pin_gate_inactive_test.dart` dipisah ke dua berkas.
- **Gerbang penjualan dipasang di build layar Kasir, BUKAN di `SaveSaleUsecase`.** Konsekuensi langsung K-6.10/AC-6.18: sheet pembayaran hidup di route di atas layar Kasir, jadi transaksi yang sudah berjalan selesai apa adanya dan kunci baru berlaku pada frame berikutnya. Menaruh pemeriksaan di usecase berarti aplikasi menolak menyimpan saat uang pembeli sudah di tangan kasir.
- **Vektor uji dibekukan sebagai konstanta, bukan dibangkitkan ulang tiap test.** Vektor yang dibangkitkan sendiri akan tetap hijau walau format muatan, urutan byte, tabel CRC, atau alfabet Base32 berubah tak sengaja — padahal itu persis perubahan yang merusak kompatibilitas dengan kode yang **sudah** beredar di tangan pembeli.
- **Karakter cek kode perangkat: batasnya ditulis, bukan disembunyikan.** Skema bobot posisi ganjil modulo 32 menangkap **setiap** salah ketik satu karakter, tapi meloloskan pertukaran dua karakter bersebelahan yang nilainya berselisih tepat 16 (batas matematis skema linier modulo 32, ±6% kasus). Diukur di test alih-alih diklaim sempurna; sisa risikonya ditutup perintah `--verifikasi` di sisi penjual.
- **Lokasi kunci penerbit mengikuti PRD §6.3.B (`~/.kasir-warung/`)**, bukan ejaan alternatif `~/.kasir_warung_lisensi/` yang muncul di instruksi milestone. Keduanya bermaksud sama (di luar repo, di home penjual); tool menerima `--dir <path>` bila perlu dipindah.
- **Distribusi WAJIB per-ABI atau App Bundle.** APK gabungan 83,9 MB karena memuat tiga ABI sekaligus; per-ABI menghasilkan 26,9 MB (armeabi-v7a) & 30,8 MB (arm64-v8a), yang barulah memenuhi AC-6.22 < 40 MB. Ini bukan temuan M10 (perilaku lama), tapi baru mengikat sekarang karena AC-6.22 mulai diverifikasi.

### Milestone 9 — Impor Produk dari Excel

- **K-4.8 (baru) — "kolom tidak ada di file" dibedakan dari "sel kosong".** PRD §4.3.A hanya menyebut nilai default per kolom ("kosong = 0", "kosong = `pcs`"). Diterapkan mentah, aturan itu justru merusak kasus yang diwajibkan AC-4.2: file export v1.0 tidak punya kolom `Batas Stok Menipis`, sehingga setiap impor ulang akan menghapus threshold semua produk — diam-diam, tanpa error, dan baru terasa saat badge stok menipis berhenti muncul. `ProductImportParseResult.columns` karena itu mencatat kolom yang BENAR-BENAR ada, dan `importProducts` memakai `Value.absent()` untuk kolom yang tidak ada. Nilai default tetap dipasang persis seperti PRD, tapi **hanya untuk produk baru**.
- **K-4.9 (baru) — baris contoh template ditandai `CONTOH (hapus baris ini)` dan dilewati parser.** Template wajib berisi contoh, tapi pengguna yang lupa menghapusnya akan mengimpor produk fiktif — dan impor tidak pernah bisa menghapus produk (K-4.6), jadi pembersihannya manual satu per satu. Efek samping yang disengaja: template polos yang diimpor apa adanya ditolak dengan pesan "file tidak berisi satu pun baris produk", bukan membuat dua produk palsu.
- **K-4.10 (baru) — exception impor tinggal di `domain/repositories/import_exceptions.dart`, bukan `repository_exceptions.dart`.** Dua alasan: berkas exception lama milik bersama (M8 dikerjakan paralel di sana), dan tipe induk `ImporProdukException` membuat penanganan error cukup mengenali satu tipe alih-alih enam turunannya.
- **K-4.11 (baru) — stok & batas stok yang tidak terbaca hanya PERINGATAN, bukan error.** PRD §4.3.D menyebut error hanya untuk nama & harga jual. Membuang seluruh baris karena kolom yang bahkan tidak wajib akan membuat impor pertama pengguna gagal ratusan baris sekaligus; nilainya dikosongkan dan barisnya tetap masuk.
- **K-4.12 (baru) — parser mengenali alias header di luar 9 header template** (`Nama Barang`, `Harga`, `Harga Beli`, `Stock`, `Unit`, `Stok Minimum`, dst.). Ini melonggarkan bunyi PRD "header harus persis" dengan alasan yang sama seperti normalisasi angka: pengguna yang filenya ditolak karena menulis "Nama Barang" tidak akan menyalahkan filenya, ia akan berhenti memakai fiturnya. Kolom yang tetap tidak dikenal diabaikan diam-diam, jadi risikonya nol.
- **K-4.13 (baru) — pencocokan barcode dibaca ulang per baris DI DALAM transaksi, bukan dari snapshot.** Akibatnya barcode kembar yang lolos sampai ke repository (parser sudah menandainya error, AC-4.5) memperbarui produk yang barusan dibuat alih-alih menabrak partial unique index dan membatalkan seluruh impor. Diuji eksplisit: 31 baris dengan satu barcode kembar → 30 produk, nol kembar.
- **`adjust_in` untuk produk baru hanya dicatat saat opsi "Timpa stok" menyala.** Mengikuti PRD §4.3.F secara harfiah (kedua butirnya berada di bawah "Bila aktif") dan konsisten dengan form produk yang sudah ada — menambah produk berstok awal lewat form pun tidak menghasilkan `stock_movements`. Opsi itu dengan begitu jadi satu saklar yang mengatur seluruh penulisan jejak stok dari impor.
- **Wizard 5 langkah ditampilkan sebagai indikator 3 langkah** (`1 Pilih file · 2 Pratinjau · 3 Selesai`, sesuai PRD §4.7). "Membaca" & "konfirmasi" tidak diberi nomor sendiri: keduanya keadaan sesaat, bukan tempat pengguna berhenti dan memutuskan sesuatu.
- **Titik masuk kedua ditaruh di dalam kartu "Export Excel", bukan kartu Data terpisah.** PRD §4.7 menyebut "kartu Data, berdampingan dengan `export_section.dart`"; membuat kartu baru justru memisahkan dua arah dari satu berkas yang sama (export → edit → import). Tombolnya karena itu masuk ke bawah tiga baris export, dipisah `Divider` + eyebrow **ARAH SEBALIKNYA** supaya tetap terbaca sebagai lawan arah, bukan export keempat. Kedua titik masuk mem-`push` `ProductImportScreen` yang sama (bukan rute go_router: impor alur sekali jalan yang tidak perlu bisa di-deep link).

### Milestone 8 — Printer Thermal Bluetooth 58mm

- **K-3.10 (baru) — byte ESC/POS ditulis sendiri; `Generator` milik `esc_pos_utils_plus` TIDAK dipakai di dalam builder.** `CapabilityProfile.load()` membaca profil printer dari asset lewat `rootBundle`, yaitu dependency platform. Memakainya di `EscPosReceiptBuilder` melanggar K-3.2 secara harfiah dan membuat builder tidak bisa diuji unit tanpa binding Flutter — padahal pengujian penuh tanpa perangkat itulah satu-satunya alasan K-3.2 ada. Builder karena itu memancarkan sendiri enam perintah yang ia butuhkan (`ESC @`, `ESC t 0`, `ESC a`, `ESC E`, `GS ! 0x01`, `GS v 0`). Ini bukan menulis ulang library: PRD §3.7.2 memang **melarang** perintah eksotis, jadi yang dibutuhkan memang cuma segelintir. `esc_pos_utils_plus` tetap dipertahankan sebagai dependency (dikunci PRD §3.7.1) dan menjadi jalur cadangan resmi bila kelak dibutuhkan raster/barcode lebih rumit — dipakai dari lapisan platform, bukan dari builder.
- **Izin `INTERNET` bawaan `print_bluetooth_thermal` dicabut, tapi HANYA di build type `release`.** Package itu mendeklarasikan `BLUETOOTH_SCAN` **dan** `INTERNET` di manifestnya walau jalur kode yang dipakai aplikasi ini tidak pernah memindai maupun menyentuh jaringan. `BLUETOOTH_SCAN` dicabut di `src/main` (AC-3.11). `INTERNET` dicabut di **`android/app/src/release/AndroidManifest.xml`** — bukan di `src/main` — karena build **debug** tetap membutuhkannya untuk hot reload & breakpoint (lihat `src/debug/AndroidManifest.xml`). Tanpa pemisahan ini, menegakkan janji "100% offline" akan mematikan alat kerja pengembangnya sendiri.
- **Logo dimuat lewat `dart:ui` (`instantiateImageCodec`), bukan `package:image`.** Menambah package gambar berarti dependency ketiga di luar dua yang dikunci PRD §3.7.1. Codec bawaan Flutter sudah cukup untuk membaca file & menurunkan lebarnya; pengemasan ke byte `GS v 0` dikerjakan `EscPosRaster` yang murni Dart sehingga ikut bisa diuji unit penuh. Dua batas dipasang sengaja: lebar dipotong ke lebar area cetak (piksel di luar area **tidak dibuang** printer melainkan menggulung ke baris berikutnya dan menghasilkan logo tercabik) dan tinggi dibatasi 240 dot supaya logo salah pilih tidak memuntahkan setengah gulungan kertas.
- **`PrinterException` sengaja TIDAK didaftarkan di `AppErrorMessage`.** Helper itu memakai daftar putih exception domain dan tinggal di `core/utils/`; mendaftarkan `PrinterException` berarti `core/` harus mengimpor `data/` — arah dependensi yang dilarang architecture.md §3. Konsekuensinya mengikat dan didokumentasikan di berkasnya: **setiap** pemanggil wajib menangkap `PrinterException` secara eksplisit, dan yang lupa akan mendapat pesan generik alih-alih pesan berguna.
- **AC-3.7 dijaga TIGA lapis, bukan satu.** (1) tombol dinonaktifkan selama job berjalan — menutup tap ganda biasa; (2) `PrintJobController` menolak bila state sedang berjalan — menutup pemanggilan program, mis. cetak otomatis yang beririsan dengan tap manual; (3) mutex `_busy` di transport — menutup dua layar berbeda yang memanggil bersamaan, dan ini satu-satunya lapis yang benar-benar melindungi soket SPP.
- **Status "Tercetak ✓" diberi umur 1,8 detik lalu kembali ke "Cetak Ulang".** Perayaan yang menetap selamanya berhenti jadi perayaan dan mulai jadi tombol rusak: kasir yang butuh lembar kedua menatap tombol bertulis "Tercetak ✓" dan tidak tahu ia masih boleh ditekan. Timernya disimpan & dibatalkan di `dispose()` — layar yang ditutup tepat setelah struk keluar kalau tidak akan meninggalkan timer hidup yang menyentuh notifier mati.
- **Setelan rinci struk disembunyikan satu tap di balik "Atur Tampilan Struk".** PRD §3.3.E mendaftar tujuh setelan; menaruh semuanya di muka kartu mengubahnya jadi formulir yang menakutkan, padahal enam di antaranya disentuh sekali seumur hidup. Kartu utama menyisakan urutan pertanyaan yang sungguh ditanyakan pemilik warung: printernya mana → keluar sendiri atau tidak → coba dulu.
- **Diagnosis yang perlu diingat: kegagalan build Kotlin `share_plus` "Unresolved reference 'SharePlusPendingIntent'" adalah artefak incremental-compile basi, BUKAN inkompatibilitas package printer.** Ia muncul tepat setelah dependency printer ditambahkan sehingga sangat mudah disalahartikan sebagai mode kegagalan `namespace` yang menghantam proyek ini di M0 & M6. Simbol yang "hilang" berada di file tetangga dalam modul yang sama. Menghapus `build/share_plus` (atau `flutter clean`) lalu membangun ulang langsung sukses. **Aturan: kandidat package hanya boleh dicoret kalau gagal pada pohon build yang bersih.**
- **Pintasan "Buka Pengaturan Bluetooth Android" belum punya penerima `MethodChannel` di sisi Android.** Panggilannya dibungkus `try/catch` sehingga tidak pernah crash, tapi hari ini tidak melakukan apa-apa; panduan 3 langkah di layar tetap lengkap dan bisa dikerjakan manual. Handler Kotlin-nya (satu `Intent(Settings.ACTION_BLUETOOTH_SETTINGS)`) paling wajar dikerjakan bersamaan dengan uji device fisik — masuk checklist M11.

### Milestone 11 — Polish & Rilis v1.1.0

- **`kAppSchemaVersion` sebagai konstanta pustaka, bukan `AppDatabase.schemaVersion`.** Guard AC-10.2 harus tahu versi skema aplikasi **sebelum** koneksi database mana pun dibuka — `BackupService` seluruhnya statis dan sedang menilai apakah file itu layak dibuka sama sekali. Membuka `AppDatabase` untuk membaca satu angka berarti menjalankan `MigrationStrategy` atas file yang justru sedang divalidasi. Konstanta memutus lingkaran itu; `AppDatabase.schemaVersion` sekarang mengembalikannya, dan satu test menjaga keduanya tidak pernah berpisah. Efek untuk M12: menaikkan skema cukup mengubah satu angka, guard backup ikut naik otomatis.
- **Guard AC-10.2 membandingkan `>`, bukan `!=`.** Backup yang lebih LAMA wajib tetap diterima (AC-10.3) — itu inti janji kompatibilitas Tier 1, dan migrasi majunya memang berjalan otomatis lewat `MigrationStrategy` setelah `restoreFrom`. Hanya arah "lebih baru" yang berbahaya, karena Drift tidak punya migrasi mundur. Guard juga ditempatkan **setelah** pemeriksaan tabel wajib, supaya file yang bukan backup Kasir Warung sama sekali mendapat pesan "tabel wajib tidak lengkap" — bukan pesan versi yang menyuruh pengguna memperbarui aplikasi tanpa guna.
- **`ImporProdukException` didaftarkan ke `AppErrorMessage`; `PrinterException` sengaja TIDAK.** Doc `import_exceptions.dart` sudah menjanjikan induknya dikenali, tapi pendaftarannya tidak pernah ada — pesan spesifik M9 berubah jadi generik begitu lewat jalur error umum. Sebaliknya `PrinterException` tetap di luar: mendaftarkannya memaksa `core/` mengimpor `data/`, arah dependensi yang dilarang architecture.md §3. Konsekuensinya sudah ditanggung di tempatnya (setiap pemanggil printer menangkapnya eksplisit dan membaca `.message`), dan alasan itu kini ditulis sebagai komentar di `error_message.dart` supaya tidak "diperbaiki" keliru di M12+.
- **Gerbang AC-5.6 diperluas ke `Color(0x…)` dan `AppTextStyles.*`.** Dua celah yang baru terlihat saat menyapu M8–M10. Yang pertama membuat entri allowlist `receipt_widget.dart` selama ini **mati** — berkas itu memakai `Color(0xFFFFFFFF)`, bukan `Colors.white` — sehingga ia memakan slot allowlist tanpa menjaga apa pun. Yang kedua menutup jalur masuk warna palet terang yang tidak pernah menuliskan `AppColors.`: gaya teks statis yang sudah memanggang `AppColors.ink` di dalamnya.
- **Versi `1.1.0+2`, bukan `1.1.0+1`.** `versionCode` Android wajib naik monoton dan v1.0.0 sudah memakai `+1`; memakainya ulang membuat pembaruan di atas pemasangan lama ditolak sistem.
- **Keystore rilis sengaja TIDAK dibuat oleh agent.** `build.gradle.kts` masih menandatangani release dengan kunci debug, dan itu memblokir dua item checklist M11 (gerbang penjualan bagian ketiga, penerbitan kode uji-terima) — karena kode perangkat SSAID unik per kunci penanda tangan, sehingga kode lisensi yang diterbitkan untuk APK debug tidak akan berlaku setelah penandatanganan rilis. Keystore adalah rahasia jangka panjang yang harus dimiliki, dicadangkan, dan dijaga pemilik: kehilangannya berarti tidak bisa lagi merilis pembaruan untuk pemasangan yang sudah beredar, selamanya. Membuatkannya otomatis lalu meninggalkannya di direktori kerja adalah cara paling rapi untuk kehilangannya. Lihat laporan-m11.md §5.
