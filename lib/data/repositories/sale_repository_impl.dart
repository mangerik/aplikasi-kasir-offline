import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_result.dart';
import '../../domain/repositories/repository_exceptions.dart';
import '../../domain/repositories/sale_repository.dart';
import '../db/app_database.dart' as db;

/// Implementasi [SaleRepository] di atas Drift/SQLite.
///
/// Seluruh penulisan — insert `sales`, insert semua `sale_items`, update
/// `products.stock` (untuk item terdaftar), insert
/// `stock_movements(type='sale')`, dan generator nomor invoice harian —
/// dibungkus SATU `db.transaction()`. Gagal di tengah jalan (mis.
/// pelanggaran foreign key) membatalkan SEMUA perubahan (rollback penuh),
/// lihat architecture.md §4 "Aturan Integritas" poin 1 & 4, dan
/// `test/data/repositories/sale_repository_impl_test.dart`.
class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Future<SaleResult> saveSale({
    required List<CartItem> items,
    required int transactionDiscount,
    required String paymentMethod,
    required int paidAmount,
    String? customerName,
    String? note,
  }) {
    final now = DateTime.now();
    final createdAtMillis = DateFormatter.toEpochMillis(now);
    final dayPrefix = DateFormatter.formatInvoiceDay(now);

    return _db.transaction(() async {
      // Nomor invoice dibangkitkan DI DALAM transaksi yang sama dengan
      // insert `sales` di bawah — mencegah dua penjualan berbarengan
      // mendapat nomor yang sama (architecture.md §4 poin 4).
      final invoiceNumber = await _nextInvoiceNumber(dayPrefix);

      final itemsSubtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
      final total = (itemsSubtotal - transactionDiscount).clamp(0, itemsSubtotal).toInt();
      final changeAmount = paymentMethod == 'cash' ? (paidAmount - total) : 0;
      final status = paymentMethod == 'debt' ? 'debt_unpaid' : 'completed';

      final saleId = await _db.into(_db.sales).insert(
            db.SalesCompanion.insert(
              invoiceNumber: invoiceNumber,
              subtotal: itemsSubtotal,
              discount: Value(transactionDiscount),
              total: total,
              paymentMethod: paymentMethod,
              paidAmount: Value(paidAmount),
              changeAmount: Value(changeAmount),
              customerName: Value(customerName),
              status: status,
              note: Value(note),
              createdAt: createdAtMillis,
            ),
          );

      final resultItems = <SaleResultItem>[];
      for (final item in items) {
        await _db.into(_db.saleItems).insert(
              db.SaleItemsCompanion.insert(
                saleId: saleId,
                productId: Value(item.productId),
                productName: item.name,
                unit: item.unit,
                qty: item.qty,
                sellPrice: item.sellPrice,
                costPrice: Value(item.costPrice),
                discount: Value(item.discount),
                lineTotal: item.lineTotal,
              ),
            );

        // Item bebas (productId null) tidak mengubah stok/produk apa pun.
        if (item.productId != null) {
          final product = await (_db.select(
            _db.products,
          )..where((p) => p.id.equals(item.productId!))).getSingle();
          final newStock = product.stock - item.qty;
          await (_db.update(
            _db.products,
          )..where((p) => p.id.equals(item.productId!))).write(
            db.ProductsCompanion(stock: Value(newStock)),
          );
          await _db.into(_db.stockMovements).insert(
                db.StockMovementsCompanion.insert(
                  productId: item.productId!,
                  type: 'sale',
                  qtyChange: -item.qty,
                  stockAfter: newStock,
                  referenceSaleId: Value(saleId),
                  createdAt: createdAtMillis,
                ),
              );
        }

        resultItems.add(
          SaleResultItem(
            productId: item.productId,
            name: item.name,
            unit: item.unit,
            qty: item.qty,
            sellPrice: item.sellPrice,
            discount: item.discount,
            lineTotal: item.lineTotal,
          ),
        );
      }

      return SaleResult(
        saleId: saleId,
        invoiceNumber: invoiceNumber,
        subtotal: itemsSubtotal,
        discount: transactionDiscount,
        total: total,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        customerName: customerName,
        note: note,
        createdAt: now,
        items: resultItems,
        status: status,
      );
    });
  }

  /// Nomor invoice berurutan per hari (`YYYYMMDD-XXXX`) — cari nomor
  /// terbesar yang sudah ada untuk [dayPrefix] hari ini, lalu +1. Dipanggil
  /// dari dalam `db.transaction()` di [saveSale] agar atomik dengan insert
  /// `sales`-nya sendiri.
  Future<String> _nextInvoiceNumber(String dayPrefix) async {
    final likePattern = '$dayPrefix-%';
    final query = _db.customSelect(
      'SELECT invoice_number FROM sales WHERE invoice_number LIKE ?1 '
      'ORDER BY invoice_number DESC LIMIT 1',
      variables: [Variable.withString(likePattern)],
      readsFrom: {_db.sales},
    );
    final row = await query.getSingleOrNull();
    var nextSequence = 1;
    if (row != null) {
      final lastInvoice = row.read<String>('invoice_number');
      final lastSequence = int.tryParse(lastInvoice.split('-').last) ?? 0;
      nextSequence = lastSequence + 1;
    }
    return '$dayPrefix-${nextSequence.toString().padLeft(4, '0')}';
  }

  @override
  Future<List<Sale>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? status,
    required int limit,
    required int offset,
  }) async {
    final statement = _db.select(_db.sales);

    if (startDate != null) {
      final startMillis = DateFormatter.toEpochMillis(startDate);
      statement.where((s) => s.createdAt.isBiggerOrEqualValue(startMillis));
    }
    if (endDate != null) {
      final endMillis = DateFormatter.toEpochMillis(endDate);
      statement.where((s) => s.createdAt.isSmallerOrEqualValue(endMillis));
    }
    if (paymentMethod != null) {
      statement.where((s) => s.paymentMethod.equals(paymentMethod));
    }
    if (status != null) {
      statement.where((s) => s.status.equals(status));
    }
    statement
      ..orderBy([(s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc)])
      ..limit(limit, offset: offset);

    final rows = await statement.get();
    return rows.map(_toSale).toList();
  }

  @override
  Future<SaleResult> getDetail(int saleId) async {
    final sale = await (_db.select(
      _db.sales,
    )..where((s) => s.id.equals(saleId))).getSingleOrNull();
    if (sale == null) {
      throw const TransaksiTidakDitemukanException();
    }
    final itemRows = await (_db.select(
      _db.saleItems,
    )..where((i) => i.saleId.equals(saleId))).get();

    return SaleResult(
      saleId: sale.id,
      invoiceNumber: sale.invoiceNumber,
      subtotal: sale.subtotal,
      discount: sale.discount,
      total: sale.total,
      paymentMethod: sale.paymentMethod,
      paidAmount: sale.paidAmount,
      changeAmount: sale.changeAmount,
      customerName: sale.customerName,
      note: sale.note,
      createdAt: DateFormatter.fromEpochMillis(sale.createdAt),
      items: itemRows
          .map(
            (row) => SaleResultItem(
              productId: row.productId,
              name: row.productName,
              unit: row.unit,
              qty: row.qty,
              sellPrice: row.sellPrice,
              discount: row.discount,
              lineTotal: row.lineTotal,
            ),
          )
          .toList(),
      status: sale.status,
      voidedAt: sale.voidedAt == null ? null : DateFormatter.fromEpochMillis(sale.voidedAt!),
      debtPaidAt: sale.debtPaidAt == null ? null : DateFormatter.fromEpochMillis(sale.debtPaidAt!),
    );
  }

  @override
  Future<void> markDebtPaid(int saleId) async {
    final now = DateFormatter.toEpochMillis(DateTime.now());
    await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
      db.SalesCompanion(status: const Value('completed'), debtPaidAt: Value(now)),
    );
  }

  @override
  Future<void> voidSale(int saleId) {
    final now = DateFormatter.toEpochMillis(DateTime.now());

    return _db.transaction(() async {
      final sale = await (_db.select(
        _db.sales,
      )..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (sale == null) {
        throw const TransaksiTidakDitemukanException();
      }
      if (sale.status == 'voided') {
        throw const TransaksiSudahDibatalkanException();
      }

      final items = await (_db.select(
        _db.saleItems,
      )..where((i) => i.saleId.equals(saleId))).get();

      for (final item in items) {
        // Item bebas (productId null) tidak pernah menyentuh stok saat
        // dijual, jadi tidak boleh dikembalikan juga (plan.md Milestone 3
        // poin 6).
        if (item.productId == null) continue;

        final product = await (_db.select(
          _db.products,
        )..where((p) => p.id.equals(item.productId!))).getSingleOrNull();
        if (product == null) continue;

        final newStock = product.stock + item.qty;
        await (_db.update(
          _db.products,
        )..where((p) => p.id.equals(item.productId!))).write(
          db.ProductsCompanion(stock: Value(newStock)),
        );
        await _db.into(_db.stockMovements).insert(
              db.StockMovementsCompanion.insert(
                productId: item.productId!,
                type: 'void_return',
                qtyChange: item.qty,
                stockAfter: newStock,
                referenceSaleId: Value(saleId),
                createdAt: now,
              ),
            );
      }

      await (_db.update(_db.sales)..where((s) => s.id.equals(saleId))).write(
        db.SalesCompanion(status: const Value('voided'), voidedAt: Value(now)),
      );
    });
  }

  Sale _toSale(db.Sale row) => Sale(
        id: row.id,
        invoiceNumber: row.invoiceNumber,
        subtotal: row.subtotal,
        discount: row.discount,
        total: row.total,
        paymentMethod: row.paymentMethod,
        paidAmount: row.paidAmount,
        changeAmount: row.changeAmount,
        customerName: row.customerName,
        status: row.status,
        note: row.note,
        createdAt: DateFormatter.fromEpochMillis(row.createdAt),
        voidedAt: row.voidedAt == null ? null : DateFormatter.fromEpochMillis(row.voidedAt!),
        debtPaidAt: row.debtPaidAt == null ? null : DateFormatter.fromEpochMillis(row.debtPaidAt!),
      );
}
