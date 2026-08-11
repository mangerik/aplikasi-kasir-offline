import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/repository_exceptions.dart';
import '../db/app_database.dart' as db;

/// Implementasi [CategoryRepository] di atas Drift/SQLite.
///
/// Catatan penamaan: kelas baris hasil generate Drift untuk tabel
/// `Categories` bernama `Category` — sama dengan entity domain [Category].
/// Untuk menghindari tabrakan nama, seluruh tipe dari `app_database.dart`
/// diakses lewat prefix `db.` (mis. `db.Category`, `db.CategoriesCompanion`).
class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Category>> watchAll() {
    final statement = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm(expression: c.name)]);
    return statement.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Category?> getById(int id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<int> create(String name) async {
    final trimmed = name.trim();
    final now = DateFormatter.toEpochMillis(DateTime.now());
    try {
      return await _db.into(_db.categories).insert(
            db.CategoriesCompanion.insert(name: trimmed, createdAt: now),
          );
    } on SqliteException catch (e) {
      if (_isUniqueViolation(e)) {
        throw NamaKategoriSudahAdaException(trimmed);
      }
      rethrow;
    }
  }

  @override
  Future<void> rename(int id, String newName) async {
    final trimmed = newName.trim();
    try {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        db.CategoriesCompanion(name: Value(trimmed)),
      );
    } on SqliteException catch (e) {
      if (_isUniqueViolation(e)) {
        throw NamaKategoriSudahAdaException(trimmed);
      }
      rethrow;
    }
  }

  @override
  Future<int> countProducts(int categoryId) async {
    final countExpression = _db.products.id.count();
    final query = _db.selectOnly(_db.products)
      ..addColumns([countExpression])
      ..where(_db.products.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(countExpression) ?? 0;
  }

  @override
  Future<void> delete(int id) async {
    final productCount = await countProducts(id);
    if (productCount > 0) {
      throw KategoriMasihDipakaiException(productCount);
    }
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  bool _isUniqueViolation(SqliteException e) =>
      e.message.toLowerCase().contains('unique constraint failed') ||
      (e.explanation ?? '').toLowerCase().contains('unique constraint failed');

  Category _toEntity(db.Category row) => Category(
        id: row.id,
        name: row.name,
        createdAt: DateFormatter.fromEpochMillis(row.createdAt),
      );
}
