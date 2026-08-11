import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/report_repository_impl.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/repositories/report_repository.dart';

void main() {
  late AppDatabase db;
  late ReportRepositoryImpl repo;
  late SaleRepositoryImpl saleRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReportRepositoryImpl(db);
    saleRepo = SaleRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertProduct({
    String name = 'Teh Botol',
    int sellPrice = 5000,
    int? costPrice,
    double stock = 1000,
  }) {
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            sellPrice: sellPrice,
            costPrice: Value(costPrice),
            stock: Value(stock),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  }

  // `sales.invoice_number` bersifat UNIQUE (architecture.md §4) — counter
  // ini menjamin tiap `insertRawSale` tanpa `invoiceNumber` eksplisit tetap
  // dapat nomor unik walau dipanggil berkali-kali dalam satu test.
  var invoiceCounter = 0;

  /// Insert transaksi LANGSUNG (bukan lewat `saveSale`) supaya `createdAt`
  /// & `status` bisa dikontrol presisi untuk uji rentang tanggal & void.
  Future<int> insertRawSale({
    required int createdAt,
    String status = 'completed',
    String paymentMethod = 'cash',
    int total = 10000,
    String? customerName,
    String? invoiceNumber,
  }) {
    invoiceCounter++;
    return db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            invoiceNumber: invoiceNumber ?? 'INV-$invoiceCounter',
            subtotal: total,
            total: total,
            paymentMethod: paymentMethod,
            status: status,
            customerName: Value(customerName),
            createdAt: createdAt,
          ),
        );
  }

  Future<void> insertSaleItem({
    required int saleId,
    int? productId,
    String productName = 'Teh Botol',
    double qty = 1,
    int sellPrice = 5000,
    int? costPrice,
    int lineTotal = 5000,
  }) {
    return db
        .into(db.saleItems)
        .insert(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: Value(productId),
            productName: productName,
            unit: 'pcs',
            qty: qty,
            sellPrice: sellPrice,
            costPrice: Value(costPrice),
            lineTotal: lineTotal,
          ),
        )
        .then((_) {});
  }

  group('ReportRepositoryImpl — getSummary (plan.md Milestone 4 poin 4)', () {
    test('omzet & jumlah transaksi = SUM/COUNT transaksi non-voided dalam rentang', () async {
      await insertRawSale(createdAt: 1000, total: 10000);
      await insertRawSale(createdAt: 2000, total: 20000);
      await insertRawSale(createdAt: 999999, total: 99999); // di luar rentang

      final summary = await repo.getSummary(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      expect(summary.transactionCount, 2);
      expect(summary.totalOmzet, 30000);
    });

    test('transaksi voided DIKECUALIKAN dari omzet & jumlah transaksi', () async {
      await insertRawSale(createdAt: 1000, total: 10000, status: 'completed');
      await insertRawSale(createdAt: 1000, total: 50000, status: 'voided');
      await insertRawSale(createdAt: 1000, total: 5000, status: 'debt_unpaid');

      final summary = await repo.getSummary(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      expect(summary.transactionCount, 2, reason: 'completed + debt_unpaid, voided dikecualikan');
      expect(summary.totalOmzet, 15000);
    });

    test('laba kotor = SUM(line_total - cost_price*qty) hanya untuk item ber-cost_price', () async {
      final saleId = await insertRawSale(createdAt: 1000, total: 15000);
      // Item dengan cost_price: laba 5000-3000=2000 per unit, qty 2 -> 4000
      await insertSaleItem(saleId: saleId, qty: 2, sellPrice: 5000, costPrice: 3000, lineTotal: 10000);
      // Item TANPA cost_price -> tidak ikut dihitung laba sama sekali
      await insertSaleItem(saleId: saleId, qty: 1, sellPrice: 5000, costPrice: null, lineTotal: 5000);

      final summary = await repo.getSummary(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      expect(summary.grossProfit, 4000);
    });

    test('laba kotor mengecualikan item dari transaksi voided', () async {
      final voidedSaleId = await insertRawSale(createdAt: 1000, total: 15000, status: 'voided');
      await insertSaleItem(
        saleId: voidedSaleId,
        qty: 1,
        sellPrice: 5000,
        costPrice: 1000,
        lineTotal: 5000,
      );

      final summary = await repo.getSummary(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      expect(summary.grossProfit, 0);
    });

    test('byPaymentMethod mengelompokkan total & jumlah per metode bayar', () async {
      await insertRawSale(createdAt: 1000, total: 10000, paymentMethod: 'cash');
      await insertRawSale(createdAt: 1000, total: 20000, paymentMethod: 'cash');
      await insertRawSale(createdAt: 1000, total: 5000, paymentMethod: 'noncash');
      await insertRawSale(createdAt: 1000, total: 7000, paymentMethod: 'debt');

      final summary = await repo.getSummary(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      final byMethod = {for (final m in summary.byPaymentMethod) m.method: m};
      expect(byMethod['cash']!.count, 2);
      expect(byMethod['cash']!.total, 30000);
      expect(byMethod['noncash']!.count, 1);
      expect(byMethod['noncash']!.total, 5000);
      expect(byMethod['debt']!.count, 1);
      expect(byMethod['debt']!.total, 7000);
    });

    test('rentang kosong (tidak ada transaksi) menghasilkan angka nol, bukan error', () async {
      final summary = await repo.getSummary(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      expect(summary.transactionCount, 0);
      expect(summary.totalOmzet, 0);
      expect(summary.grossProfit, 0);
      expect(summary.byPaymentMethod, isEmpty);
    });

    test('via saveSale sungguhan: laba & omzet konsisten dengan snapshot cost_price', () async {
      final productId = await insertProduct(sellPrice: 5000, costPrice: 3000);
      await saleRepo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 3,
            sellPrice: 5000,
            costPrice: 3000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 15000,
      );

      final now = DateTime.now();
      final summary = await repo.getSummary(
        start: now.subtract(const Duration(days: 1)),
        end: now.add(const Duration(days: 1)),
      );

      expect(summary.transactionCount, 1);
      expect(summary.totalOmzet, 15000);
      expect(summary.grossProfit, 6000); // (5000-3000)*3
    });
  });

  group('ReportRepositoryImpl — getTopProducts (plan.md Milestone 4 poin 6)', () {
    test('mengelompokkan & menjumlahkan qty/nilai per produk, urut qty terbanyak', () async {
      final productA = await insertProduct(name: 'A');
      final productB = await insertProduct(name: 'B');

      final saleId1 = await insertRawSale(createdAt: 1000, total: 30000);
      await insertSaleItem(
        saleId: saleId1,
        productId: productA,
        productName: 'A',
        qty: 5,
        lineTotal: 25000,
      );
      final saleId2 = await insertRawSale(createdAt: 2000, total: 10000);
      await insertSaleItem(
        saleId: saleId2,
        productId: productA,
        productName: 'A',
        qty: 2,
        lineTotal: 10000,
      );
      await insertSaleItem(
        saleId: saleId2,
        productId: productB,
        productName: 'B',
        qty: 20,
        lineTotal: 5000,
      );

      final result = await repo.getTopProducts(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      final byName = {for (final p in result) p.productName: p};
      expect(byName['A']!.qtySold, 7); // 5 + 2
      expect(byName['A']!.totalValue, 35000);
      expect(byName['B']!.qtySold, 20);
      // Urut qty terbanyak dulu -> B (20) di atas A (7)
      expect(result.first.productName, 'B');
    });

    test('sortBy value mengurutkan berdasarkan nilai penjualan, bukan qty', () async {
      final productMurah = await insertProduct(name: 'Murah-Banyak');
      final productMahal = await insertProduct(name: 'Mahal-Sedikit');

      final saleId = await insertRawSale(createdAt: 1000, total: 100000);
      await insertSaleItem(
        saleId: saleId,
        productId: productMurah,
        productName: 'Murah-Banyak',
        qty: 100,
        lineTotal: 10000,
      );
      await insertSaleItem(
        saleId: saleId,
        productId: productMahal,
        productName: 'Mahal-Sedikit',
        qty: 1,
        lineTotal: 90000,
      );

      final result = await repo.getTopProducts(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
        sortBy: TopProductSort.value,
      );

      expect(result.first.productName, 'Mahal-Sedikit');
    });

    test('mengecualikan item dari transaksi voided', () async {
      final productId = await insertProduct(name: 'A');
      final saleId = await insertRawSale(createdAt: 1000, total: 10000, status: 'voided');
      await insertSaleItem(
        saleId: saleId,
        productId: productId,
        productName: 'A',
        qty: 5,
        lineTotal: 25000,
      );

      final result = await repo.getTopProducts(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
      );

      expect(result, isEmpty);
    });

    test('limit membatasi jumlah baris hasil', () async {
      final saleId = await insertRawSale(createdAt: 1000, total: 10000);
      for (var i = 0; i < 5; i++) {
        final productId = await insertProduct(name: 'Produk $i');
        await insertSaleItem(
          saleId: saleId,
          productId: productId,
          productName: 'Produk $i',
          qty: 1,
          lineTotal: 1000,
        );
      }

      final result = await repo.getTopProducts(
        start: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        end: DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
        limit: 2,
      );

      expect(result, hasLength(2));
    });
  });

  group('ReportRepositoryImpl — hutang belum lunas (plan.md Milestone 4 poin 7)', () {
    test('getUnpaidDebts mengelompokkan total & jumlah transaksi per pelanggan', () async {
      await insertRawSale(
        createdAt: 1000,
        total: 10000,
        status: 'debt_unpaid',
        customerName: 'Budi',
      );
      await insertRawSale(
        createdAt: 2000,
        total: 15000,
        status: 'debt_unpaid',
        customerName: 'Budi',
      );
      await insertRawSale(
        createdAt: 3000,
        total: 20000,
        status: 'debt_unpaid',
        customerName: 'Siti',
      );
      // Sudah lunas -> tidak ikut dihitung.
      await insertRawSale(
        createdAt: 4000,
        total: 99999,
        status: 'completed',
        customerName: 'Budi',
      );

      final debts = await repo.getUnpaidDebts();

      final byName = {for (final d in debts) d.customerName: d};
      expect(byName['Budi']!.totalDebt, 25000);
      expect(byName['Budi']!.transactionCount, 2);
      expect(byName['Siti']!.totalDebt, 20000);
      expect(byName['Siti']!.transactionCount, 1);
    });

    test('getUnpaidDebts urut dari total terbesar', () async {
      await insertRawSale(
        createdAt: 1000,
        total: 5000,
        status: 'debt_unpaid',
        customerName: 'Kecil',
      );
      await insertRawSale(
        createdAt: 1000,
        total: 50000,
        status: 'debt_unpaid',
        customerName: 'Besar',
      );

      final debts = await repo.getUnpaidDebts();
      expect(debts.first.customerName, 'Besar');
    });

    test('getDebtTransactions mengembalikan hanya transaksi hutang milik pelanggan tsb', () async {
      await insertRawSale(
        createdAt: 1000,
        total: 10000,
        status: 'debt_unpaid',
        customerName: 'Budi',
        invoiceNumber: 'INV-1',
      );
      await insertRawSale(
        createdAt: 2000,
        total: 15000,
        status: 'debt_unpaid',
        customerName: 'Budi',
        invoiceNumber: 'INV-2',
      );
      await insertRawSale(
        createdAt: 3000,
        total: 20000,
        status: 'debt_unpaid',
        customerName: 'Siti',
        invoiceNumber: 'INV-3',
      );
      await insertRawSale(
        createdAt: 4000,
        total: 20000,
        status: 'completed',
        customerName: 'Budi',
        invoiceNumber: 'INV-4',
      );

      final result = await repo.getDebtTransactions('Budi');

      expect(result, hasLength(2));
      expect(result.every((s) => s.customerName == 'Budi'), isTrue);
      expect(result.every((s) => s.status == 'debt_unpaid'), isTrue);
      // Terbaru dulu.
      expect(result.first.invoiceNumber, 'INV-2');
    });
  });
}
