import '../entities/product.dart';

/// Kontrak repository Produk.
///
/// Implementasi konkret (Drift) ada di
/// `data/repositories/product_repository_impl.dart`. Layer `features/`
/// HANYA boleh bergantung pada kontrak ini, tidak pernah mengimpor Drift
/// secara langsung (lihat architecture.md §3).
abstract class ProductRepository {
  /// Stream reaktif daftar produk, mendukung pencarian (nama ATAU barcode,
  /// `LIKE`) dan filter kategori.
  ///
  /// `onlyActive` dipakai layar Kasir (Milestone 2) untuk menyembunyikan
  /// produk nonaktif; layar Produk (Milestone 1) menampilkan semua produk
  /// (aktif & nonaktif) dengan penanda.
  Stream<List<Product>> watchAll({
    String? query,
    int? categoryId,
    bool onlyActive = false,
  });

  Future<Product?> getById(int id);

  /// Mencari SATU produk aktif dengan barcode PERSIS sama. Dipakai layar
  /// Kasir untuk hasil scan (plan.md Milestone 2 poin 4). `null` bila tidak
  /// ditemukan atau produk yang cocok sedang nonaktif.
  Future<Product?> getByBarcode(String barcode);

  /// Menambah produk baru, mengembalikan id produk yang baru dibuat.
  ///
  /// Melempar `BarcodeSudahDipakaiException` (lihat repository_exceptions.dart)
  /// bila [barcode] terisi dan sudah dipakai produk lain.
  Future<int> createProduct({
    required String name,
    String? barcode,
    int? categoryId,
    required int sellPrice,
    int? costPrice,
    double stock = 0,
    String unit = 'pcs',
    double? lowStockThreshold,
    String? imagePath,
  });

  /// Memperbarui produk yang sudah ada.
  ///
  /// Melempar `BarcodeSudahDipakaiException` bila [barcode] terisi dan
  /// sudah dipakai produk lain.
  Future<void> updateProduct({
    required int id,
    required String name,
    String? barcode,
    int? categoryId,
    required int sellPrice,
    int? costPrice,
    required double stock,
    required String unit,
    double? lowStockThreshold,
    String? imagePath,
  });

  /// Aktif/nonaktifkan produk. Produk nonaktif tersembunyi dari Kasir tapi
  /// tetap tampil di daftar Produk dengan penanda (plan.md Milestone 1 poin 6).
  Future<void> setActive(int id, bool isActive);
}
