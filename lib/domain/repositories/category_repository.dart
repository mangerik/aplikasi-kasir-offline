import '../entities/category.dart';

/// Kontrak repository Kategori.
///
/// Implementasi konkret (Drift) ada di
/// `data/repositories/category_repository_impl.dart`. Layer `features/`
/// HANYA boleh bergantung pada kontrak ini (lihat architecture.md §3).
abstract class CategoryRepository {
  Stream<List<Category>> watchAll();

  Future<Category?> getById(int id);

  /// Menambah kategori baru, mengembalikan id yang baru dibuat.
  ///
  /// Melempar `NamaKategoriSudahAdaException` (lihat repository_exceptions.dart)
  /// bila [name] sudah dipakai kategori lain.
  Future<int> create(String name);

  /// Mengubah nama kategori. Melempar `NamaKategoriSudahAdaException` bila
  /// [newName] sudah dipakai kategori lain.
  Future<void> rename(int id, String newName);

  /// Jumlah produk (aktif maupun nonaktif) yang memakai kategori ini.
  Future<int> countProducts(int categoryId);

  /// Menghapus kategori. Melempar `KategoriMasihDipakaiException` bila
  /// masih ada produk yang memakainya (plan.md Milestone 1 poin 5).
  Future<void> delete(int id);
}
