import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/repository_exceptions.dart';
import '../../domain/repositories/stock_repository.dart';
import '../db/app_database.dart' as db;

/// Implementasi [StockRepository] di atas Drift/SQLite.
///
/// [adjustStock] dibungkus SATU `db.transaction()` — baca stok sekarang,
/// hitung stok baru sesuai `type`, update `products.stock`, insert
/// `stock_movements` — persis pola `saveSale`/`voidSale` di
/// `SaleRepositoryImpl` (architecture.md §4, plan.md Milestone 4 poin 1).
class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Future<void> adjustStock({
    required int productId,
    required String type,
    required double amount,
    String? note,
  }) {
    final now = DateFormatter.toEpochMillis(DateTime.now());

    return _db.transaction(() async {
      final product = await (_db.select(
        _db.products,
      )..where((p) => p.id.equals(productId))).getSingleOrNull();
      if (product == null) {
        throw const ProdukTidakDitemukanException();
      }

      // `amount` untuk opname adalah stok akhir ABSOLUT hasil hitung fisik,
      // bukan selisih (lihat kontrak StockRepository.adjustStock).
      final (double newStock, double qtyChange) = switch (type) {
        'adjust_in' => (product.stock + amount, amount),
        'adjust_out' => (product.stock - amount, -amount),
        'opname' => (amount, amount - product.stock),
        _ => throw ArgumentError.value(type, 'type', 'Jenis penyesuaian stok tidak dikenal'),
      };

      await (_db.update(_db.products)..where((p) => p.id.equals(productId))).write(
        db.ProductsCompanion(stock: Value(newStock)),
      );
      await _db.into(_db.stockMovements).insert(
            db.StockMovementsCompanion.insert(
              productId: productId,
              type: type,
              qtyChange: qtyChange,
              stockAfter: newStock,
              note: Value(note),
              createdAt: now,
            ),
          );
    });
  }

  @override
  Future<List<StockMovement>> getMovements({
    required int productId,
    required int limit,
    required int offset,
  }) async {
    final rows = await (_db.select(_db.stockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([(m) => OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc)])
          ..limit(limit, offset: offset))
        .get();

    // Nomor invoice referensi (untuk pergerakan type 'sale'/'void_return')
    // dimuat sekaligus dalam SATU query tambahan (bukan N+1 per baris).
    final saleIds = rows.map((r) => r.referenceSaleId).whereType<int>().toSet();
    var invoiceById = const <int, String>{};
    if (saleIds.isNotEmpty) {
      final saleRows = await (_db.select(
        _db.sales,
      )..where((s) => s.id.isIn(saleIds))).get();
      invoiceById = {for (final s in saleRows) s.id: s.invoiceNumber};
    }

    return rows
        .map(
          (row) => StockMovement(
            id: row.id,
            productId: row.productId,
            type: row.type,
            qtyChange: row.qtyChange,
            stockAfter: row.stockAfter,
            referenceSaleId: row.referenceSaleId,
            referenceInvoiceNumber:
                row.referenceSaleId == null ? null : invoiceById[row.referenceSaleId],
            note: row.note,
            createdAt: DateFormatter.fromEpochMillis(row.createdAt),
          ),
        )
        .toList();
  }
}
