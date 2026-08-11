import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/repository_exceptions.dart';
import '../db/app_database.dart' as db;

/// Implementasi [ProductRepository] di atas Drift/SQLite.
///
/// Catatan penamaan: kelas baris hasil generate Drift untuk tabel `Products`
/// bernama `Product` — sama dengan entity domain [Product]. Untuk
/// menghindari tabrakan nama, seluruh tipe dari `app_database.dart` diakses
/// lewat prefix `db.` (mis. `db.Product`, `db.ProductsCompanion`).
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Product>> watchAll({
    String? query,
    int? categoryId,
    bool onlyActive = false,
  }) {
    final statement = _db.select(_db.products);

    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      final pattern = '%$trimmedQuery%';
      statement.where((p) => p.name.like(pattern) | p.barcode.like(pattern));
    }
    if (categoryId != null) {
      statement.where((p) => p.categoryId.equals(categoryId));
    }
    if (onlyActive) {
      statement.where((p) => p.isActive.equals(true));
    }
    statement.orderBy([(p) => OrderingTerm(expression: p.name)]);

    return statement.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Product?> getById(int id) async {
    final row = await (_db.select(
      _db.products,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
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
  }) async {
    final now = DateFormatter.toEpochMillis(DateTime.now());
    final normalizedBarcode = _normalizeBarcode(barcode);
    try {
      return await _db.into(_db.products).insert(
            db.ProductsCompanion.insert(
              name: name.trim(),
              barcode: Value(normalizedBarcode),
              categoryId: Value(categoryId),
              sellPrice: sellPrice,
              costPrice: Value(costPrice),
              stock: Value(stock),
              unit: Value(unit),
              lowStockThreshold: Value(lowStockThreshold),
              imagePath: Value(imagePath),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } on SqliteException catch (e) {
      if (_isUniqueViolation(e)) {
        throw BarcodeSudahDipakaiException(normalizedBarcode ?? '');
      }
      rethrow;
    }
  }

  @override
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
  }) async {
    final now = DateFormatter.toEpochMillis(DateTime.now());
    final normalizedBarcode = _normalizeBarcode(barcode);
    try {
      await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
        db.ProductsCompanion(
          name: Value(name.trim()),
          barcode: Value(normalizedBarcode),
          categoryId: Value(categoryId),
          sellPrice: Value(sellPrice),
          costPrice: Value(costPrice),
          stock: Value(stock),
          unit: Value(unit),
          lowStockThreshold: Value(lowStockThreshold),
          imagePath: Value(imagePath),
          updatedAt: Value(now),
        ),
      );
    } on SqliteException catch (e) {
      if (_isUniqueViolation(e)) {
        throw BarcodeSudahDipakaiException(normalizedBarcode ?? '');
      }
      rethrow;
    }
  }

  @override
  Future<void> setActive(int id, bool isActive) async {
    await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
      db.ProductsCompanion(isActive: Value(isActive)),
    );
  }

  /// String kosong dianggap "tidak diisi" agar tidak memicu unique index
  /// (yang hanya berlaku untuk barcode yang benar-benar terisi).
  String? _normalizeBarcode(String? raw) {
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  bool _isUniqueViolation(SqliteException e) =>
      e.message.toLowerCase().contains('unique constraint failed') ||
      (e.explanation ?? '').toLowerCase().contains('unique constraint failed');

  Product _toEntity(db.Product row) => Product(
        id: row.id,
        name: row.name,
        barcode: row.barcode,
        categoryId: row.categoryId,
        sellPrice: row.sellPrice,
        costPrice: row.costPrice,
        stock: row.stock,
        unit: row.unit,
        lowStockThreshold: row.lowStockThreshold,
        imagePath: row.imagePath,
        isActive: row.isActive,
        createdAt: DateFormatter.fromEpochMillis(row.createdAt),
        updatedAt: DateFormatter.fromEpochMillis(row.updatedAt),
      );
}
