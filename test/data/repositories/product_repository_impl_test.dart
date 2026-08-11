import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/category_repository_impl.dart';
import 'package:kasir_warung/data/repositories/product_repository_impl.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';

void main() {
  late AppDatabase db;
  late ProductRepositoryImpl repo;
  late CategoryRepositoryImpl categoryRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductRepositoryImpl(db);
    categoryRepo = CategoryRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ProductRepositoryImpl — CRUD', () {
    test('createProduct menyimpan produk baru dan mengembalikan id', () async {
      final id = await repo.createProduct(
        name: 'Beras 5kg',
        sellPrice: 65000,
        costPrice: 60000,
        stock: 20,
      );

      final product = await repo.getById(id);
      expect(product, isNotNull);
      expect(product!.name, 'Beras 5kg');
      expect(product.sellPrice, 65000);
      expect(product.costPrice, 60000);
      expect(product.stock, 20);
      expect(product.unit, 'pcs');
      expect(product.isActive, isTrue);
    });

    test('barcode string kosong dianggap tidak diisi (null)', () async {
      final id = await repo.createProduct(name: 'Produk A', sellPrice: 1000, barcode: '   ');
      final product = await repo.getById(id);
      expect(product!.barcode, isNull);
    });

    test('createProduct menolak barcode duplikat dengan pesan Bahasa Indonesia', () async {
      await repo.createProduct(name: 'Produk A', sellPrice: 1000, barcode: '12345');

      expect(
        () => repo.createProduct(name: 'Produk B', sellPrice: 2000, barcode: '12345'),
        throwsA(
          isA<BarcodeSudahDipakaiException>().having(
            (e) => e.toString(),
            'pesan',
            contains('sudah dipakai produk lain'),
          ),
        ),
      );
    });

    test('dua produk boleh sama-sama tanpa barcode', () async {
      await repo.createProduct(name: 'Produk A', sellPrice: 1000);
      await repo.createProduct(name: 'Produk B', sellPrice: 2000);

      final all = await repo.watchAll().first;
      expect(all, hasLength(2));
    });

    test('updateProduct memperbarui field & menolak barcode duplikat produk lain', () async {
      final idA = await repo.createProduct(name: 'Produk A', sellPrice: 1000, barcode: '111');
      final idB = await repo.createProduct(name: 'Produk B', sellPrice: 2000, barcode: '222');

      // updateProduct adalah "full update" (selalu kirim ulang seluruh
      // field, sama seperti form produk di UI) — barcode wajib disertakan
      // ulang di sini, jika tidak akan ter-null-kan (dianggap dikosongkan).
      await repo.updateProduct(
        id: idA,
        name: 'Produk A Updated',
        barcode: '111',
        sellPrice: 1500,
        stock: 10,
        unit: 'kg',
      );
      final updated = await repo.getById(idA);
      expect(updated!.name, 'Produk A Updated');
      expect(updated.barcode, '111');
      expect(updated.sellPrice, 1500);
      expect(updated.stock, 10);
      expect(updated.unit, 'kg');

      expect(
        () => repo.updateProduct(
          id: idB,
          name: 'Produk B',
          barcode: '111',
          sellPrice: 2000,
          stock: 0,
          unit: 'pcs',
        ),
        throwsA(isA<BarcodeSudahDipakaiException>()),
      );
    });

    test('setActive menonaktifkan produk tanpa menghapusnya', () async {
      final id = await repo.createProduct(name: 'Produk A', sellPrice: 1000);

      await repo.setActive(id, false);

      final product = await repo.getById(id);
      expect(product!.isActive, isFalse);

      final all = await repo.watchAll().first;
      expect(all, hasLength(1), reason: 'produk nonaktif tetap tampil di daftar produk');

      final activeOnly = await repo.watchAll(onlyActive: true).first;
      expect(activeOnly, isEmpty, reason: 'produk nonaktif tersembunyi dari Kasir');
    });
  });

  group('ProductRepositoryImpl — pencarian & filter', () {
    test('watchAll query mencari berdasarkan nama ATAU barcode', () async {
      await repo.createProduct(name: 'Teh Botol', sellPrice: 5000, barcode: '999888');
      await repo.createProduct(name: 'Kopi Sachet', sellPrice: 2000, barcode: '111222');

      final byName = await repo.watchAll(query: 'teh').first;
      expect(byName, hasLength(1));
      expect(byName.first.name, 'Teh Botol');

      final byBarcode = await repo.watchAll(query: '111222').first;
      expect(byBarcode, hasLength(1));
      expect(byBarcode.first.name, 'Kopi Sachet');
    });

    test('getByBarcode menemukan produk aktif dengan barcode PERSIS sama', () async {
      await repo.createProduct(name: 'Teh Botol', sellPrice: 5000, barcode: '999888');

      final found = await repo.getByBarcode('999888');
      expect(found, isNotNull);
      expect(found!.name, 'Teh Botol');

      expect(await repo.getByBarcode('tidak-ada'), isNull);
    });

    test('getByBarcode tidak menemukan produk yang sudah dinonaktifkan', () async {
      final id = await repo.createProduct(name: 'Teh Botol', sellPrice: 5000, barcode: '777666');
      await repo.setActive(id, false);

      expect(await repo.getByBarcode('777666'), isNull);
    });

    test('watchAll filter berdasarkan kategori', () async {
      final catA = await categoryRepo.create('Minuman');
      final catB = await categoryRepo.create('Sembako');
      await repo.createProduct(name: 'Teh Botol', sellPrice: 5000, categoryId: catA);
      await repo.createProduct(name: 'Beras', sellPrice: 60000, categoryId: catB);

      final result = await repo.watchAll(categoryId: catA).first;
      expect(result, hasLength(1));
      expect(result.first.name, 'Teh Botol');
    });

    test('watchAll bersifat reaktif (stream emit ulang saat data berubah)', () async {
      final stream = repo.watchAll();
      final emissions = <int>[];
      final sub = stream.listen((products) => emissions.add(products.length));

      await Future<void>.delayed(Duration.zero);
      await repo.createProduct(name: 'Produk A', sellPrice: 1000);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, containsAllInOrder([0, 1]));
      await sub.cancel();
    });
  });

  group('Product entity — stok menipis', () {
    test('isLowStock true bila stok <= threshold per-produk', () async {
      final id = await repo.createProduct(
        name: 'Kerupuk',
        sellPrice: 2000,
        stock: 2,
        lowStockThreshold: 3,
      );
      final product = await repo.getById(id);
      expect(product!.isLowStock, isTrue);
    });

    test('isLowStock pakai default global bila threshold per-produk null', () async {
      final id = await repo.createProduct(name: 'Air Mineral', sellPrice: 4000, stock: 4);
      final product = await repo.getById(id);
      expect(product!.isLowStock, isTrue); // 4 <= defaultLowStockThreshold (5)
    });

    test('isLowStock false bila stok cukup', () async {
      final id = await repo.createProduct(name: 'Air Mineral', sellPrice: 4000, stock: 100);
      final product = await repo.getById(id);
      expect(product!.isLowStock, isFalse);
    });
  });
}
