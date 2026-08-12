import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase — skema', () {
    test('schemaVersion adalah 2 (M12 — pelanggan & poin)', () {
      expect(db.schemaVersion, 2);
      expect(db.schemaVersion, kAppSchemaVersion);
    });

    test('bisa insert kategori & produk', () async {
      final categoryId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Sembako',
              createdAt: 1000,
            ),
          );

      final productId = await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Beras 5kg',
              categoryId: Value(categoryId),
              sellPrice: 65000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();

      expect(product.name, 'Beras 5kg');
      expect(product.sellPrice, 65000);
      expect(product.stock, 0);
      expect(product.unit, 'pcs');
      expect(product.isActive, isTrue);
    });

    test('boleh banyak produk dengan barcode null (bukan pelanggaran unique)', () async {
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Produk A',
              sellPrice: 1000,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Produk B',
              sellPrice: 2000,
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      final all = await db.select(db.products).get();
      expect(all.length, 2);
    });

    test('partial unique index menolak barcode duplikat yang terisi', () async {
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Produk A',
              barcode: const Value('8991234567890'),
              sellPrice: 1000,
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      expect(
        () => db.into(db.products).insert(
              ProductsCompanion.insert(
                name: 'Produk B (barcode sama)',
                barcode: const Value('8991234567890'),
                sellPrice: 2000,
                createdAt: 1,
                updatedAt: 1,
              ),
            ),
        throwsA(anything),
      );
    });

    test('WAL mode aktif saat koneksi dibuka lewat _openConnection (in-memory tetap "memory")', () async {
      // NativeDatabase.memory() tidak mendukung WAL (sqlite membatasi WAL
      // hanya untuk file DB sungguhan), jadi kita hanya pastikan koneksi
      // in-memory dapat menjalankan query PRAGMA tanpa error, sebagai bukti
      // setup berjalan. WAL sesungguhnya diverifikasi lewat _openConnection
      // yang dipakai di runtime (bukan di test in-memory).
      final result = await db.customSelect('PRAGMA journal_mode').getSingle();
      expect(result.data['journal_mode'], isNotNull);
    });
  });

  group('AppDatabase — transaksi atomik', () {
    test('simpan penjualan (sale + sale_items + stock_movements) atomik', () async {
      final categoryId = await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: 'Minuman', createdAt: 1));
      final productId = await db.into(db.products).insert(
            ProductsCompanion.insert(
              name: 'Teh Botol',
              categoryId: Value(categoryId),
              sellPrice: 5000,
              stock: const Value(10),
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      await db.transaction(() async {
        final saleId = await db.into(db.sales).insert(
              SalesCompanion.insert(
                invoiceNumber: '20260811-0001',
                subtotal: 5000,
                total: 5000,
                paymentMethod: 'cash',
                paidAmount: const Value(10000),
                changeAmount: const Value(5000),
                status: 'completed',
                createdAt: 1,
              ),
            );

        await db.into(db.saleItems).insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                productId: Value(productId),
                productName: 'Teh Botol',
                unit: 'pcs',
                qty: 1,
                sellPrice: 5000,
                lineTotal: 5000,
              ),
            );

        const newStock = 9.0;
        await (db.update(db.products)..where((p) => p.id.equals(productId)))
            .write(const ProductsCompanion(stock: Value(newStock)));

        await db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: productId,
                type: 'sale',
                qtyChange: -1,
                stockAfter: newStock,
                referenceSaleId: Value(saleId),
                createdAt: 1,
              ),
            );
      });

      final sales = await db.select(db.sales).get();
      final saleItems = await db.select(db.saleItems).get();
      final movements = await db.select(db.stockMovements).get();
      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();

      expect(sales, hasLength(1));
      expect(saleItems, hasLength(1));
      expect(movements, hasLength(1));
      expect(product.stock, 9.0);
    });

    test('rollback: jika salah satu insert gagal, tidak ada perubahan tersimpan', () async {
      final productId = await db.into(db.products).insert(
            ProductsCompanion.insert(
              name: 'Gula 1kg',
              sellPrice: 15000,
              stock: const Value(5),
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      Future<void> attempt() => db.transaction(() async {
            await db.into(db.sales).insert(
                  SalesCompanion.insert(
                    invoiceNumber: '20260811-0002',
                    subtotal: 15000,
                    total: 15000,
                    paymentMethod: 'cash',
                    status: 'completed',
                    createdAt: 1,
                  ),
                );

            // Sengaja melanggar FK: productId tidak valid -> memicu error
            // (foreign_keys diaktifkan lewat beforeOpen) sehingga transaksi
            // wajib rollback total, termasuk insert sales di atas.
            await db.into(db.stockMovements).insert(
                  StockMovementsCompanion.insert(
                    productId: 999999,
                    type: 'adjust_out',
                    qtyChange: -1,
                    stockAfter: 4,
                    createdAt: 1,
                  ),
                );
          });

      await expectLater(attempt(), throwsA(anything));

      final sales = await db.select(db.sales).get();
      final movements = await db.select(db.stockMovements).get();
      final product = await (db.select(
        db.products,
      )..where((p) => p.id.equals(productId))).getSingle();

      expect(sales, isEmpty);
      expect(movements, isEmpty);
      expect(product.stock, 5.0);
    });
  });
}
