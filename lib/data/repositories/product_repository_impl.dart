import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_import.dart';
import '../../domain/repositories/import_exceptions.dart';
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
  Future<Product?> getByBarcode(String barcode) async {
    final row = await (_db.select(_db.products)
          ..where((p) => p.barcode.equals(barcode) & p.isActive.equals(true)))
        .getSingleOrNull();
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

  @override
  Stream<int> watchLowStockCount({required double defaultThreshold}) {
    final countExpr = _db.products.id.count();
    final query = _db.selectOnly(_db.products)
      ..addColumns([countExpr])
      ..where(_lowStockCondition(defaultThreshold));
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  @override
  Stream<List<Product>> watchLowStock({required double defaultThreshold}) {
    final statement = _db.select(_db.products)
      ..where((p) => _lowStockCondition(defaultThreshold))
      ..orderBy([(p) => OrderingTerm(expression: p.stock)]);
    return statement.watch().map((rows) => rows.map(_toEntity).toList());
  }

  // ---------------------------------------------------------------------
  // Impor produk dari Excel (PRD v1.1 §4, Milestone 9).
  // ---------------------------------------------------------------------

  @override
  Future<ProductImportLookup> loadImportLookup() async {
    final productRows = await (_db.selectOnly(_db.products)
          ..addColumns([
            _db.products.id,
            _db.products.name,
            _db.products.barcode,
            _db.products.isActive,
          ]))
        .get();

    final idByBarcode = <String, int>{};
    final activeNames = <String>{};
    for (final row in productRows) {
      final barcode = row.read(_db.products.barcode);
      if (barcode != null && barcode.isNotEmpty) {
        idByBarcode[barcode] = row.read(_db.products.id)!;
      }
      if (row.read(_db.products.isActive) ?? false) {
        activeNames.add((row.read(_db.products.name) ?? '').toLowerCase());
      }
    }

    final categoryRows =
        await (_db.selectOnly(_db.categories)..addColumns([_db.categories.name])).get();

    return ProductImportLookup(
      productIdByBarcode: idByBarcode,
      activeProductNames: activeNames,
      categoryNames: {
        for (final row in categoryRows) (row.read(_db.categories.name) ?? '').toLowerCase(),
      },
    );
  }

  @override
  Future<ProductImportSummary> importProducts({
    required List<ProductImportRow> rows,
    required Set<ProductImportColumn> columns,
    required ProductImportOptions options,
    required String fileName,
  }) {
    final now = DateFormatter.toEpochMillis(DateTime.now());
    final note = 'Impor Excel: $fileName';

    // SATU transaksi untuk SELURUH file (K-4.5): gagal di baris ke-50 dari
    // 100 berarti nol produk masuk, bukan 49 produk masuk separuh jalan.
    return _db.transaction(() async {
      final categoryRows = await _db.select(_db.categories).get();
      final categoryIdByName = <String, int>{
        for (final row in categoryRows) row.name.trim().toLowerCase(): row.id,
      };

      var created = 0;
      var updated = 0;
      var skipped = 0;
      var categoriesCreated = 0;
      var movements = 0;

      for (final row in rows) {
        // Penjaga terakhir: baris bermasalah tidak boleh menyentuh
        // database sama sekali. Dilempar DI DALAM transaksi supaya baris
        // yang sudah ditulis sebelumnya ikut dibatalkan (AC-4.15).
        _assertImportable(row);

        int? categoryId;
        if (columns.contains(ProductImportColumn.category)) {
          final categoryName = row.categoryName;
          if (categoryName != null) {
            final key = categoryName.trim().toLowerCase();
            categoryId = categoryIdByName[key];
            if (categoryId == null && options.autoCreateCategory) {
              categoryId = await _db.into(_db.categories).insert(
                    db.CategoriesCompanion.insert(
                      name: categoryName.trim(),
                      createdAt: now,
                    ),
                  );
              // Kategori dibuat SEKALI saja walau muncul di banyak baris
              // (AC-4.9) — petanya ikut diperbarui di dalam transaksi.
              categoryIdByName[key] = categoryId;
              categoriesCreated++;
            }
          }
        }

        final barcode = row.barcode;
        final existing = barcode == null
            ? null
            : await (_db.select(_db.products)..where((p) => p.barcode.equals(barcode)))
                .getSingleOrNull();

        if (existing != null) {
          if (options.duplicateMode == ProductImportDuplicateMode.skip) {
            skipped++;
            continue;
          }

          var newStock = existing.stock;
          final fileStock = row.stock;
          final overwriting = options.overwriteStock &&
              columns.contains(ProductImportColumn.stock) &&
              fileStock != null &&
              fileStock != existing.stock;
          if (overwriting) {
            newStock = fileStock;
          }

          await (_db.update(_db.products)..where((p) => p.id.equals(existing.id))).write(
            db.ProductsCompanion(
              name: Value(row.name.trim()),
              sellPrice: Value(row.sellPrice),
              stock: overwriting ? Value(newStock) : const Value.absent(),
              categoryId: columns.contains(ProductImportColumn.category)
                  ? Value(categoryId)
                  : const Value.absent(),
              costPrice: columns.contains(ProductImportColumn.costPrice)
                  ? Value(row.costPrice)
                  : const Value.absent(),
              unit: columns.contains(ProductImportColumn.unit)
                  ? Value(row.unit ?? 'pcs')
                  : const Value.absent(),
              lowStockThreshold: columns.contains(ProductImportColumn.lowStockThreshold)
                  ? Value(row.lowStockThreshold)
                  : const Value.absent(),
              isActive: columns.contains(ProductImportColumn.isActive)
                  ? Value(row.isActive ?? true)
                  : const Value.absent(),
              updatedAt: Value(now),
            ),
          );

          if (overwriting) {
            // Jejak audit stok M4 wajib tetap utuh: satu baris opname per
            // perubahan stok, dengan catatan berisi nama file (AC-4.8).
            await _db.into(_db.stockMovements).insert(
                  db.StockMovementsCompanion.insert(
                    productId: existing.id,
                    type: 'opname',
                    qtyChange: newStock - existing.stock,
                    stockAfter: newStock,
                    note: Value(note),
                    createdAt: now,
                  ),
                );
            movements++;
          }
          updated++;
          continue;
        }

        // Produk BARU. Stok diambil dari file apa adanya — tidak ada stok
        // lama yang bisa "ditimpa", jadi opsi timpa stok tidak berlaku di
        // sini; opsi itu hanya menentukan perlu-tidaknya jejak audit.
        final stock = columns.contains(ProductImportColumn.stock) ? (row.stock ?? 0) : 0.0;
        final newId = await _db.into(_db.products).insert(
              db.ProductsCompanion.insert(
                name: row.name.trim(),
                barcode: Value(barcode),
                categoryId: Value(categoryId),
                sellPrice: row.sellPrice,
                costPrice: Value(row.costPrice),
                stock: Value(stock),
                unit: Value(row.unit ?? 'pcs'),
                lowStockThreshold: Value(row.lowStockThreshold),
                isActive: Value(row.isActive ?? true),
                createdAt: now,
                updatedAt: now,
              ),
            );
        created++;

        if (options.overwriteStock && stock > 0) {
          await _db.into(_db.stockMovements).insert(
                db.StockMovementsCompanion.insert(
                  productId: newId,
                  type: 'adjust_in',
                  qtyChange: stock,
                  stockAfter: stock,
                  note: Value(note),
                  createdAt: now,
                ),
              );
          movements++;
        }
      }

      return ProductImportSummary(
        createdCount: created,
        updatedCount: updated,
        skippedCount: skipped,
        categoriesCreatedCount: categoriesCreated,
        stockMovementCount: movements,
      );
    });
  }

  void _assertImportable(ProductImportRow row) {
    if (row.hasError) {
      throw BarisImporTidakValidException(
        row.excelRow,
        row.issues.firstWhere((i) => i.isError).message,
      );
    }
    if (row.name.trim().isEmpty) {
      throw BarisImporTidakValidException(row.excelRow, 'nama produk kosong');
    }
    if (row.sellPrice < 0) {
      throw BarisImporTidakValidException(row.excelRow, 'harga jual negatif');
    }
  }

  /// Kondisi "aktif DAN stok menipis" via SQL murni (agregasi/perbandingan
  /// di database, BUKAN Dart — plan.md Milestone 4 poin 8): `is_active = 1
  /// AND stock <= COALESCE(low_stock_threshold, defaultThreshold)`, sama
  /// persis dengan [Product.isLowStock].
  Expression<bool> _lowStockCondition(double defaultThreshold) {
    final effectiveThreshold = coalesce<double>([
      _db.products.lowStockThreshold,
      Variable.withReal(defaultThreshold),
    ]);
    return _db.products.isActive.equals(true) &
        _db.products.stock.isSmallerOrEqual(effectiveThreshold);
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
