/// Exception domain untuk pelanggaran aturan bisnis di layer repository.
///
/// `toString()` masing-masing sudah berbahasa Indonesia dan siap ditampilkan
/// langsung ke pengguna (mis. lewat SnackBar), sesuai PRD §6 dan tugas
/// Milestone 1 poin 6 (validasi barcode unik) & poin 5 (validasi kategori
/// masih dipakai).
library;

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
