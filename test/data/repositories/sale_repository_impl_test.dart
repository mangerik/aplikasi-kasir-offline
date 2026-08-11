import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';

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
}
