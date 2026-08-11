import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale_result.dart';
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
}
