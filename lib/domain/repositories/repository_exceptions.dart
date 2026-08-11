/// Exception domain untuk pelanggaran aturan bisnis di layer repository.
///
/// `toString()` masing-masing sudah berbahasa Indonesia dan siap ditampilkan
/// langsung ke pengguna (mis. lewat SnackBar), sesuai PRD §6 dan tugas
/// Milestone 1 poin 6 (validasi barcode unik) & poin 5 (validasi kategori
/// masih dipakai), serta Milestone 2 poin 6 (validasi simpan penjualan).
library;

import '../../core/utils/currency_formatter.dart';

/// Dilempar saat barcode yang diisi sudah dipakai produk lain (partial
/// unique index `idx_products_barcode_unique`, lihat app_database.dart).
class BarcodeSudahDipakaiException implements Exception {
  const BarcodeSudahDipakaiException(this.barcode);

  final String barcode;

  @override
  String toString() =>
      'Barcode "$barcode" sudah dipakai produk lain. Gunakan barcode yang '
      'berbeda atau kosongkan.';
}

/// Dilempar saat nama kategori yang diisi (tambah/ubah) sudah dipakai
/// kategori lain (`categories.name` bersifat UNIQUE).
class NamaKategoriSudahAdaException implements Exception {
  const NamaKategoriSudahAdaException(this.name);

  final String name;

  @override
  String toString() => 'Kategori "$name" sudah ada. Gunakan nama lain.';
}

/// Dilempar saat kategori yang ingin dihapus masih dipakai oleh produk.
class KategoriMasihDipakaiException implements Exception {
  const KategoriMasihDipakaiException(this.productCount);

  final int productCount;

  @override
  String toString() =>
      'Kategori tidak bisa dihapus karena masih dipakai oleh $productCount '
      'produk. Pindahkan atau hapus produk tersebut terlebih dahulu.';
}

/// Dilempar saat `SaveSaleUsecase` dipanggil dengan keranjang kosong
/// (plan.md Milestone 2 poin 6).
class KeranjangKosongException implements Exception {
  const KeranjangKosongException();

  @override
  String toString() => 'Keranjang masih kosong. Tambahkan barang terlebih dahulu.';
}

/// Dilempar saat uang tunai yang diterima kurang dari total belanja
/// (sheet pembayaran tunai, plan.md Milestone 2 poin 5).
class UangTidakCukupException implements Exception {
  const UangTidakCukupException({required this.total, required this.dibayar});

  final int total;
  final int dibayar;

  @override
  String toString() {
    final kurang = CurrencyFormatter.format(total - dibayar);
    return 'Uang diterima kurang $kurang dari total belanja.';
  }
}

/// Dilempar saat transaksi hutang tidak menyertakan nama pelanggan (wajib
/// — lihat architecture.md §4, kolom `sales.customer_name`).
class NamaPelangganWajibException implements Exception {
  const NamaPelangganWajibException();

  @override
  String toString() => 'Nama pelanggan wajib diisi untuk transaksi hutang.';
}

/// Dilempar saat `saleId` yang diminta (detail/pelunasan/void) tidak ada
/// di database (plan.md Milestone 3 poin 2 & 3).
class TransaksiTidakDitemukanException implements Exception {
  const TransaksiTidakDitemukanException();

  @override
  String toString() => 'Transaksi tidak ditemukan.';
}

/// Dilempar saat `MarkDebtPaidUsecase` dipanggil untuk transaksi yang
/// bukan hutang belum lunas (mis. sudah lunas, atau bukan transaksi
/// hutang sama sekali) — plan.md Milestone 3 poin 4.
class TransaksiBukanHutangException implements Exception {
  const TransaksiBukanHutangException();

  @override
  String toString() => 'Transaksi ini bukan hutang yang belum lunas.';
}

/// Dilempar saat `VoidSaleUsecase` dipanggil untuk transaksi yang sudah
/// pernah di-void sebelumnya (plan.md Milestone 3 poin 5).
class TransaksiSudahDibatalkanException implements Exception {
  const TransaksiSudahDibatalkanException();

  @override
  String toString() => 'Transaksi ini sudah dibatalkan sebelumnya.';
}
