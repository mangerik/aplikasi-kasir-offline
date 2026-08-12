# Redesign UI — Area Setelan (Pengaturan)

Design language: **"Kertas & Daun"** · Acuan tunggal:
`docs/ui-redesign-foundation.md` · Tanggal: 12 Agustus 2026

Cakupan: `lib/features/settings/**` saja (screens + widgets). Tidak ada
provider, repository, usecase, hashing PIN, atau skema data yang disentuh —
seluruh perubahan bersifat visual & struktur widget.

---

## 1. Masalah desain lama

- Semua seksi tampil sebagai `Card` seragam bertumpuk tanpa pengelompokan:
  layar panjang yang harus dibaca kata per kata untuk menemukan sesuatu.
- Tidak ada jangkar visual — tidak satu pun ikon, pill, atau hierarki nada;
  "Profil Toko" dan "Backup & Restore" punya bobot visual identik.
- Nilai kalah dari label: "Backup terakhir: …" ditulis sebagai satu kalimat
  `bodyMedium` biasa, padahal itulah informasi yang dicari pengguna.
- Layar PIN terasa seperti dialog debug: judul di AppBar, keypad lingkaran
  tonal, dan saat verifikasi keypad DIGANTI spinner sehingga layar melompat.
- State async ditangani ad hoc (`CircularProgressIndicator` telanjang, teks
  `'Gagal memuat …'` tanpa tombol coba lagi).
- Banner pengingat backup dibuat manual dari `Container` + `withValues(alpha:)`
  (melanggar DON'T #4 & #9) dan tidak punya tombol tindak lanjut.

## 2. Perubahan per file

### `screens/settings_screen.dart`
- `StatelessWidget` → `StatefulWidget` (hanya untuk memegang `GlobalKey`
  jangkar scroll; tidak ada state bisnis).
- Setelan dipecah jadi **empat grup bernama**, masing-masing dibuka
  `SectionHeader` ber-eyebrow: `IDENTITAS · Toko Kamu`,
  `OPERASIONAL · Aturan Stok`, `DATA · Cadangan & Ekspor`,
  `KEAMANAN · Kunci Akses`. Judul grup sengaja berbeda dari judul kartu di
  dalamnya supaya tidak ada teks kembar.
- Jarak antar grup `spaceXl` (32), antar kartu dalam satu grup `spaceMs` (12)
  — aturan relasi §4.1.
- `padding` scroll view memakai `screenPadding` + `bottomSafePadding` (96)
  agar kartu terakhir tidak tertutup dock navigasi (§6).
- Banner pengingat sekarang bisa ditindaklanjuti: `onBackup` menggulir ke
  kartu Backup lewat `Scrollable.ensureVisible` (`AppDurations.medium`,
  `easeOutCubic`).
- Ditambah penutup layar `_SettingsFooter` (ikon toko + "Kasir Warung" +
  janji offline) — peak-end rule: akhir layar tetap menenangkan, bukan
  berhenti mendadak.

### `widgets/settings_card.dart`
- Dari `Card` + judul `titleLarge` → `AppCard` (padding `spaceMl`) dengan
  **kepala kartu**: `AppIconBadge` + judul `titleMedium` + keterangan
  `bodySmall`, opsional `trailing` (untuk `AppPill` status), dipisahkan isi
  oleh `Divider` tipis.
- Parameter baru: `icon` (wajib), `tone`, `trailing`. Ikon wajib supaya tiap
  seksi punya jangkar visual saat pengguna scroll cepat.

### `widgets/store_profile_section.dart`
- Field diberi `prefixIcon` (toko / lokasi / telepon) dan hint contoh nama.
- Tombol simpan: dari `FilledButton` kecil rata kanan → `FilledButton.icon`
  selebar kartu setinggi `buttonHeight` (52), label berubah jadi
  "Menyimpan…" saat proses berjalan.
- Loading → `AppLoadingView(compact: true)`; error → `AppErrorView(compact)`
  dengan tombol **Coba Lagi** yang meng-`invalidate` provider.

### `widgets/low_stock_default_section.dart`
- Ditambah **pilihan cepat** `ChoiceChip` (3 / 5 / 10 / 20 unit) di atas
  field — pola "selection over manual input"; chip aktif mengikuti isi field
  secara langsung. Mengetik manual tetap bisa (validasi & penyimpanan tidak
  berubah).
- Field dapat `prefixIcon` + helper text yang menjelaskan akibat angkanya.
- Tombol "Simpan Batas" selebar kartu setinggi `buttonHeight`.
- Loading/error memakai `AppLoadingView`/`AppErrorView` (retry).

### `widgets/export_section.dart`
- Tiga `OutlinedButton` seragam → tiga **baris kartu** `_ExportTile`
  (`AppCard` `surfaceAlt`, radius `radiusMd`) berisi `AppIconBadge` bernada,
  judul `titleSmall`, penjelasan `bodySmall`, dan chevron. Sekarang isi tiap
  export bisa dibedakan tanpa membaca ulang.
- Nada ikon mengikuti §2.5: Produk & Stok = `warning`, Transaksi = `primary`,
  Laporan Penjualan = `success`.
- State sibuk: sub-panel `primary50` berisi spinner + "Menyiapkan file …",
  seluruh tile nonaktif (ikon turun ke `neutral`).

### `widgets/backup_restore_section.dart`
- Status backup terakhir naik jadi informasi utama kartu: sub-panel
  `surfaceAlt` dengan eyebrow `BACKUP TERAKHIR` (kecil) di atas nilainya
  (`titleSmall`) — nilai > label, prinsip §1.1 — plus `AppIconBadge` dan
  `AppPill` jarak waktu ("Hari ini" / "12 hari lalu"), bernada `success` bila
  ≤ 7 hari dan `warning` bila lebih/belum pernah.
- Tombol aksi setinggi `buttonHeight`: `Backup Sekarang` (filled) dan
  `Restore dari File` (outlined), diikuti catatan peringatan kecil bahwa
  restore menimpa seluruh data.
- Indikator sibuk kini menyebut apa yang sedang terjadi ("Menyiapkan file
  backup…" / "Memeriksa file backup…" / "Memulihkan data…") menggantikan
  `LinearProgressIndicator` tanpa konteks.
- Dialog konfirmasi & dialog sukses diberi `AppIconBadge` (danger/success)
  sebagai `icon` — tombol merah pada dialog konfirmasi dipertahankan (satu-
  satunya override warna tombol yang diizinkan §7.3).
- **`FilePicker.pickFiles(...)` TIDAK diubah** sesuai instruksi (fix API
  `file_picker` 12.x), termasuk komentarnya.

### `widgets/backup_reminder_banner.dart`
- `Container` + `BoxDecoration` manual → `AppBanner(tone: AppTone.warning)`
  dengan `title` ("Data belum pernah dicadangkan" / "Waktunya backup lagi"),
  pesan yang menjelaskan risikonya, dan aksi **Backup Sekarang** yang
  melompat ke kartu Backup. Logika ambang 7 hari tidak berubah.

### `widgets/pin_section.dart`
- Kepala kartu jadi indikator status: ikon `lock_rounded` bernada `success`
  saat aktif / `lock_open_outlined` netral saat nonaktif, plus `AppPill`
  "Aktif"/"Nonaktif".
- "Status: AKTIF" (teks datar) diganti daftar area terlindungi sebagai pill
  ber-ikon: **Laporan · Setelan · Batalkan transaksi** — pengguna tahu apa
  yang ia dapat sebelum menekan tombol.
- Saat aktif, "Ubah PIN" & "Hapus PIN" jadi dua tombol sejajar setinggi
  `buttonHeight`; saat nonaktif satu CTA "Aktifkan PIN" selebar kartu.
- Ketiga state (data/loading/error) dibungkus `SettingsCard` yang sama supaya
  kartu tidak "meloncat" ukurannya; error punya tombol Coba Lagi.
- Semua alur `_activate` / `_change` / `_remove` (termasuk konfirmasi ganda
  PIN & pemanggilan usecase) tidak diubah sama sekali.

### `screens/pin_entry_screen.dart`
- Judul dipindah dari AppBar ke badan layar (`headlineMedium`) di bawah
  `AppIconBadge` gembok ukuran `xl` — satu titik fokus, dan menghindari teks
  judul kembar (penting: widget test gerbang PIN memakai
  `find.text('Verifikasi PIN')` dengan `findsOneWidget`).
- Subtitle default "Masukkan 6 digit PIN kamu." bila pemanggil tidak mengisi.
- Saat verifikasi berjalan keypad **tidak lagi diganti spinner** — keypad
  tetap di tempat dalam keadaan nonaktif, dan baris status berubah jadi
  "Memeriksa PIN…". Tidak ada lagi lompatan layout.
- Baris bawah berisi jaminan kepercayaan: "PIN hanya tersimpan di HP ini,
  tidak dikirim ke mana pun."
- Konten dibatasi `maxContentWidth` supaya tetap rapi di tablet.

### `widgets/pin_keypad.dart`
- Tombol: lingkaran `primaryLight` 72dp → **kartu kertas** `surface` radius
  `radiusLg`, tinggi 64, lebar mengikuti grid 3 kolom (`Expanded`), angka
  `headlineLarge` dengan tabular figures, bayangan `AppShadows.level1` yang
  turun ke `level0` + latar `primary50` saat ditekan (`AppDurations.instant`).
- Tombol hapus dibuat "muted" (tanpa permukaan) agar angka tetap jadi fokus,
  dan diberi label semantik.
- Indikator titik: `AnimatedContainer` yang membesar 12 → 16 saat terisi,
  kosongnya bergaris `borderStrong` (bukan lingkaran samar).
- Feedback salah PIN: seluruh baris titik **bergetar** (± 320ms, meredam) dan
  berubah `danger`, ditambah `HapticFeedback.heavyImpact`. Pesan error kini
  tampil sebagai `AppPill(tone: danger)` — teksnya tetap persis
  "PIN salah, coba lagi." agar test lama tetap berlaku.
- `HapticFeedback.selectionClick()` di tiap penekanan angka/hapus, sejalan
  dengan dock navigasi (§6).
- Parameter baru `enabled` untuk mematikan keypad selama verifikasi.

## 3. Keputusan desain

1. **Grup bernama, bukan tumpukan kartu.** Setelan adalah layar "cari lalu
   ubah". `SectionHeader` ber-eyebrow memberi peta yang bisa dipindai dalam
   sekali lihat, dan menjaga jumlah ukuran huruf tetap disiplin (eyebrow,
   titleMedium, bodySmall/bodyMedium, plus angka keypad di layar terpisah).
2. **Setiap kartu punya ikon.** Ikon jauh lebih cepat dikenali daripada judul
   saat scroll — dan `AppIconBadge` bernada sekaligus jadi kanal status
   (hijau = PIN aktif, amber = stok/backup perlu perhatian).
3. **Status backup dinaikkan pangkatnya.** Itu satu-satunya angka di layar
   ini yang benar-benar dicari orang, jadi diperlakukan seperti nominal:
   label kecil, nilai besar, pill jarak waktu bernada.
4. **Pengingat harus punya jalan keluar.** Banner backup diberi tombol yang
   menggulir langsung ke kartunya, bukan sekadar menegur.
5. **Layar PIN = satu titik fokus + zona jempol.** Gembok besar, judul,
   titik, lalu keypad di bagian bawah layar. Keypad tidak pernah menghilang
   supaya jempol tidak kehilangan pegangan saat verifikasi.
6. **Salah PIN terasa, bukan cuma terbaca.** Getar + warna merah pada titik +
   haptic berat membuat kegagalan terbaca dalam sepersekian detik tanpa
   membaca teks — penting saat kasir buru-buru.
7. **Aksen dipakai hemat.** Satu elemen amber menonjol per layar (banner
   pengingat atau pill backup basi), tidak keduanya sekaligus bila backup
   masih segar.

## 4. Pola fondasi yang dipakai

| Pola | Dipakai di |
|---|---|
| `AppCard` (kartu & sub-panel `surfaceAlt`/`primary50`) | Semua seksi, tile export, panel status backup |
| `SectionHeader` (eyebrow + judul + subtitle) | Empat grup di `settings_screen` |
| `AppIconBadge` (`sm`/`md`/`xl`) | Kepala tiap kartu, tile export, panel backup, dialog, layar PIN, footer |
| `AppPill` | Status PIN, area terlindungi, jarak waktu backup, pesan error PIN |
| `AppBanner(tone: warning)` | Pengingat backup |
| `AppLoadingView(compact)` / `AppErrorView(compact, onRetry)` | Profil toko, stok menipis, backup, PIN |
| `AppTone` §2.5 | success = aman/aktif · warning = perlu perhatian · danger = merusak · info = ekspor · neutral = pasif |
| Token `AppSizes` / `AppShadows` / `AppDurations` | Seluruh spacing, radius, elevasi, dan animasi |
| `AppTextStyles.eyebrow` | Label "BACKUP TERAKHIR", "Pilihan cepat" |
| `AppTypography.tabularFigures` | Angka keypad PIN |

Tidak ada hex mentah, `Colors.*`, angka spacing mentah, `Card`,
`BoxShadow` buatan sendiri, gradient/blur, atau `withOpacity` untuk hierarki
teks di dalam area ini.

## 5. Hasil verifikasi

- `flutter analyze lib/features/settings` → **No issues found!** (0 error,
  0 warning).
- `flutter analyze` (seluruh proyek) → 2 error TERSISA di
  `lib/features/reports/screens/reports_screen.dart` (`AppCard(color: …)`
  pada baris 83 & 93) — **di luar scope agent ini**, milik agent area
  Laporan yang sedang bekerja paralel. Tidak ada satu pun isu di
  `lib/features/settings`.
- `flutter test test/features/settings/ test/app_test.dart
  test/features/products/products_screen_low_stock_threshold_test.dart` →
  **8 test lolos, 0 gagal.** Termasuk `pin_gate_active_test` (gerbang PIN:
  tolak PIN salah → terima PIN benar) yang menyentuh langsung keypad &
  layar PIN hasil redesign.
- `flutter test` (penuh) → 206 lolos, 1 gagal:
  `test/features/pos/pos_checkout_flow_test.dart` ("void transaksi dari
  Riwayat") gagal pada `find.byType(ListTile)` di tab **Riwayat** —
  `lib/features/transactions/widgets/history_tile.dart` sudah tidak memakai
  `ListTile` lagi setelah redesign area Transaksi (agent lain, file di luar
  scope ini). Tidak berhubungan dengan perubahan Setelan.
- Catatan waktu pengerjaan: pada pengecekan ulang PALING AKHIR, kedua test
  `pin_gate_*` sempat gagal — bukan karena Setelan, melainkan karena
  `reports_screen.dart` (area Laporan, agent lain) sedang setengah jadi:
  file itu punya 2 error kompilasi dan melempar assertion layout
  (`Row` baris 176 / `Column` baris 163) saat `KasirApp` dirender. Kedua
  test itu membangun SELURUH aplikasi, jadi ikut terseret. Sebelum
  perubahan Laporan tersebut masuk, test yang sama lolos penuh (8/8) dengan
  kode Setelan yang persis sama. Jalankan ulang setelah area Laporan
  selesai.
- Smoke test sementara (dijalankan lalu dihapus, tidak ditinggalkan di repo):
  render `SettingsScreen` + scroll penuh dan `PinEntryScreen` + input 6 digit
  pada layar 360×640 → tanpa overflow/exception, callback PIN menerima
  "123456", pesan "PIN salah, coba lagi." muncul tepat satu kali.

## 6. Catatan untuk agent lain

- `SettingsCard` sekarang MEWAJIBKAN parameter `icon` (dan menerima `tone`
  serta `trailing`). Semua pemanggilnya berada di dalam area Setelan dan
  sudah disesuaikan.
- `PinEntryScreen` tidak lagi menaruh judul di AppBar. Test yang mencari
  judul layar PIN dengan `find.text(...)` tetap mendapat **tepat satu**
  widget.
- `PinKeypad` menerima parameter baru `enabled` (default `true`), sehingga
  pemakaian lama tetap kompatibel.
