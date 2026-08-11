import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/report_repository_impl.dart';

/// Uji performa agregasi laporan pada data dummy BESAR (plan.md Milestone 4
/// poin 8: "uji dengan data dummy besar (>=50.000 transaksi) ... pastikan
/// query agregasi tetap cepat (<1 detik)").
///
/// Data di-generate lewat `db.batch()` (bulk insert) langsung ke tabel
/// Drift — TIDAK lewat `SaleRepositoryImpl.saveSale` satu-satu (yang akan
/// sangat lambat untuk 50rb baris karena tiap panggilan adalah
/// `db.transaction()` + beberapa query invoice/produk terpisah) — sesuai
/// izin eksplisit tugas "boleh via batch insert langsung di test".
void main() {
  late AppDatabase db;
  late ReportRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReportRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'agregasi laporan (getSummary/getTopProducts/getUnpaidDebts) tetap '
    '<1 detik dengan >=50.000 transaksi & sale_items',
    () async {
      const totalSales = 50000;
      final baseMillis = DateTime(2020, 1, 1).millisecondsSinceEpoch;

      final salesRows = List<SalesCompanion>.generate(totalSales, (i) {
        final createdAt = baseMillis + i * 60000; // 1 menit per transaksi.
        final status = i % 10 == 0
            ? 'voided'
            : (i % 7 == 0 ? 'debt_unpaid' : 'completed');
        final method = i % 3 == 0 ? 'cash' : (i % 3 == 1 ? 'noncash' : 'debt');
        return SalesCompanion.insert(
          invoiceNumber: 'PERF-$i',
          subtotal: 10000,
          total: 10000,
          paymentMethod: method,
          status: status,
          customerName: status == 'debt_unpaid'
              ? Value('Pelanggan ${i % 200}')
              : const Value.absent(),
          createdAt: createdAt,
        );
      });
      await db.batch((batch) => batch.insertAll(db.sales, salesRows));

      // 300 produk dummy supaya sale_items.product_id (foreign key) valid.
      // AUTOINCREMENT dari tabel kosong -> id produk ke-i (0-based) = i+1.
      const productCount = 300;
      final productRows = List<ProductsCompanion>.generate(
        productCount,
        (i) => ProductsCompanion.insert(
          name: 'Produk $i',
          sellPrice: 10000,
          costPrice: const Value(6000),
          createdAt: baseMillis,
          updatedAt: baseMillis,
        ),
      );
      await db.batch((batch) => batch.insertAll(db.products, productRows));

      // AUTOINCREMENT: DB kosong sebelum ini -> id baris ke-i (0-based) = i+1.
      final itemRows = List<SaleItemsCompanion>.generate(
        totalSales,
        (i) => SaleItemsCompanion.insert(
          saleId: i + 1,
          productId: Value((i % productCount) + 1),
          productName: 'Produk ${i % productCount}',
          unit: 'pcs',
          qty: 1,
          sellPrice: 10000,
          costPrice: const Value(6000),
          lineTotal: 10000,
        ),
      );
      await db.batch((batch) => batch.insertAll(db.saleItems, itemRows));

      final start = DateTime.fromMillisecondsSinceEpoch(baseMillis, isUtc: true);
      final end = DateTime.fromMillisecondsSinceEpoch(
        baseMillis + totalSales * 60000,
        isUtc: true,
      );

      final summaryStopwatch = Stopwatch()..start();
      final summary = await repo.getSummary(start: start, end: end);
      summaryStopwatch.stop();

      final topProductsStopwatch = Stopwatch()..start();
      final topProducts = await repo.getTopProducts(start: start, end: end, limit: 10);
      topProductsStopwatch.stop();

      final debtsStopwatch = Stopwatch()..start();
      final debts = await repo.getUnpaidDebts();
      debtsStopwatch.stop();

      // Sanity check: query benar-benar memproses data (bukan lolos karena
      // hasil kosong).
      expect(summary.transactionCount, greaterThan(40000));
      expect(topProducts, isNotEmpty);
      expect(debts, isNotEmpty);

      expect(
        summaryStopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'getSummary harus <1 detik walau $totalSales transaksi (agregasi SQL, '
            'bukan Dart) — plan.md Milestone 4 poin 8',
      );
      expect(
        topProductsStopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'getTopProducts harus <1 detik',
      );
      expect(
        debtsStopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'getUnpaidDebts harus <1 detik',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
