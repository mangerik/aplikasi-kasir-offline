# Laporan Milestone 13 — Multi-User dengan PIN per Kasir (`schemaVersion` 2 → 3)

**Tanggal:** 12 Agustus 2026
**Baseline:** commit `bdb7c93` — M7–M12 tuntas, analyze bersih, 670/670 test lulus
**Acuan:** [plan-v1.1.md](plan-v1.1.md) "Milestone 13" · [prd-v1.1.md §8](prd-v1.1.md) &
[§10](prd-v1.1.md) · [architecture.md](architecture.md) ·
[ui-redesign-foundation.md](ui-redesign-foundation.md)

---

## 1. Ringkasan

M13 menjawab satu pertanyaan yang v1.0 tidak bisa jawab sama sekali:
**siapa yang melayani transaksi ini?** Sekaligus memisahkan apa yang boleh
dilihat karyawan dari apa yang hanya urusan pemilik.

Tiga hal yang menentukan hasilnya:

1. **Migrasi 2 → 3 yang tidak mengunci pemiliknya sendiri.** Pemilik yang
   sudah memasang PIN sejak M5 harus tetap bisa masuk dengan PIN yang
   **sama persis** setelah aplikasinya diperbarui (AC-8.2). Migrasi yang
   lupa memindahkan PIN itu akan menutup warung pada hari update — dan
   tidak ada satu pun pihak yang bisa membukanya dari luar.
2. **Kode pemulihan offline.** Aplikasi ini memang tidak punya akun
   online, jadi "lupa PIN" tanpa kode pemulihan berarti kehilangan data
   total (K-8.4). Kodenya diterbitkan saat penyalaan, ditampilkan sekali,
   disimpan sebagai hash, dan wajib dicentang "saya sudah mencatat".
3. **Izin yang dijaga di lapisan router, bukan di tombol.** Menyembunyikan
   menu Laporan hanya menyembunyikan; `redirect` go_router menolak
   rutenya dari semua jalan masuk sekaligus (AC-8.4), dan itu yang diuji.

Angka kunci:

- `flutter analyze` → **0 issue**.
- `flutter test` → **734/734 lulus**. Baseline 670 utuh; **64 test baru**.
  Enam berkas test lama diubah (dua soal versi skema, empat hanya tanda
  tangan fake repository) — seluruhnya karena kontrak/perilakunya memang
  berubah menurut PRD, dirinci per berkas di §6.
- `flutter build apk --release` → **sukses** (§7).
- `schemaVersion` **2 → 3**, `kAppSchemaVersion = 3`. Guard backup AC-10.2
  ikut naik otomatis tanpa perubahan kode (efek K-M11) dan diuji ulang dua
  arah, termasuk penolakan `user_version = 4`.
- Multi-user **mati secara default** (K-8.5) — tanpa layar Masuk, tanpa
  chip pengguna, tanpa baris "Kasir" di struk, dan gerbang PIN global v1.0
  tetap yang berlaku.
- Navigasi bawah **tetap 5 tab**.

---

## 2. Skema & migrasi

### 2.1 Yang ditambahkan

| Objek | Bentuk |
|---|---|
| `users` | `id`, `name`, `role` (`owner`/`cashier`), `pin_hash`, `pin_salt`, `is_active`, `created_at`, `updated_at`, `last_login_at` |
| `sales.user_id` | `INTEGER NULL REFERENCES users(id)` — `ALTER TABLE ADD COLUMN` |
| `sales.user_name` | `TEXT NULL` — **snapshot** nama kasir (K-8.6) |
| `sales.voided_by_user_id` | `INTEGER NULL REFERENCES users(id)` |
| `stock_movements.user_id` | `INTEGER NULL REFERENCES users(id)` |
| `idx_users_name_nocase` | `UNIQUE ... (name COLLATE NOCASE) WHERE is_active = 1` (parsial) |
| `idx_sales_user` | `(user_id, created_at)` |
| `settings` | `multi_user_enabled` (**default `0`**), `auto_lock_minutes` (`0` = mati), `recovery_code_hash`, `recovery_code_salt` |

Seluruh perubahan tabel lama adalah `ADD COLUMN` — O(1) di SQLite, tidak
menulis ulang tabel (AC-10.4). Key lama `pin_hash`/`pin_salt`
**dipertahankan apa adanya** untuk mode single-user.

### 2.2 Backfill — dan garis yang sengaja ditarik (K-8.8)

PRD §8.3.A menulis pemindahan PIN global sebagai bagian alur "aktifkan
multi-user", sementara AC-8.1 mewajibkan aplikasi berperilaku **persis**
v1.0 selama fiturnya mati. Keduanya dipenuhi dengan memisahkan
*penyiapan* dari *penyalaan*:

| Langkah | Dilakukan migrasi 2 → 3? |
|---|---|
| Membuat tabel `users`, kolom jejak, dua index | ✅ |
| Menyalin `settings.pin_hash`/`pin_salt` → akun `Pemilik` | ✅ (bila PIN global memang ada) |
| Mengisi `settings.multi_user_enabled` | ❌ — tetap kosong, artinya **mati** |
| Menghapus/mengubah key `pin_hash`/`pin_salt` | ❌ — dibiarkan utuh |
| Mengarang `sales.user_id` untuk transaksi lama | ❌ — tetap `NULL` |

Yang berpindah adalah **hash**-nya, bukan PIN-nya: PIN teks polos memang
tidak pernah ada di database (AC-8.14). Warung yang belum pernah memasang
PIN tidak mendapat akun apa pun — akun Pemilik tanpa PIN adalah pintu
terbuka, bukan kemudahan.

### 2.3 Bukti

`test/data/db/migration_v2_to_v3_test.dart` (17 test) berjalan di atas
**snapshot skema v2 nyata** (`test/fixtures/v2_database_fixture.dart`,
DDL disalin dari `sqlite_master` build M12) — bukan `createAll()` dari nol
(AC-10.1):

- prasyarat fixture: `user_version = 2`, belum ada tabel `users` maupun
  kolom `user_id`/`user_name`/`voided_by_user_id`;
- **AC-8.2**: hash & salt akun `Pemilik` sama persis dengan `pin_hash`/
  `pin_salt` fixture — bukan hash baru;
- **AC-8.1**: `multi_user_enabled` tetap kosong setelah migrasi dan key
  PIN lama utuh;
- warung tanpa PIN global → `users` kosong;
- **AC-10.3/10.4**: jumlah baris seluruh tabel sebelum = sesudah; kolom
  lama tetap ada; index M12 & M0 tidak hilang;
- transaksi lama tetap ber-`user_id` `NULL`;
- idempoten: membuka ulang tidak melahirkan Pemilik kedua;
- **rantai penuh v1 → v2 → v3 dalam satu jalur** dari fixture v1 nyata:
  `user_version` berakhir di 3, backfill pelanggan M12 tetap berjalan,
  tidak ada baris hilang;
- **guard backup dua arah**: backup `user_version` 2 diterima & termigrasi,
  `user_version` 4 ditolak dengan kalimat AC-10.2, dan backup schema 3
  membawa seluruh akun beserta perannya (AC-8.16).

---

## 3. Peran, sesi, dan penjagaan izin

### 3.1 Dua peran tetap (K-8.1)

Izin hidup sebagai getter di `UserRoleAccess` (`domain/entities/app_user.dart`)
— satu sumber kebenaran yang dipakai **dua lapis sekaligus**: `redirect`
go_router dan UI. Tidak ada tabel izin yang bisa diedit; peran ketiga tidak
ada.

| Kemampuan | Pemilik | Kasir |
|---|---|---|
| Jual, hold, hutang, pelunasan, cetak | ✅ | ✅ |
| Penyesuaian stok | ✅ | ✅ (tercatat atas namanya) |
| Riwayat | ✅ semua | ✅ **hanya hari ini** |
| Void transaksi | ✅ | ❌ |
| Laporan, laba, harga modal | ✅ | ❌ |
| Tambah/ubah produk & harga | ✅ | ❌ |
| Export, backup, restore | ✅ | ❌ |
| Pengaturan & kelola pengguna | ✅ | ❌ kecuali tema |

`UserRole.fromDb` memetakan nilai `role` asing ke **Kasir**, bukan Pemilik
(K-8.10): ketidaktahuan tidak boleh menjadi izin.

### 3.2 Gerbang router

Urutannya **lisensi → masuk → izin peran → shell**. `licenseRedirect` yang
sudah ada dipanggil lebih dulu; `authRedirect` (fungsi murni, mudah diuji)
menangani sisanya:

- belum masuk → semua rute dialihkan ke `/masuk`, dan `/masuk` sendiri
  tidak dialihkan (tidak "nyangkut");
- sudah masuk → `/masuk` dikembalikan ke `/kasir`;
- Kasir + rute Pemilik (`/laporan**`, `/produk/tambah`, `/produk/:id/ubah`)
  → `/akses-ditolak`;
- Pemilik tidak pernah melihat layar penolakan.

`/pengaturan` sengaja **tidak** masuk daftar rute Pemilik: §8.3.C memberi
Kasir akses tema. Yang berbeda adalah isinya — `SettingsScreen` merender
badan berbeda per peran, bukan layar sama dengan tombol-tombol mati.

Penolakan akses adalah **rute** (`/akses-ditolak`), konsekuensi langsung
dari "penjagaan di lapisan router": redirect harus punya tujuan. Layarnya
memakai pola `EmptyState` (ikon gembok + kalimat pengarah + "Masuk sebagai
Pemilik" + "Kembali ke Kasir"), bukan dialog error telanjang.

### 3.3 Sesi & kunci otomatis

- `active_user_id`, hitungan percobaan PIN, dan cermin `multi_user_enabled`
  hidup di `shared_preferences` lewat abstraksi `SessionStore` — pola yang
  sama dengan `ThemeModeStore` & `LicenseStore` (§8.5, K-8.11). Sesi adalah
  keadaan **perangkat**, bukan data toko: backup dari HP kasir tidak boleh
  "membawa masuk" sesi orang lain saat direstore.
- **Keranjang tidak pernah dibuang.** Baik "Ganti Kasir" (AC-8.11) maupun
  kunci otomatis (AC-8.12) hanya mengubah keadaan sesi; provider keranjang
  tidak disentuh satu baris pun. Layar PIN benar-benar sekadar menutupi.
- `AutoLockScope` membungkus seluruh aplikasi: pointer apa pun menyegarkan
  timer, dan waktu di **latar belakang ikut dihitung** saat aplikasi
  kembali `resumed`. Saat `auto_lock_minutes = 0` (default), tidak ada satu
  timer pun yang dijalankan.
- Rate limit PIN (`core/utils/pin_throttle.dart`): 5 salah → 30 detik,
  berlipat 60 → 120 → 240 → **maksimal 5 menit**, keadaannya tersimpan
  sehingga **bertahan setelah aplikasi ditutup-buka** (AC-8.10). Tidak ada
  penghapusan data.

---

## 4. Kode pemulihan (K-8.4, AC-8.3)

- 8 karakter, abjad Crockford Base32 **tanpa `I`, `L`, `O`, `U`**, ditulis
  berpemisah (`7QK4-M2XB`) — alasan yang sama dengan kode lisensi §6: kode
  ini disalin dengan tangan ke kertas lalu diketik ulang berbulan-bulan
  kemudian.
- Normalisasi memaafkan salah baca tulisan tangan (`O`→`0`, `I`/`L`→`1`)
  dan huruf kecil.
- Disimpan hanya sebagai **hash + salt** (`PinHasher`), tidak pernah teks
  polos. Diuji: hash tersimpan tidak memuat kodenya.
- `RecoveryCodeScreen` menampilkannya sekali dengan tipografi bertabular
  di atas kartu `warning`, tombol Salin & Bagikan, kalimat konsekuensi yang
  terus terang, checkbox wajib "Saya sudah mencatat", dan `PopScope` yang
  menolak ditutup sebelum dicentang.
- Pemulihan berhasil → PIN Pemilik diganti, **kode lama hangus**, kode baru
  diterbitkan & ditampilkan sekali lagi. Kode salah → PIN tidak berubah
  sedikit pun (diuji).
- `ForgotPinScreen` juga mengatakan terus terang apa yang terjadi bila
  kodenya ikut hilang: tidak ada pihak yang bisa mereset dari luar, yang
  bisa diselamatkan adalah datanya lewat file backup.

---

## 5. UI

| Layar / elemen | Isi |
|---|---|
| **Masuk** (`/masuk`, di luar shell) | "Siapa yang bertugas?" → kartu nama besar 64dp (avatar inisial, pil peran) → keypad PIN yang me-*reuse* `pin_keypad.dart` apa adanya. Pemilik mendapat "Lupa PIN?". |
| **Akses Terbatas** (`/akses-ditolak`) | `EmptyState` gembok + dua jalan keluar. |
| **Kode Pemulihan** | Kartu `warning`, angka besar bertabular, Salin/Bagikan, centang wajib. |
| **Pengguna & Akses** (kartu Pengaturan) | `SettingsCard` pola `pin_section.dart`: status Aktif/Nonaktif, pengguna yang sedang bertugas, pemilih kunci otomatis (Mati/1/5/15), "Kelola Pengguna", "Ganti Kasir", "Matikan", "Terbitkan ulang kode pemulihan". |
| **Pengguna** (layar kelola) | Tambah kasir, ubah nama, reset PIN, nonaktifkan/aktifkan. Pengguna tidak pernah dihapus keras. |
| **Chip pengguna aktif** | Di AppBar layar Kasir: kapsul **netral** (bukan beraksen) berisi inisial + nama pendek; tap → Ganti Kasir. Aksen di layar itu tetap milik CTA "Bayar". |
| **Menu ⋮ layar Kasir** | Satu item: "Ganti Kasir" — satu-satunya tambahan multi-user di layar jualan. |
| **Detail transaksi** | Pil "Kasir: `<nama>`" di samping metode bayar; tombol "Batalkan Transaksi" **tidak dirender** untuk Kasir. |
| **Filter Riwayat** | Bagian "KASIR" (chip per pengguna) — hanya dirender saat multi-user menyala. |
| **Laporan** | Baris chip "Semua kasir / per nama" menempel pada pemilih rentang yang sudah ada, tanpa pemilih baru. |
| **Struk** | Baris `Kasir: <nama>` di tiga tempat sekaligus: `ReceiptService` (teks), `EscPosReceiptBuilder` (cetak), `ReceiptWidget` (gambar) — hanya muncul bila transaksinya memang punya nama kasir. |

Seluruh warna lewat `context.palette`, gaya teks lewat `context.textStyles`
— gerbang `no_hardcoded_colors_test.dart` tetap hijau tanpa entri allowlist
baru.

---

## 6. Perubahan pada test lama — dan alasannya

Enam berkas diubah, seluruhnya karena kontrak atau perilakunya memang
berubah menurut PRD. Tidak ada satu pun ekspektasi yang dilonggarkan.

| Berkas | Perubahan | Alasan |
|---|---|---|
| `test/data/db/app_database_test.dart` | `schemaVersion` 2 → **3** | PRD §8.5 & §10: kenaikan skema memang tujuan milestone ini. |
| `test/data/db/migration_v1_to_v2_test.dart` | membuka DB v1 kini berakhir di `user_version` 3; backup "lebih baru" yang ditolak menjadi `user_version` 4; daftar tabel wajib menambah `users` | Rantai migrasi berjalan 1 → 2 → 3 dalam satu jalur. `kAppSchemaVersion + 1` dipakai apa adanya di guard, jadi kalimat testnya yang menyesuaikan. |
| `test/domain/usecases/{adjust_stock,mark_debt_paid,save_sale,void_sale}_usecase_test.dart` | tanda tangan `_Fake*Repository` mengikuti kontrak baru (`userId`, `userName`, `voidedByUserId`) | Perluasan kontrak repository. **Tidak ada** ekspektasi perilaku yang berubah — hanya `@override` yang harus cocok. |

Yang **tidak** perlu diubah, dan itu disengaja: seluruh widget test M0–M12
yang membangun `KasirApp` tetap lulus tanpa satu baris pun disentuh, karena
multi-user mati secara default dan `SessionState.role` jatuh ke Pemilik
dalam mode itu (perilaku v1.0 persis — AC-8.1).

### Test baru (64)

| Berkas | Cakupan |
|---|---|
| `test/data/db/migration_v2_to_v3_test.dart` (17) | Migrasi 2 → 3, backfill PIN, rantai v1→v3, idempotensi, guard backup dua arah, unik nama, Pemilik terakhir, AC-8.15 |
| `test/domain/usecases/multi_user_usecase_test.dart` (8) | Nyalakan/matikan multi-user, AC-8.2, AC-8.3, AC-8.13, kunci otomatis |
| `test/core/utils/pin_throttle_test.dart` (12) | AC-8.10 (termasuk bertahan setelah restart), abjad & normalisasi kode pemulihan |
| `test/features/auth/auth_redirect_test.dart` (13) | AC-8.4 per rute, matriks izin §8.3.C, peran asing, inisial/nama pendek |
| `test/data/repositories/user_trail_test.dart` (9) | AC-8.6, AC-8.7, AC-8.8, AC-8.9, baris "Kasir" di struk (ada & tidak ada) |
| `test/features/auth/login_gate_test.dart` (6) | AC-8.1 (tanpa layar Masuk), alur pilih nama → PIN, PIN salah, AC-8.4 lewat `router.go()` langsung, akun nonaktif |

---

## 7. Verifikasi

| Perintah | Hasil |
|---|---|
| `flutter analyze` | **0 issue** |
| `flutter test` | **734/734 lulus** (baseline 670 + 64 baru) |
| `flutter build apk --release` | **sukses** — 85,5 MB (gabungan 3 ABI) |
| `flutter build apk --release --split-per-abi` | **sukses** — **27,3 / 31,2 / 33,6 MB** (armeabi-v7a / arm64-v8a / x86_64), ketiganya di bawah batas 40 MB |

Distribusi tetap **per-ABI atau App Bundle** (keputusan M10): APK gabungan
memuat tiga ABI sekaligus sehingga melebihi 40 MB, sedangkan per-ABI berada
jauh di bawahnya. Pertambahan dibanding M12 (27,1 / 31,0 / 33,4 MB) adalah
**~0,2 MB per ABI** — seluruhnya kode, karena M13 tidak menambah satu pun
dependency baru: kode
pemulihan memakai `dart:math` + `crypto` yang sudah ada, dan sesi memakai
`shared_preferences` yang sudah dipakai tema & lisensi.

---

## 8. Yang TIDAK selesai (butuh perangkat fisik)

Satu item checklist M13 sengaja **dibiarkan tidak dicentang**:

> Uji manual device fisik: ganti kasir saat keranjang berisi, kunci otomatis
> lalu buka kembali, rasa keypad PIN, restore backup schema 3 membawa
> seluruh akun & meminta masuk (AC-8.16).

Padanan otomatisnya sudah hijau — keranjang yang tidak dibuang dijamin oleh
desainnya (provider keranjang tidak disentuh oleh `signOut`/`lock`), restore
backup schema 3 diuji di `migration_v2_to_v3_test.dart`, dan gerbang masuk
diuji di `login_gate_test.dart`. Tapi tiga hal di daftar itu hanya bisa
dinilai di tangan: **rasa** keypad PIN (getaran, ukuran tombol, jarak
jempol), kunci otomatis yang benar-benar melewati layar mati HP, dan file
backup yang benar-benar berpindah antar perangkat.

---

## 9. Catatan untuk M14

- `sales.user_id` sudah berindeks (`idx_sales_user`) dan
  `ReportRepository.getSummary`/`getTopProducts` sudah menerima `userId`.
  Grafik M14 tinggal meneruskan `reportUserFilterProvider` yang sama supaya
  filter "Kasir" konsisten dengan kartu ringkasan (AC-9.14).
- Peralih "Laba" pada grafik hanya boleh dirender untuk Pemilik: pakai
  `ref.watch(currentRoleProvider).canSeeProfit`, bukan pemeriksaan sesi
  sendiri.
- `schemaVersion` **tetap 3** di M14 (hanya index `idx_sales_status_created`
  lewat migrasi idempoten) — pola `_createUserIndexes()` bisa disalin.
- Bila M14 menambah layar baru di bawah `/laporan`, ia otomatis ikut
  terjaga: `AppRoutes.isOwnerOnly` mencocokkan awalan rute, bukan nama
  layar.
