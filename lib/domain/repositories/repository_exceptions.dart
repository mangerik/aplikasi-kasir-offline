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
