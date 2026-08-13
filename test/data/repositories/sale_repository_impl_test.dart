import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';

void main() {
  late AppDatabase db;
  late SaleRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SaleRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertProduct({String name = 'Teh Botol', int sellPrice = 5000, double stock = 10}) {
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            sellPrice: sellPrice,
            stock: Value(stock),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  }

  group('SaleRepositoryImpl — simpan atomik', () {
    test('menyimpan sales + sale_items + update stok + stock_movements dalam satu transaksi', () async {
      final productId = await insertProduct(stock: 10, sellPrice: 5000);

      final result = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 2,
            sellPrice: 5000,
            costPrice: 3000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 10000,
      );

      expect(result.invoiceNumber, endsWith('-0001'));
      expect(result.subtotal, 10000);
      expect(result.total, 10000);
      expect(result.changeAmount, 0);
      // costPrice snapshot (plan.md M6 perbaikan tertunda: laba kotor di
      // export Excel wajib pakai snapshot sale_items.cost_price, bukan
      // harga modal produk saat ini) harus ikut kembali di SaleResultItem.
      expect(result.items.single.costPrice, 3000);

      final sales = await db.select(db.sales).get();
      final saleItems = await db.select(db.saleItems).get();
      final movements = await db.select(db.stockMovements).get();
      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();

      expect(sales, hasLength(1));
      expect(sales.single.invoiceNumber, result.invoiceNumber);
      expect(saleItems, hasLength(1));
      expect(saleItems.single.lineTotal, 10000);
      expect(movements, hasLength(1));
      expect(movements.single.type, 'sale');
      expect(movements.single.qtyChange, -2);
      expect(movements.single.stockAfter, 8);
      expect(movements.single.referenceSaleId, sales.single.id);
      expect(product.stock, 8);
    });

    test('item bebas (productId null) tidak mengubah stok/stock_movements', () async {
      final productId = await insertProduct(stock: 5);

      await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 5000,
          ),
          const CartItem(
            key: 'f_1',
            name: 'Jasa Bungkus',
            unit: 'pcs',
            qty: 1,
            sellPrice: 1000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 6000,
      );

      final saleItems = await db.select(db.saleItems).get();
      final movements = await db.select(db.stockMovements).get();

      expect(saleItems, hasLength(2));
      expect(movements, hasLength(1), reason: 'hanya item terdaftar yang mengubah stok');
    });

    test('diskon item & diskon transaksi dihitung benar ke subtotal/total tersimpan', () async {
      final productId = await insertProduct(stock: 10, sellPrice: 10000);

      final result = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 10000,
            discount: 2000,
          ),
        ],
        transactionDiscount: 3000,
        paymentMethod: 'cash',
        paidAmount: 5000,
      );

      expect(result.subtotal, 8000); // 10000 - diskon item 2000
      expect(result.discount, 3000);
      expect(result.total, 5000); // 8000 - diskon transaksi 3000
      expect(result.changeAmount, 0);
    });

    test('pembayaran hutang: status debt_unpaid, customerName tersimpan', () async {
      final productId = await insertProduct(stock: 10, sellPrice: 10000);

      final result = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 10000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'debt',
        paidAmount: 0,
        customerName: 'Budi',
      );

      final sale = (await db.select(db.sales).get()).single;
      expect(sale.status, 'debt_unpaid');
      expect(sale.customerName, 'Budi');
      expect(result.changeAmount, 0);
    });
  });

  group('SaleRepositoryImpl — nomor invoice harian berurutan', () {
    test('invoice bertambah 0001, 0002, ... untuk penjualan di hari yang sama', () async {
      final productId = await insertProduct();

      final first = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 5000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 5000,
      );
      final second = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 5000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 5000,
      );

      final prefix = first.invoiceNumber.split('-').first;
      expect(first.invoiceNumber, '$prefix-0001');
      expect(second.invoiceNumber, '$prefix-0002');
    });

    test('invoice mulai dari 0001 lagi walau ada nomor lama dari hari berbeda', () async {
      // Sisipkan invoice "hari lain" (prefix beda dari hari ini) langsung.
      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              invoiceNumber: '20200101-0099',
              subtotal: 1000,
              total: 1000,
              paymentMethod: 'cash',
              status: 'completed',
              createdAt: 1,
            ),
          );

      final productId = await insertProduct();
      final result = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 5000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 5000,
      );

      expect(result.invoiceNumber, endsWith('-0001'));
      expect(result.invoiceNumber, isNot(startsWith('20200101')));
    });
  });

  group('SaleRepositoryImpl — rollback', () {
    test('gagal di tengah transaksi (produk tidak ditemukan) membatalkan SEMUA perubahan', () async {
      final validProductId = await insertProduct(stock: 5, sellPrice: 5000);

      Future<void> attempt() => repo.saveSale(
            items: [
              CartItem(
                key: 'p_$validProductId',
                productId: validProductId,
                name: 'Teh Botol',
                unit: 'pcs',
                qty: 1,
                sellPrice: 5000,
              ),
              const CartItem(
                key: 'p_999999',
                productId: 999999, // produk tidak ada -> getSingle() gagal
                name: 'Produk Hilang',
                unit: 'pcs',
                qty: 1,
                sellPrice: 1000,
              ),
            ],
            transactionDiscount: 0,
            paymentMethod: 'cash',
            paidAmount: 6000,
          );

      await expectLater(attempt(), throwsA(anything));

      final sales = await db.select(db.sales).get();
      final saleItems = await db.select(db.saleItems).get();
      final movements = await db.select(db.stockMovements).get();
      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(validProductId))).getSingle();

      expect(sales, isEmpty, reason: 'rollback: sales harus kosong');
      expect(saleItems, isEmpty, reason: 'rollback: sale_items harus kosong, termasuk item valid');
      expect(movements, isEmpty);
      expect(product.stock, 5, reason: 'stok produk valid TIDAK berubah walau item lain gagal');
    });
  });

  /// Insert langsung ke `sales` (bypass `repo.saveSale`) supaya `createdAt`
  /// bisa dikontrol presisi untuk uji urutan/pagination/filter tanggal.
  Future<int> insertRawSale({
    required int createdAt,
    String invoiceNumber = 'INV',
    String status = 'completed',
    String paymentMethod = 'cash',
    int total = 1000,
  }) {
    return db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            invoiceNumber: invoiceNumber,
            subtotal: total,
            total: total,
            paymentMethod: paymentMethod,
            status: status,
            createdAt: createdAt,
          ),
        );
  }

  group('SaleRepositoryImpl — riwayat & pagination', () {
    test('getHistory urut terbaru dulu, LIMIT/OFFSET tanpa duplikat antar halaman', () async {
      final id1 = await insertRawSale(createdAt: 1000, invoiceNumber: 'INV-1');
      final id2 = await insertRawSale(createdAt: 2000, invoiceNumber: 'INV-2');
      final id3 = await insertRawSale(createdAt: 3000, invoiceNumber: 'INV-3');
      final id4 = await insertRawSale(createdAt: 4000, invoiceNumber: 'INV-4');
      final id5 = await insertRawSale(createdAt: 5000, invoiceNumber: 'INV-5');

      final page1 = await repo.getHistory(limit: 2, offset: 0);
      final page2 = await repo.getHistory(limit: 2, offset: 2);
      final page3 = await repo.getHistory(limit: 2, offset: 4);

      expect(page1.map((s) => s.id), [id5, id4]);
      expect(page2.map((s) => s.id), [id3, id2]);
      expect(page3.map((s) => s.id), [id1]);
    });

    test('getHistory memfilter status', () async {
      await insertRawSale(createdAt: 1000, invoiceNumber: 'INV-A', status: 'completed');
      final debtId = await insertRawSale(
        createdAt: 2000,
        invoiceNumber: 'INV-B',
        status: 'debt_unpaid',
      );
      await insertRawSale(createdAt: 3000, invoiceNumber: 'INV-C', status: 'voided');

      final result = await repo.getHistory(status: 'debt_unpaid', limit: 10, offset: 0);

      expect(result, hasLength(1));
      expect(result.single.id, debtId);
      expect(result.single.status, 'debt_unpaid');
    });

    test('getHistory memfilter paymentMethod', () async {
      final cashId = await insertRawSale(
        createdAt: 1000,
        invoiceNumber: 'INV-D',
        paymentMethod: 'cash',
      );
      await insertRawSale(createdAt: 2000, invoiceNumber: 'INV-E', paymentMethod: 'noncash');

      final result = await repo.getHistory(paymentMethod: 'cash', limit: 10, offset: 0);

      expect(result, hasLength(1));
      expect(result.single.id, cashId);
    });

    test('getHistory memfilter rentang tanggal (inklusif)', () async {
      await insertRawSale(createdAt: 1000, invoiceNumber: 'INV-F');
      final inRangeId = await insertRawSale(createdAt: 5000, invoiceNumber: 'INV-G');
      await insertRawSale(createdAt: 9000, invoiceNumber: 'INV-H');

      final result = await repo.getHistory(
        startDate: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
        endDate: DateTime.fromMillisecondsSinceEpoch(7000, isUtc: true),
        limit: 10,
        offset: 0,
      );

      expect(result, hasLength(1));
      expect(result.single.id, inRangeId);
    });
  });

  group('SaleRepositoryImpl — detail transaksi', () {
    test('getDetail mengembalikan header + seluruh item tersimpan', () async {
      final productId = await insertProduct(stock: 10, sellPrice: 5000);
      final saved = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 2,
            sellPrice: 5000,
            costPrice: 3000,
          ),
          const CartItem(key: 'f_1', name: 'Jasa Bungkus', unit: 'pcs', qty: 1, sellPrice: 1000),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 11000,
      );

      final detail = await repo.getDetail(saved.saleId);

      expect(detail.invoiceNumber, saved.invoiceNumber);
      expect(detail.status, 'completed');
      expect(detail.items, hasLength(2));
      expect(detail.items.map((i) => i.name), containsAll(['Teh Botol', 'Jasa Bungkus']));

      // getDetail (dibaca ulang dari DB, bukan dari state saveSale di
      // memori) juga harus membawa snapshot costPrice per item — item
      // terdaftar (Teh Botol) punya snapshot, item bebas (Jasa Bungkus)
      // tidak (plan.md M6 perbaikan tertunda).
      final tehBotol = detail.items.firstWhere((i) => i.name == 'Teh Botol');
      final jasaBungkus = detail.items.firstWhere((i) => i.name == 'Jasa Bungkus');
      expect(tehBotol.costPrice, 3000);
      expect(jasaBungkus.costPrice, isNull);
    });

    test('getDetail melempar TransaksiTidakDitemukanException untuk id tidak ada', () {
      expect(
        () => repo.getDetail(999999),
        throwsA(isA<TransaksiTidakDitemukanException>()),
      );
    });
  });

  group('SaleRepositoryImpl — pelunasan hutang', () {
    test('markDebtPaid mengubah status jadi completed & mengisi debt_paid_at', () async {
      final productId = await insertProduct(stock: 10, sellPrice: 5000);
      final saved = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 5000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'debt',
        paidAmount: 0,
        customerName: 'Budi',
      );

      var sale = (await db.select(db.sales).get()).single;
      expect(sale.status, 'debt_unpaid');
      expect(sale.debtPaidAt, isNull);

      await repo.markDebtPaid(saved.saleId);

      sale = (await db.select(db.sales).get()).single;
      expect(sale.status, 'completed');
      expect(sale.debtPaidAt, isNotNull);
    });

    test(
      'markDebtPaid melempar TransaksiBukanHutangException untuk transaksi '
      'voided & TIDAK menghidupkannya kembali (guard status di UPDATE)',
      () async {
        final productId = await insertProduct(stock: 10, sellPrice: 5000);
        final saved = await repo.saveSale(
          items: [
            CartItem(
              key: 'p_$productId',
              productId: productId,
              name: 'Teh Botol',
              unit: 'pcs',
              qty: 1,
              sellPrice: 5000,
            ),
          ],
          transactionDiscount: 0,
          paymentMethod: 'debt',
          paidAmount: 0,
          customerName: 'Budi',
        );

        // Void menyelip lebih dulu (mis. dari layar lain) — stok sudah
        // dikembalikan. Pelunasan yang datang terlambat TIDAK boleh
        // mengubah voided menjadi completed, karena omzetnya akan
        // terhitung lagi padahal barangnya sudah kembali ke rak.
        await repo.voidSale(saved.saleId);

        await expectLater(
          repo.markDebtPaid(saved.saleId),
          throwsA(isA<TransaksiBukanHutangException>()),
        );

        final sale = (await db.select(db.sales).get()).single;
        expect(sale.status, 'voided', reason: 'transaksi voided tidak boleh hidup lagi');
        expect(sale.debtPaidAt, isNull);
      },
    );
  });

  group('SaleRepositoryImpl — void transaksi', () {
    test('voidSale mengembalikan stok & mencatat stock_movements(void_return) per item terdaftar', () async {
      final productA = await insertProduct(name: 'A', stock: 10, sellPrice: 5000);
      final productB = await insertProduct(name: 'B', stock: 20, sellPrice: 3000);

      final saved = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productA',
            productId: productA,
            name: 'A',
            unit: 'pcs',
            qty: 2,
            sellPrice: 5000,
          ),
          CartItem(
            key: 'p_$productB',
            productId: productB,
            name: 'B',
            unit: 'pcs',
            qty: 3,
            sellPrice: 3000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 19000,
      );

      final stockAAfterSale = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productA))).getSingle();
      final stockBAfterSale = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productB))).getSingle();
      expect(stockAAfterSale.stock, 8);
      expect(stockBAfterSale.stock, 17);

      await repo.voidSale(saved.saleId);

      final sale = (await db.select(db.sales).get()).single;
      expect(sale.status, 'voided');
      expect(sale.voidedAt, isNotNull);

      final stockAAfterVoid = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productA))).getSingle();
      final stockBAfterVoid = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productB))).getSingle();
      expect(stockAAfterVoid.stock, 10, reason: 'stok A kembali ke semula');
      expect(stockBAfterVoid.stock, 20, reason: 'stok B kembali ke semula');

      final voidReturns = await (db.select(
        db.stockMovements,
      )..where((m) => m.type.equals('void_return'))).get();
      expect(voidReturns, hasLength(2));
      expect(voidReturns.every((m) => m.referenceSaleId == saved.saleId), isTrue);
      final qtyByProduct = {for (final m in voidReturns) m.productId: m.qtyChange};
      expect(qtyByProduct[productA], 2);
      expect(qtyByProduct[productB], 3);
    });

    test('voidSale TIDAK menyentuh stok untuk item bebas (productId null)', () async {
      final productId = await insertProduct(stock: 5, sellPrice: 5000);
      final saved = await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$productId',
            productId: productId,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 5000,
          ),
          const CartItem(key: 'f_1', name: 'Jasa Bungkus', unit: 'pcs', qty: 1, sellPrice: 1000),
        ],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 6000,
      );

      await repo.voidSale(saved.saleId);

      final voidReturns = await (db.select(
        db.stockMovements,
      )..where((m) => m.type.equals('void_return'))).get();
      expect(
        voidReturns,
        hasLength(1),
        reason: 'hanya item terdaftar yang dikembalikan stoknya, item bebas dilewati',
      );
      expect(voidReturns.single.productId, productId);

      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();
      expect(product.stock, 5, reason: 'stok produk terdaftar kembali ke semula');
    });

    test('voidSale melempar TransaksiTidakDitemukanException untuk id tidak ada', () {
      expect(
        () => repo.voidSale(999999),
        throwsA(isA<TransaksiTidakDitemukanException>()),
      );
    });

    test(
      'voidSale melempar TransaksiSudahDibatalkanException bila dipanggil dua kali, '
      'stok TIDAK dikembalikan dobel',
      () async {
        final productId = await insertProduct(stock: 10, sellPrice: 5000);
        final saved = await repo.saveSale(
          items: [
            CartItem(
              key: 'p_$productId',
              productId: productId,
              name: 'Teh Botol',
              unit: 'pcs',
              qty: 2,
              sellPrice: 5000,
            ),
          ],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 10000,
        );

        await repo.voidSale(saved.saleId);
        final stockAfterFirstVoid = await (db.select(
          db.products,
        )..where((p) => p.id.equals(productId))).getSingle();
        expect(stockAfterFirstVoid.stock, 10);

        await expectLater(
          repo.voidSale(saved.saleId),
          throwsA(isA<TransaksiSudahDibatalkanException>()),
        );

        final stockAfterSecondAttempt = await (db.select(
          db.products,
        )..where((p) => p.id.equals(productId))).getSingle();
        expect(stockAfterSecondAttempt.stock, 10, reason: 'stok tidak dikembalikan dua kali');
      },
    );

    test(
      'voidSale melempar HutangSudahLunasException untuk hutang yang sudah '
      'dilunasi — status, stok, dan stock_movements tidak berubah',
      () async {
        final productId = await insertProduct(stock: 10, sellPrice: 5000);
        final saved = await repo.saveSale(
          items: [
            CartItem(
              key: 'p_$productId',
              productId: productId,
              name: 'Teh Botol',
              unit: 'pcs',
              qty: 2,
              sellPrice: 5000,
            ),
          ],
          transactionDiscount: 0,
          paymentMethod: 'debt',
          paidAmount: 0,
          customerName: 'Budi',
        );
        await repo.markDebtPaid(saved.saleId);

        // Uang pelunasan sudah diterima — membatalkan transaksinya akan
        // menghapus omzet dari laporan tanpa mengeluarkan uang dari laci.
        await expectLater(
          repo.voidSale(saved.saleId),
          throwsA(isA<HutangSudahLunasException>()),
        );

        final sale = (await db.select(db.sales).get()).single;
        expect(sale.status, 'completed');
        expect(sale.voidedAt, isNull);

        final stock = await (db.select(
          db.products,
        )..where((p) => p.id.equals(productId))).getSingle();
        expect(stock.stock, 8, reason: 'stok TIDAK dikembalikan');

        final voidReturns = await (db.select(
          db.stockMovements,
        )..where((m) => m.type.equals('void_return'))).get();
        expect(voidReturns, isEmpty);
      },
    );
  });
}
