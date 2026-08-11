# Kasir Warung

**Aplikasi kasir (POS) offline-first untuk warung, toko kelontong, dan UMKM kecil.**

![Flutter](https://img.shields.io/badge/Flutter-stable%20(3.44.x)-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Version](https://img.shields.io/badge/version-v1.0.0-blue)
![Tests](https://img.shields.io/badge/tests-207%20passing-brightgreen)

---

## Tentang Proyek

Kasir Warung adalah aplikasi Point of Sale yang berjalan **100% offline** — tanpa
server, tanpa cloud, tanpa koneksi internet, tanpa akun/login online. Semua data
(produk, stok, transaksi, laporan) tersimpan lokal di perangkat, dan sepenuhnya
dimiliki penggunanya: bisa di-**export ke Excel** kapan saja dan seluruh database
bisa di-**backup & restore**, termasuk untuk dipindahkan ke perangkat lain.

### Prinsip Produk

1. **Offline penuh** — tidak ada satu pun fitur yang membutuhkan internet.
2. **Sederhana** — bisa dipakai orang awam tanpa training; alur kasir maksimal 3 langkah (pilih barang → bayar → selesai).
3. **Data milik pengguna** — mudah di-export (Excel) dan dipindahkan (file backup).
4. **Cepat** — buka aplikasi langsung siap transaksi.

Dibangun mengikuti [PRD](docs/prd.md) dan [dokumen arsitektur](docs/architecture.md) proyek ini. MVP v1.0.0 (Milestone 0–6) sudah selesai.

---

## Fitur

### Kasir / Transaksi Penjualan (POS)
- Grid/daftar produk dengan pencarian & filter kategori, layout adaptif HP (portrait) dan tablet (dua panel).
- Tambah ke keranjang lewat tap, scan barcode kamera (`mobile_scanner`), atau input manual.
- Item bebas / penjualan cepat untuk barang tak terdaftar (nama & harga diketik langsung).
- Diskon per item (nominal/persen) dan diskon total transaksi.
- Pembayaran **Tunai** (tombol pecahan cepat, kembalian otomatis), **Non-tunai** (QRIS/transfer/kartu — dicatat jenisnya), dan **Hutang/bon** (dengan nama pelanggan).
- Simpan transaksi bersifat atomik: `sales` + `sale_items` + stok + `stock_movements` dalam satu transaksi database.
- Struk digital: ringkasan transaksi, dibagikan sebagai gambar/teks (WhatsApp, dll.).
- Tahan/parkir transaksi (hold) untuk melayani pembeli lain lebih dulu.

### Produk & Stok
- CRUD produk: nama, barcode (opsional & unik), kategori, harga jual, harga modal (opsional), stok, satuan (pcs/kg/liter/dll.).
- CRUD kategori produk.
- Penyesuaian stok manual (masuk / keluar / opname) dengan catatan alasan, tercatat sebagai audit trail (`stock_movements`).
- Peringatan stok menipis dengan threshold per produk atau default global (bisa diatur di Pengaturan), lengkap dengan badge & daftar tersendiri.
- Riwayat pergerakan stok per produk.

### Riwayat Transaksi
- Daftar transaksi dengan filter tanggal, metode bayar, dan status, mendukung data besar lewat pagination.
- Detail transaksi lengkap (item, qty, harga, diskon, total, pembayaran, kembalian) + share ulang struk.
- Pelunasan hutang/bon.
- Void/batalkan transaksi — stok dikembalikan otomatis, transaksi ditandai batal (tidak dihapus).

### Laporan
- Dashboard ringkasan harian: omzet, jumlah transaksi, laba kotor, penjualan per metode bayar.
- Laporan rentang tanggal dengan preset (hari ini, kemarin, 7 hari, bulan ini, custom).
- Produk terlaris (berdasarkan qty & nilai).
- Daftar hutang pelanggan yang belum lunas.
- Seluruh agregasi dihitung di SQL (bukan di Dart) agar tetap cepat pada skala data besar.

### Export & Backup
- Export ke Excel (.xlsx): daftar produk + stok, riwayat transaksi per rentang tanggal (2 sheet: header & detail item), dan laporan penjualan — diproses di isolate agar UI tidak macet, lalu langsung bisa dibagikan.
- Backup penuh: satu file database (`.db`) berisi seluruh data, untuk disimpan atau dibagikan.
- Restore: pilih file backup → validasi → seluruh data kembali (dipakai juga untuk pindah perangkat), dengan peringatan & konfirmasi ganda sebelum data lama ditimpa.
- Pengingat lembut untuk backup jika sudah lebih dari 7 hari tidak dilakukan.

### Pengaturan & PIN
- Profil toko (nama, alamat, no. HP) yang tampil di struk.
- Pengaturan threshold default stok menipis.
- Kunci aplikasi dengan PIN 6 digit (set/ubah/hapus, keypad besar) untuk melindungi Laporan, Pengaturan, dan aksi void dari akses karyawan.

---

## Screenshot

> Folder `docs/screenshots/` belum tersedia — tangkapan layar aplikasi akan
> ditambahkan menyusul.

---

## Teknologi & Arsitektur

| Kebutuhan | Pilihan | Alasan singkat |
|-----------|---------|-----------------|
| Framework | Flutter (stable) / Dart 3 | Satu codebase, UI cepat |
| Database | **Drift** (di atas SQLite, mode WAL) | Type-safe, reactive stream query, migrasi terkelola, transaksi ACID |
| State management | **Riverpod** | Sederhana, testable, selaras dengan stream Drift |
| Navigasi | **go_router** | Deklaratif, mendukung layout adaptif & shell navigasi bawah |
| Export Excel | `excel` | Menulis `.xlsx` murni Dart tanpa native dependency |
| Scan barcode | `mobile_scanner` | Berbasis kamera, sepenuhnya on-device |
| File & share | `file_picker`, `share_plus` | Restore backup & bagikan export/struk |
| PIN lock | `shared_preferences` + hash SHA-256 bersalt (`crypto`) | Kebutuhan ringan, tanpa tabel DB tambahan |

Aplikasi mengikuti arsitektur berlapis **presentation → domain → data**:
UI/Riverpod di lapisan presentation, entity & usecase murni di domain, serta
implementasi repository (Drift), export Excel, dan backup/restore di lapisan
data. Detail lengkap skema database, alur data, dan keputusan desain ada di
**[docs/architecture.md](docs/architecture.md)**.

---

## Struktur Folder

```
lib/
├── main.dart
├── app.dart                # MaterialApp, tema, router
├── core/                   # constants, utils (formatter Rupiah/tanggal), widget umum, router
├── data/
│   ├── db/                 # AppDatabase (Drift) + definisi tabel
│   ├── repositories/       # implementasi repository
│   └── services/           # export Excel, backup/restore, struk
├── domain/
│   ├── entities/           # model murni (Product, Sale, dll.)
│   └── repositories/       # kontrak/abstract repository
└── features/
    ├── pos/                 # layar kasir, keranjang, pembayaran
    ├── products/            # CRUD produk & kategori
    ├── inventory/           # stok, penyesuaian, riwayat stok
    ├── transactions/        # riwayat, detail, void, pelunasan hutang
    ├── reports/             # dashboard & laporan
    └── settings/            # profil toko, PIN, backup/restore, export
```

Aturan dependensi: `features → domain ← data`; kode di `features/` tidak
mengakses Drift secara langsung, selalu lewat repository.

---

## Cara Build & Menjalankan

### Prasyarat
- Flutter stable (dikembangkan dengan Flutter 3.44.x / Dart 3.12.x)
- Android SDK dengan target minimal **API 26 (Android 8.0)**
- Device Android fisik atau emulator untuk `flutter run`

### Instalasi & menjalankan (debug)
```bash
flutter pub get
flutter run
```

### Analisis kode
```bash
flutter analyze
```

### Menjalankan test
```bash
flutter test
```

### Build APK release (per-ABI, direkomendasikan untuk instalasi langsung)
```bash
flutter build apk --release --split-per-abi
```
Menghasilkan 3 file APK terpisah per arsitektur (`armeabi-v7a`, `arm64-v8a`,
`x86_64`), masing-masing di bawah 40 MB (contoh build rilis: 25,6 MB /
29,6 MB / 32,0 MB).

### Build App Bundle (untuk distribusi via Play Store)
```bash
flutter build appbundle --release
```

> **Catatan signing:** build release saat ini masih memakai **debug signing
> key** bawaan template Flutter (cukup untuk uji internal/`flutter run
> --release`). Untuk distribusi publik lewat Play Store, pemilik proyek perlu
> membuat dan mengonfigurasi **keystore rilis miliknya sendiri** — Play Store
> menolak APK/AAB yang ditandatangani dengan debug key.

---

## Testing

Proyek ini memiliki **207 test otomatis** (unit, widget, dan database) yang
mencakup: usecase domain (perhitungan total/diskon/kembalian, generate
invoice, mutasi stok), test database Drift in-memory (transaksi atomik,
void, migrasi skema), widget test end-to-end alur kasir (tunai, hutang,
void) lewat UI sungguhan, serta test performa (pencarian produk pada 5.000
produk, agregasi laporan pada 50.000 transaksi).

```bash
flutter test
```

---

## Dokumentasi

| Dokumen | Isi |
|---------|-----|
| [docs/prd.md](docs/prd.md) | Product Requirements Document — ruang lingkup, user stories, kebutuhan non-fungsional |
| [docs/architecture.md](docs/architecture.md) | Arsitektur, skema database, desain fitur kunci, state management |
| [docs/plan.md](docs/plan.md) | Rencana pengerjaan per milestone (tracker progres & catatan keputusan) |
| [docs/laporan-m0.md](docs/laporan-m0.md) | Laporan Milestone 0 — inisialisasi proyek |
| [docs/laporan-m1.md](docs/laporan-m1.md) | Laporan Milestone 1 — produk & kategori |
| [docs/laporan-m2.md](docs/laporan-m2.md) | Laporan Milestone 2 — kasir (POS) inti |
| [docs/laporan-m3.md](docs/laporan-m3.md) | Laporan Milestone 3 — non-tunai, hutang, riwayat, void |
| [docs/laporan-m4.md](docs/laporan-m4.md) | Laporan Milestone 4 — stok & laporan |
| [docs/laporan-m5.md](docs/laporan-m5.md) | Laporan Milestone 5 — export Excel, backup/restore, Pengaturan |
| [docs/laporan-m6.md](docs/laporan-m6.md) | Laporan Milestone 6 — polish & rilis v1.0.0 |

---

## Roadmap Post-MVP

Fitur berikut secara eksplisit di luar cakupan MVP, sudah dipertimbangkan di
arsitektur, dan direncanakan untuk fase berikutnya:

- Cetak struk ke printer thermal Bluetooth (58mm)
- Import produk dari Excel
- Multi-user dengan PIN per kasir
- Grafik penjualan di dashboard
- Mode gelap
- Manajemen pelanggan lebih lengkap (poin, riwayat belanja)

---

## Status Proyek

**MVP v1.0.0 selesai** — seluruh Milestone 0–6 sudah diimplementasikan,
`flutter analyze` bersih (0 issue), dan seluruh 207 test lulus. Build APK
release (per-ABI) dan App Bundle sudah berhasil dibuat.

Beberapa hal masih menunggu **uji manual di device fisik** sebelum rilis
publik (lihat detail di [docs/laporan-m6.md §5](docs/laporan-m6.md)):

- **Uji pindah perangkat nyata**: backup di device A → restore di device B → verifikasi data identik.
- **Uji device fisik**: cold start sungguhan, tampilan di HP kecil (5") & tablet (8–11") secara visual, scan barcode kamera, share struk ke aplikasi lain (WhatsApp dll.), file picker restore backup, serta kenyamanan sentuh keypad PIN — semua sudah diverifikasi lewat audit kode dan widget test (viewport disimulasikan), namun belum diamati langsung di perangkat fisik/emulator karena tidak tersedia di lingkungan pengembangan.
- Sebelum distribusi ke Play Store: ganti signing config dari debug key ke keystore rilis milik pemilik produk.
