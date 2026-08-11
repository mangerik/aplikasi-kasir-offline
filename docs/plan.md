# Plan — Rencana Pengerjaan Aplikasi Kasir Warung (MVP)

**Versi:** 1.0
**Acuan:** [prd.md](prd.md) · [architecture.md](architecture.md)

Rencana disusun sebagai **milestone berurutan**. Setiap milestone menghasilkan aplikasi yang bisa dijalankan & diuji (incremental). Checklist dicentang selama pengerjaan agar dokumen ini sekaligus menjadi tracker progres.

---

## Milestone 0 — Inisialisasi Proyek
> Hasil: proyek Flutter berjalan dengan fondasi arsitektur.

- [ ] `flutter create` (org id disepakati, mis. `com.erik.kasir`), target Android API 26+
- [ ] Setup struktur folder sesuai `architecture.md` (core/data/domain/features)
- [ ] Tambah dependency: drift, drift_flutter, riverpod (flutter_riverpod), go_router, intl, path_provider, shared_preferences, excel, mobile_scanner, file_picker, share_plus
- [ ] Setup tema dasar: warna, tipografi besar & kontras, tombol ≥ 48dp
- [ ] Formatter Rupiah & tanggal Indonesia di `core/utils`
- [ ] Setup go_router + shell navigasi bawah: **Kasir · Produk · Riwayat · Laporan · Pengaturan**
- [ ] Setup lint (`flutter_lints`), CI opsional
- [ ] Definisi seluruh tabel Drift + `AppDatabase` + migrasi v1 + WAL mode
- [ ] Seed data contoh (mode debug) untuk pengembangan

## Milestone 1 — Produk & Kategori
> Hasil: kelola produk lengkap.

- [ ] Entity + repository + provider produk & kategori
- [ ] Layar daftar produk: pencarian, filter kategori, indikator stok menipis
- [ ] Form tambah/edit produk (nama, barcode via ketik/scan, kategori, harga jual, harga modal, stok awal, satuan, threshold, foto opsional)
- [ ] CRUD kategori (dialog sederhana)
- [ ] Nonaktifkan produk (soft-hide dari kasir) & validasi barcode unik
- [ ] Unit test repository + validasi form

## Milestone 2 — Kasir (POS) inti
> Hasil: transaksi tunai end-to-end.

- [ ] `cartProvider` (tambah/kurang qty, hapus, diskon per item, diskon total, subtotal/total)
- [ ] Layar kasir HP portrait: grid produk + pencarian + bar keranjang bawah
- [ ] Layout tablet dua panel (breakpoint ≥ 600dp)
- [ ] Scan barcode → tambah ke keranjang (mobile_scanner)
- [ ] Item bebas (nama + harga manual)
- [ ] Sheet pembayaran tunai: input uang diterima (tombol pecahan cepat 10rb/20rb/50rb/100rb/uang pas), kembalian otomatis
- [ ] **Usecase simpan penjualan atomik** (sales + sale_items + stok + stock_movements dalam satu transaksi DB) + generator nomor invoice harian
- [ ] Layar sukses + struk digital + share struk (gambar/teks)
- [ ] Hold/parkir & lanjutkan transaksi
- [ ] Unit test: perhitungan keranjang, kembalian, atomisitas simpan (in-memory DB)

## Milestone 3 — Pembayaran non-tunai, hutang, riwayat, void
> Hasil: semua jenis transaksi + riwayat lengkap.

- [ ] Metode non-tunai (dicatat jenisnya) & hutang/bon (wajib nama pelanggan)
- [ ] Layar riwayat transaksi: filter tanggal/metode/status, infinite scroll
- [ ] Detail transaksi + share ulang struk
- [ ] Pelunasan hutang (ubah status, catat waktu lunas)
- [ ] Void transaksi + pengembalian stok atomik + konfirmasi (dan PIN bila aktif)
- [ ] Test: void mengembalikan stok tepat, pelunasan hutang

## Milestone 4 — Stok & Laporan
> Hasil: kontrol stok dan laporan untuk pemilik.

- [ ] Penyesuaian stok (masuk/keluar/opname) + alasan → `stock_movements`
- [ ] Riwayat pergerakan stok per produk
- [ ] Daftar "stok menipis" + badge di tab Produk
- [ ] Dashboard laporan harian: omzet, jumlah transaksi, laba kotor, per metode bayar
- [ ] Laporan rentang tanggal (preset: hari ini, kemarin, 7 hari, bulan ini, custom)
- [ ] Produk terlaris (qty & nilai)
- [ ] Daftar hutang belum lunas (total per pelanggan)
- [ ] Query agregasi di SQL + index; uji dengan data dummy besar (≥ 50k transaksi)

## Milestone 5 — Export Excel, Backup/Restore, Pengaturan
> Hasil: portabilitas data penuh — janji utama produk.

- [ ] Pengaturan profil toko (nama/alamat/telp → tampil di struk)
- [ ] Export Excel: produk+stok, transaksi per rentang (2 sheet), laporan — di isolate, lalu share
- [ ] Uji file terbuka rapi di Excel/WPS/Google Sheets
- [ ] Backup database → satu file `.db`, share/simpan
- [ ] Restore: validasi file, konfirmasi ganda, timpa DB, migrasi bila perlu
- [ ] **Uji pindah perangkat nyata:** backup di device A → restore di device B → data identik
- [ ] Kunci PIN (set/ubah/hapus; lindungi laporan, pengaturan, void)
- [ ] Pengingat backup > 7 hari

## Milestone 6 — Polish & Rilis
> Hasil: APK siap dipakai.

- [ ] Empty state & pesan error Bahasa Indonesia di semua layar
- [ ] Review ukuran sentuh, font, kontras (uji di HP kecil & tablet)
- [ ] Performa: cold start < 3 dtk, pencarian < 100 ms @ 5k produk
- [ ] Ikon app + splash screen + nama "Kasir Warung" (atau nama final)
- [ ] Uji regresi manual semua alur PRD (checklist §4 & §5 PRD)
- [ ] Build release APK (+ App Bundle bila ke Play Store), proguard/R8 ok
- [ ] Tag versi 1.0.0

---

## Urutan Ketergantungan

```
M0 ──► M1 ──► M2 ──► M3 ──► M6
        │      └───► M4 ─────┤
        └────────────► M5 ───┘   (M4 & M5 bisa paralel setelah M2/M3)
```

## Definisi Selesai (per milestone)
1. Semua checklist tercentang & fitur berjalan di device nyata (HP + tablet).
2. Test unit/DB terkait lulus (`flutter test`).
3. Tidak ada regresi pada fitur milestone sebelumnya.
4. Dokumen ini diperbarui (centang + catatan bila ada perubahan keputusan).

## Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|--------|--------|----------|
| Korupsi DB saat crash/restore | Kehilangan data | WAL mode, transaksi atomik, validasi file sebelum restore, dorong backup rutin |
| Scan barcode lambat/gagal di HP low-end | Antrian kasir | Pencarian teks selalu tersedia sebagai jalur utama; scan hanya pelengkap |
| File Excel besar bikin UI freeze | App terasa hang | Jalankan export di isolate + progress indicator |
| Scope membengkak (printer, cloud, dsb.) | MVP molor | Patuh pada daftar Non-Fitur PRD §3.2; fitur baru masuk backlog post-MVP |
| Storage permission Android berbeda antar versi | Backup/export gagal | Pakai SAF (file_picker/share_plus) — tanpa permission storage legacy |

## Catatan Keputusan (diisi selama proyek)
- _(kosong — tambahkan tanggal + keputusan di sini saat ada perubahan)_
