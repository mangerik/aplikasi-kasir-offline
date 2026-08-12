import '../entities/product.dart';
import '../entities/product_import.dart';

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

  /// Stream reaktif JUMLAH produk aktif dengan stok menipis — agregasi SQL
  /// `COUNT`, BUKAN dihitung di Dart (plan.md Milestone 4 poin 8), dipakai
  /// badge di tab Produk (plan.md Milestone 4 poin 3).
  ///
  /// Produk dianggap menipis bila `stock <= (low_stock_threshold ??
  /// [defaultThreshold])` — sama persis dengan `Product.isLowStock`, hanya
  /// dihitung di SQL agar cepat tanpa memuat seluruh tabel produk.
  /// [defaultThreshold] adalah fallback global dari `settings` (dibaca
  /// pemanggil, bukan di sini — kontrak ini tidak bergantung pada
  /// `SettingsRepository`).
  Stream<int> watchLowStockCount({required double defaultThreshold});

  /// Stream reaktif daftar produk aktif dengan stok menipis, urut stok
  /// paling sedikit dulu — dipakai layar "Stok Menipis" (plan.md Milestone
  /// 4 poin 3). Lihat [watchLowStockCount] untuk arti [defaultThreshold].
  Stream<List<Product>> watchLowStock({required double defaultThreshold});

  // -------------------------------------------------------------------
  // Impor produk dari Excel (PRD v1.1 §4, Milestone 9).
  // -------------------------------------------------------------------

  /// Memuat SEKALI seluruh data yang dibutuhkan pratinjau impor: peta
  /// barcode -> id produk (aktif MAUPUN nonaktif, K-4.7), nama produk
  /// aktif, dan nama kategori yang sudah ada.
  ///
  /// Dimuat sekaligus, bukan satu query per baris, supaya file 5.000 baris
  /// tidak berubah menjadi 5.000 query (bandingkan `getMovements` yang
  /// juga menghindari N+1).
  Future<ProductImportLookup> loadImportLookup();

  /// Menulis hasil impor ke database dalam **satu `db.transaction()`**:
  /// seluruh baris masuk, atau tidak ada satupun (K-4.5, AC-4.15).
  ///
  /// - [rows] hanya boleh berisi baris yang sudah lolos validasi. Baris
  ///   bermasalah yang lolos ke sini membatalkan seluruh impor (penjaga
  ///   terakhir, melempar `BarisImporTidakValidException`).
  /// - [columns] adalah kolom yang BENAR-BENAR ada di file. Kolom yang
  ///   tidak ada tidak pernah menimpa nilai lama; kolom yang ada tapi
  ///   selnya kosong berarti pengguna memang mengosongkannya.
  /// - Produk lama dicocokkan **hanya lewat barcode** (K-4.3) dan impor
  ///   TIDAK PERNAH menghapus produk (K-4.6).
  /// - [fileName] masuk ke catatan `stock_movements` sebagai
  ///   `"Impor Excel: <fileName>"` (AC-4.8).
  Future<ProductImportSummary> importProducts({
    required List<ProductImportRow> rows,
    required Set<ProductImportColumn> columns,
    required ProductImportOptions options,
    required String fileName,
  });
}
