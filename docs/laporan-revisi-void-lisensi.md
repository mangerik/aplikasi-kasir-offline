# Laporan Revisi — Celah Void Hutang Lunas & Pengerasan Lisensi

Tanggal: 2026-08-13 · Versi: 1.2.0+3 (tanpa kenaikan versi — perbaikan, bukan fitur)

Revisi atas temuan user saat menguji v1.2.0: **hutang yang sudah dilunasi
masih bisa dibatalkan (void)**. Audit lanjutan atas seluruh logika
transaksi & lisensi menghasilkan empat perbaikan di bawah.

## 1. Hutang lunas tidak bisa di-void lagi (celah utama)

Akar masalah: `markDebtPaid` mengubah status hutang menjadi `'completed'`
— tidak bisa dibedakan dari penjualan tunai oleh pengecekan status saja;
jejaknya hanya `debt_paid_at`. Padahal void atas hutang lunas
mengembalikan stok, menarik poin, dan menghapus omzet dari laporan,
sementara uang pelunasannya sudah diterima fisik → laci kas dan laporan
tidak cocok, dan bisa dipakai menilap uang (terima pelunasan → void).

Dijaga **tiga lapis**, meniru pola AC-8.6:

| Lapis | Berkas | Perilaku |
|---|---|---|
| UI | `sale_detail_screen.dart` | tombol "Batalkan Transaksi" tidak dirender bila `debtPaidAt != null` |
| Domain | `void_sale_usecase.dart` | lempar `HutangSudahLunasException` (baru, `repository_exceptions.dart`) |
| Data | `sale_repository_impl.dart` | pengecekan diulang **di dalam** `db.transaction()` yang sama dengan penulisan |

Hutang **belum lunas** tetap boleh di-void (piutang batal, stok kembali) —
tidak berubah.

## 2. Guard status pada UPDATE pelunasan (anti-race)

`markDebtPaid` kini menulis dengan syarat
`WHERE id = ? AND status = 'debt_unpaid'` dan melempar
`TransaksiBukanHutangException` bila 0 baris berubah. Sebelumnya void yang
menyelip di antara pengecekan usecase dan penulisan repository bisa
"menghidupkan kembali" transaksi voided menjadi completed padahal stoknya
sudah dikembalikan.

## 3. `allowBackup="false"` di AndroidManifest

Prefs berisi identitas perangkat fallback (`license_device_id_fallback`)
dan saksi waktu lisensi. Dengan Auto Backup default Android, keduanya bisa
dikloning ke HP lain (lisensi ganda pada perangkat kategori fallback-SSAID)
atau lahir ulang lewat clear-data (reset trial). `tools:replace` dipakai
supaya menang atas manifest library. Terverifikasi di manifest hasil merge
debug **dan** release. Backup data warung tetap lewat fitur "Cadangkan
Data".

## 4. Aktivasi menolak kode kedaluwarsa saat lisensi masih berlaku

`LicenseController.activate` kini mengevaluasi kode yang lolos tanda
tangan terhadap waktu acuan sebelum menyimpannya: bila hasilnya sudah
kedaluwarsa **dan** lisensi berjalan masih `canSell`, kembalikan
`LicenseRejection.kodeSudahKedaluwarsa` (anggota enum baru + pesan + label
pill) tanpa menyentuh penyimpanan. Sebelumnya pengguna lifetime yang tak
sengaja menempel kode trial lamanya menimpa lisensi bagusnya dan langsung
terkunci. Saat **tidak ada** lisensi berjalan, kode kedaluwarsa tetap
diterima seperti semula — AC-6.11 (trial tidak bisa direset) tidak berubah
arti.

## Test

838/838 lolos (831 lama + 7 baru): 1 usecase void hutang-lunas, 2
repository (void hutang lunas tidak mengubah apa pun; pelunasan tidak
menghidupkan voided), 4 gerbang anti-penurunan lisensi
(`license_activate_downgrade_guard_test.dart`).

## Catatan toolchain (bukan bagian revisi)

Flutter di mesin dev ter-upgrade ke 3.47.0 → `flutter_localizations`
menuntut `intl ^0.20.3`; pin `pubspec.yaml` dinaikkan 0.20.2 → 0.20.3.
`flutter analyze` juga menambahkan blok `analyzer.exclude` standar ke
`analysis_options.yaml` secara otomatis.

## Masih menunggu keputusan user

- Kebijakan poin pada hutang: poin lahir saat transaksi dibuat (belum
  dibayar) dan poin boleh ditukar pada transaksi hutang. Alternatif: poin
  baru diberikan saat pelunasan.
- Pencatatan `debt_paid_by_user_id` (siapa menerima uang pelunasan) —
  butuh migrasi skema 3→4.
