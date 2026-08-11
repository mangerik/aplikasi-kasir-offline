# PRD — Aplikasi Kasir Warung (Offline-First)

**Versi:** 1.0 (MVP)
**Tanggal:** 11 Agustus 2026
**Platform:** Flutter (Android prioritas utama; iOS menyusul)
**Status:** Draft untuk development

---

## 1. Ringkasan Produk

Aplikasi kasir (Point of Sale) sederhana untuk warung / toko kelontong / UMKM kecil yang berjalan **100% offline**. Semua data (produk, stok, transaksi, laporan) disimpan di penyimpanan lokal perangkat — **tidak ada server, tidak ada cloud, tidak butuh internet, tidak butuh akun/login online**.

Data dapat di-**export ke Excel (.xlsx)** dan seluruh database dapat di-**backup & restore** sehingga bisa dipindahkan ke perangkat lain kapan saja.

### Masalah yang Diselesaikan
- Pemilik warung kecil butuh pencatatan penjualan & stok tapi tidak mau ribet dengan aplikasi kasir berbayar/berlangganan yang butuh internet.
- Pencatatan manual di buku rawan hilang, salah hitung, dan sulit direkap.
- Sinyal internet di banyak lokasi tidak stabil — aplikasi harus tetap jalan penuh tanpa koneksi.

### Prinsip Produk
1. **Offline penuh** — tidak ada satupun fitur yang butuh internet.
2. **Sederhana** — bisa dipakai orang awam tanpa training. Alur kasir maksimal 3 langkah: pilih barang → bayar → selesai.
3. **Data milik pengguna** — mudah di-export (Excel) dan dipindahkan (backup file).
4. **Cepat** — buka aplikasi langsung siap transaksi.

---

## 2. Target Pengguna

| Persona | Deskripsi | Kebutuhan Utama |
|---------|-----------|-----------------|
| Pemilik warung | Mengelola sendiri warungnya, gaptek ringan | Transaksi cepat, lihat untung harian |
| Penjaga toko / kasir | Karyawan yang melayani pembeli | UI besar & jelas, minim salah pencet |
| Pemilik toko kecil | Punya 1–2 karyawan, ingin kontrol stok | Manajemen stok, laporan, export Excel |

**Perangkat target:**
- HP Android (layar 5–7 inci) — mode **portrait/vertical**
- Tablet Android (8–11 inci) — layout menyesuaikan (grid produk lebih lebar, panel keranjang berdampingan)

---

## 3. Ruang Lingkup MVP

### 3.1 Fitur MVP (WAJIB)

#### A. Kasir / Transaksi Penjualan (POS)
- Layar utama kasir: grid/daftar produk dengan pencarian & filter kategori.
- Tambah produk ke keranjang dengan tap; ubah qty (+/−), hapus item.
- Produk tanpa barcode tetap didukung (pilih manual dari daftar).
- Scan barcode via kamera HP untuk menambah produk ke keranjang.
- Input **penjualan cepat / item bebas** (barang tak terdaftar: ketik nama & harga manual).
- Diskon per item (nominal atau %) dan diskon total transaksi.
- Pembayaran: **Tunai** (dengan hitung kembalian otomatis) dan **Non-tunai** (QRIS/transfer — hanya dicatat jenisnya, tanpa integrasi).
- Transaksi hutang/bon (catat nama pelanggan, status belum lunas).
- Simpan transaksi → stok otomatis berkurang.
- Struk digital: tampilkan ringkasan, share sebagai gambar/teks (WhatsApp dll). *(Cetak printer thermal = fase berikutnya, lihat 3.3)*
- Tahan/parkir transaksi (hold) untuk melayani pembeli lain dulu.

#### B. Manajemen Produk & Stok
- CRUD produk: nama, barcode (opsional), kategori, harga jual, harga modal (opsional), stok, satuan (pcs/kg/liter/dll), foto (opsional).
- CRUD kategori produk.
- Penyesuaian stok manual (stok masuk / stok keluar / opname) dengan catatan alasan.
- Peringatan stok menipis (threshold per produk, default global).
- Pencarian & filter produk.
- Riwayat pergerakan stok per produk (kapan masuk/keluar, dari transaksi mana).

#### C. Riwayat Transaksi
- Daftar semua transaksi dengan filter tanggal, metode bayar, status (lunas/hutang).
- Detail transaksi: item, qty, harga, diskon, total, pembayaran, kembalian.
- Pelunasan hutang/bon.
- **Void/batalkan transaksi** (stok dikembalikan otomatis, transaksi ditandai batal — tidak dihapus).

#### D. Laporan
- Ringkasan harian: total penjualan, jumlah transaksi, laba kotor (jika harga modal diisi), penjualan per metode bayar.
- Laporan per rentang tanggal (hari/minggu/bulan/custom).
- Produk terlaris.
- Daftar hutang pelanggan yang belum lunas.

#### E. Export & Backup (Portabilitas Data)
- **Export ke Excel (.xlsx):** daftar produk + stok, riwayat transaksi (per rentang tanggal), laporan penjualan. File disimpan ke storage & bisa langsung di-share.
- **Backup penuh:** satu file berisi seluruh database → simpan ke storage / share.
- **Restore:** pilih file backup → seluruh data kembali. Dipakai juga untuk **pindah perangkat**.
- Peringatan jelas sebelum restore (data lama akan ditimpa).

#### F. Pengaturan
- Profil toko: nama toko, alamat, no. HP (dipakai di struk).
- Mata uang tampil Rupiah (format `Rp12.345`), pembulatan.
- Threshold default stok menipis.
- Kunci aplikasi dengan PIN (opsional, untuk melindungi laporan & pengaturan dari karyawan).

### 3.2 Non-Fitur MVP (EKSPLISIT TIDAK DIBUAT)
- ❌ Sinkronisasi cloud / multi-perangkat realtime
- ❌ Login / akun online
- ❌ Integrasi pembayaran online (QRIS dinamis, e-wallet API)
- ❌ Multi-toko / multi-cabang
- ❌ Pajak kompleks (PPN dsb) — cukup diskon sederhana
- ❌ Manajemen supplier & purchase order lengkap

### 3.3 Fase Berikutnya (Post-MVP, sudah dipertimbangkan di arsitektur)
- Cetak struk ke printer thermal Bluetooth (58mm)
- Manajemen pelanggan lebih lengkap (poin, riwayat belanja)
- Import produk dari Excel
- Multi-user dengan PIN per kasir
- Grafik penjualan di dashboard
- Mode gelap

---

## 4. User Stories (MVP)

1. Sebagai kasir, saya bisa mencari/scan barang dan menyelesaikan pembayaran tunai dalam hitungan detik, agar antrian tidak menumpuk.
2. Sebagai kasir, saya bisa menjual barang yang belum terdaftar dengan mengetik harga manual, agar transaksi tidak terhambat.
3. Sebagai pemilik, saya bisa melihat total penjualan dan laba hari ini dalam satu layar, agar tahu performa warung.
4. Sebagai pemilik, saya bisa menambah/mengubah produk dan stok kapan saja langsung dari HP.
5. Sebagai pemilik, saya mendapat tanda ketika stok barang menipis, agar bisa belanja ulang tepat waktu.
6. Sebagai pemilik, saya bisa mencatat pembeli yang berhutang dan menandai lunas ketika dibayar.
7. Sebagai pemilik, saya bisa meng-export data penjualan ke Excel untuk rekap bulanan.
8. Sebagai pemilik, saya bisa backup seluruh data dan memulihkannya di HP baru tanpa kehilangan apapun.
9. Sebagai pemilik, saya bisa mengunci aplikasi dengan PIN agar karyawan tidak melihat laporan laba.

---

## 5. Alur Utama (Happy Path)

### Alur Transaksi Kasir
```
Buka app → Layar Kasir (default)
→ Cari/scan/tap produk → masuk keranjang
→ (opsional) ubah qty, beri diskon
→ Tap "Bayar" → pilih Tunai/Non-tunai/Hutang
→ Tunai: input uang diterima → kembalian tampil otomatis
→ Tap "Selesai" → transaksi tersimpan, stok berkurang
→ (opsional) Share struk → kembali ke layar kasir kosong
```

### Alur Pindah Perangkat
```
HP lama: Pengaturan → Backup → simpan/share file backup
HP baru: install app → Pengaturan → Restore → pilih file → data lengkap kembali
```

---

## 6. Kebutuhan Non-Fungsional

| Aspek | Target |
|-------|--------|
| Offline | 100% fitur berfungsi tanpa internet, selamanya |
| Performa | Cold start < 3 detik; pencarian produk instan (< 100 ms) pada 5.000 produk |
| Skala data | Minimal 10.000 produk & 100.000 transaksi tanpa degradasi berarti |
| Keandalan | Transaksi bersifat atomik — tidak boleh ada transaksi tersimpan setengah (total & stok wajib konsisten) |
| Ukuran app | APK < 40 MB |
| OS minimum | Android 8.0 (API 26); iOS 13 (jika dirilis) |
| Bahasa | Bahasa Indonesia (default & satu-satunya di MVP) |
| Orientasi | HP: portrait; Tablet: portrait & landscape |
| Aksesibilitas | Tombol & teks besar, kontras baik, target sentuh ≥ 48dp |
| Privasi | Tidak ada data keluar perangkat kecuali user share/export sendiri |

---

## 7. Metrik Keberhasilan MVP
- Transaksi tunai selesai ≤ 10 detik (produk sudah terdaftar).
- 0 kasus data korup/transaksi setengah tersimpan saat pengujian.
- Backup → restore di perangkat lain menghasilkan data 100% identik.
- Export Excel terbuka rapi di Microsoft Excel, WPS, dan Google Sheets.

---

## 8. Asumsi & Batasan
- Satu perangkat = satu toko = satu database.
- Uang hanya Rupiah, tanpa desimal (pembulatan ke rupiah penuh).
- Waktu mengikuti jam perangkat (tidak ada validasi server).
- Pengguna bertanggung jawab menyimpan file backup (app menyarankan backup berkala lewat pengingat lokal).
