import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/stock_repository_impl.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';

void main() {
  late AppDatabase db;
  late StockRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = StockRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertProduct({String name = 'Beras', double stock = 10}) {
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            sellPrice: 10000,
            stock: Value(stock),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  }

  group('StockRepositoryImpl — adjustStock (plan.md Milestone 4 poin 1)', () {
    test('adjust_in menambah stok & mencatat qtyChange positif', () async {
      final productId = await insertProduct(stock: 10);

      await repo.adjustStock(
        productId: productId,
        type: 'adjust_in',
        amount: 5,
        note: 'Belanja stok baru',
      );

      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();
      expect(product.stock, 15);

      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.type, 'adjust_in');
      expect(movements.single.qtyChange, 5);
      expect(movements.single.stockAfter, 15);
      expect(movements.single.note, 'Belanja stok baru');
      expect(movements.single.referenceSaleId, isNull);
    });

    test('adjust_out mengurangi stok & mencatat qtyChange negatif', () async {
      final productId = await insertProduct(stock: 10);

      await repo.adjustStock(
        productId: productId,
        type: 'adjust_out',
        amount: 4,
        note: 'Barang rusak',
      );

      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();
      expect(product.stock, 6);

      final movement = (await db.select(db.stockMovements).get()).single;
      expect(movement.type, 'adjust_out');
      expect(movement.qtyChange, -4);
      expect(movement.stockAfter, 6);
    });

    test('opname mengganti stok ke nilai ABSOLUT & qtyChange = selisih', () async {
      final productId = await insertProduct(stock: 10);

      await repo.adjustStock(
        productId: productId,
        type: 'opname',
        amount: 7,
        note: 'Hasil hitung fisik',
      );

      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();
      expect(product.stock, 7, reason: 'opname menyetel stok absolut, bukan menambah');

      final movement = (await db.select(db.stockMovements).get()).single;
      expect(movement.type, 'opname');
      expect(movement.qtyChange, -3); // 7 - 10
      expect(movement.stockAfter, 7);
    });

    test('opname dengan hasil hitung LEBIH BESAR dari stok sekarang -> qtyChange positif', () async {
      final productId = await insertProduct(stock: 10);

      await repo.adjustStock(
        productId: productId,
        type: 'opname',
        amount: 25,
        note: 'Ternyata lebih banyak',
      );

      final movement = (await db.select(db.stockMovements).get()).single;
      expect(movement.qtyChange, 15); // 25 - 10
      expect(movement.stockAfter, 25);
    });

    test('adjustStock melempar ProdukTidakDitemukanException untuk productId tidak ada', () {
      expect(
        () => repo.adjustStock(productId: 999999, type: 'adjust_in', amount: 1, note: 'x'),
        throwsA(isA<ProdukTidakDitemukanException>()),
      );
    });

    test('adjustStock gagal (produk tidak ada) TIDAK meninggalkan baris stock_movements (atomik)', () async {
      await expectLater(
        repo.adjustStock(productId: 999999, type: 'adjust_in', amount: 1, note: 'x'),
        throwsA(isA<ProdukTidakDitemukanException>()),
      );

      final movements = await db.select(db.stockMovements).get();
      expect(movements, isEmpty);
    });
  });

  group('StockRepositoryImpl — getMovements (riwayat pergerakan, plan.md Milestone 4 poin 2)', () {
    test('getMovements urut terbaru dulu, LIMIT/OFFSET tanpa duplikat', () async {
      final productId = await insertProduct(stock: 100);
      for (var i = 0; i < 5; i++) {
        await repo.adjustStock(
          productId: productId,
          type: 'adjust_in',
          amount: 1,
          note: 'ke-$i',
        );
      }

      final page1 = await repo.getMovements(productId: productId, limit: 2, offset: 0);
      final page2 = await repo.getMovements(productId: productId, limit: 2, offset: 2);

      expect(page1.map((m) => m.note), ['ke-4', 'ke-3']);
      expect(page2.map((m) => m.note), ['ke-2', 'ke-1']);
    });

    test('getMovements hanya mengembalikan pergerakan milik productId yang diminta', () async {
      final productA = await insertProduct(name: 'A', stock: 10);
      final productB = await insertProduct(name: 'B', stock: 10);
      await repo.adjustStock(productId: productA, type: 'adjust_in', amount: 1, note: 'a');
      await repo.adjustStock(productId: productB, type: 'adjust_in', amount: 1, note: 'b');

      final result = await repo.getMovements(productId: productA, limit: 10, offset: 0);
      expect(result, hasLength(1));
      expect(result.single.productId, productA);
    });

    test('getMovements menyertakan nomor invoice referensi untuk pergerakan dari transaksi', () async {
      final productId = await insertProduct(stock: 10);
      final saleId = await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              invoiceNumber: '20260811-0001',
              subtotal: 10000,
              total: 10000,
              paymentMethod: 'cash',
              status: 'completed',
              createdAt: 1,
            ),
          );
      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: productId,
              type: 'sale',
              qtyChange: -1,
              stockAfter: 9,
              referenceSaleId: Value(saleId),
              createdAt: 2,
            ),
          );

      final result = await repo.getMovements(productId: productId, limit: 10, offset: 0);
      expect(result.single.referenceInvoiceNumber, '20260811-0001');
    });
  });
}
