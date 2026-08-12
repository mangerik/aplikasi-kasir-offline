import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/product_repository_impl.dart';
import 'package:kasir_warung/domain/entities/product_import.dart';
import 'package:kasir_warung/domain/repositories/import_exceptions.dart';

/// Penulisan hasil impor ke database (PRD v1.1 §4.3.E–F, §4.6).
///
/// Yang diuji di sini bukan "apakah datanya masuk" saja, melainkan tiga
/// janji yang paling mahal kalau dilanggar:
/// 1. **Stok tidak ditimpa diam-diam** (AC-4.6) — file Excel pengguna
///    hampir selalu lebih tua daripada stok berjalan.
/// 2. **Jejak audit stok tetap utuh** (AC-4.8) — setiap perubahan stok
///    lewat impor punya baris `stock_movements` dengan nama filenya.
/// 3. **Atomik** (AC-4.15) — gagal di tengah berarti NOL produk masuk,
///    bukan separuh katalog yang tidak jelas keadaannya.
void main() {
  late AppDatabase db;
  late ProductRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  const allColumns = {
    ProductImportColumn.name,
    ProductImportColumn.barcode,
    ProductImportColumn.category,
    ProductImportColumn.sellPrice,
    ProductImportColumn.costPrice,
    ProductImportColumn.stock,
    ProductImportColumn.unit,
    ProductImportColumn.lowStockThreshold,
    ProductImportColumn.isActive,
  };

  ProductImportRow row({
    required int excelRow,
    required String name,
    String? barcode,
    String? categoryName,
    int sellPrice = 10000,
    int? costPrice,
    double? stock,
    String? unit,
    double? lowStockThreshold,
    bool? isActive,
    List<ProductImportIssue> issues = const [],
  }) {
    return ProductImportRow(
      excelRow: excelRow,
      rawCells: const [],
      name: name,
      barcode: barcode,
      categoryName: categoryName,
      sellPrice: sellPrice,
      costPrice: costPrice,
      stock: stock,
      unit: unit,
      lowStockThreshold: lowStockThreshold,
      isActive: isActive,
      issues: issues,
    );
  }

  Future<int> seedProduct({
    required String name,
    String? barcode,
    int sellPrice = 5000,
    double stock = 20,
    double? lowStockThreshold,
    bool isActive = true,
  }) async {
    final now = DateTime(2026, 8, 1).millisecondsSinceEpoch;
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            barcode: Value(barcode),
            sellPrice: sellPrice,
            stock: Value(stock),
            lowStockThreshold: Value(lowStockThreshold),
            isActive: Value(isActive),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<Product> productById(int id) =>
      (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();

  // ===================================================================
  // loadImportLookup
  // ===================================================================

  group('loadImportLookup', () {
    test('memuat barcode produk AKTIF maupun NONAKTIF (K-4.7)', () async {
      await seedProduct(name: 'Kopi', barcode: '899123');
      await seedProduct(name: 'Teh Lama', barcode: '888000', isActive: false);
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: 'Minuman', createdAt: 0));

      final lookup = await repo.loadImportLookup();

      expect(lookup.productIdByBarcode.keys, containsAll(['899123', '888000']));
      expect(lookup.activeProductNames, contains('kopi'));
      expect(
        lookup.activeProductNames,
        isNot(contains('teh lama')),
        reason: 'nama hanya dipakai untuk peringatan produk AKTIF',
      );
      expect(lookup.categoryNames, contains('minuman'));
    });
  });

  // ===================================================================
  // Mode duplikat (AC-4.6, AC-4.7)
  // ===================================================================

  group('mode duplikat', () {
    test('Perbarui: harga ikut berubah, STOK TIDAK BERUBAH selama opsi timpa '
        'stok mati (AC-4.6)', () async {
      final id = await seedProduct(
        name: 'Kopi Kapal Api',
        barcode: '899123',
        sellPrice: 2000,
        stock: 37,
      );

      final summary = await repo.importProducts(
        rows: [
          row(
            excelRow: 2,
            name: 'Kopi Kapal Api Special',
            barcode: '899123',
            sellPrice: 2500,
            stock: 5,
          ),
        ],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      final product = await productById(id);
      expect(summary.updatedCount, 1);
      expect(summary.createdCount, 0);
      expect(product.sellPrice, 2500);
      expect(product.name, 'Kopi Kapal Api Special');
      expect(product.stock, 37, reason: 'stok berjalan tidak boleh tergeser');
      expect(await db.select(db.stockMovements).get(), isEmpty);
    });

    test('Lewati: produk lama tidak berubah SAMA SEKALI (AC-4.7)', () async {
      final id = await seedProduct(
        name: 'Kopi Kapal Api',
        barcode: '899123',
        sellPrice: 2000,
        stock: 37,
      );
      final before = await productById(id);

      final summary = await repo.importProducts(
        rows: [
          row(
            excelRow: 2,
            name: 'Nama Baru',
            barcode: '899123',
            sellPrice: 9999,
            stock: 1,
          ),
        ],
        columns: allColumns,
        options: const ProductImportOptions(
          duplicateMode: ProductImportDuplicateMode.skip,
        ),
        fileName: 'produk.xlsx',
      );

      expect(summary.skippedCount, 1);
      expect(summary.updatedCount, 0);
      expect(await productById(id), before);
    });

    test('produk NONAKTIF ikut dicocokkan lewat barcode (K-4.7) — impor '
        'tidak membuat produk kembar', () async {
      final id = await seedProduct(
        name: 'Rokok Lama',
        barcode: '777',
        isActive: false,
      );

      await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Rokok Lama', barcode: '777', isActive: true)],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      final all = await db.select(db.products).get();
      expect(all, hasLength(1));
      expect((await productById(id)).isActive, isTrue);
    });
  });

  // ===================================================================
  // Timpa stok & jejak audit (AC-4.8)
  // ===================================================================

  group('opsi timpa stok', () {
    test('menyala: stok ikut file dan tercatat SATU baris stock_movements '
        'opname dengan nama file (AC-4.8)', () async {
      final id = await seedProduct(name: 'Beras', barcode: '111', stock: 40);

      final summary = await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Beras', barcode: '111', stock: 12.5)],
        columns: allColumns,
        options: const ProductImportOptions(overwriteStock: true),
        fileName: 'produk_stok_agustus.xlsx',
      );

      expect((await productById(id)).stock, 12.5);
      expect(summary.stockMovementCount, 1);

      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.type, 'opname');
      expect(movements.single.qtyChange, -27.5);
      expect(movements.single.stockAfter, 12.5);
      expect(movements.single.note, 'Impor Excel: produk_stok_agustus.xlsx');
    });

    test('menyala tapi stok sama persis: tidak ada baris pergerakan palsu', () async {
      await seedProduct(name: 'Beras', barcode: '111', stock: 40);

      await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Beras', barcode: '111', stock: 40)],
        columns: allColumns,
        options: const ProductImportOptions(overwriteStock: true),
        fileName: 'produk.xlsx',
      );

      expect(await db.select(db.stockMovements).get(), isEmpty);
    });

    test('produk BARU berstok awal mencatat adjust_in saat opsi menyala', () async {
      final summary = await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Gula', barcode: '222', stock: 8)],
        columns: allColumns,
        options: const ProductImportOptions(overwriteStock: true),
        fileName: 'produk.xlsx',
      );

      final movements = await db.select(db.stockMovements).get();
      expect(summary.createdCount, 1);
      expect(movements, hasLength(1));
      expect(movements.single.type, 'adjust_in');
      expect(movements.single.qtyChange, 8);
      expect(movements.single.stockAfter, 8);
    });

    test('mati (default): stok produk lama utuh & tidak ada pergerakan stok', () async {
      final id = await seedProduct(name: 'Beras', barcode: '111', stock: 40);

      await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Beras', barcode: '111', stock: 0)],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      expect((await productById(id)).stock, 40);
      expect(await db.select(db.stockMovements).get(), isEmpty);
    });
  });

  // ===================================================================
  // Kategori (AC-4.9)
  // ===================================================================

  group('kategori', () {
    test('kategori baru dibuat SEKALI saja walau dipakai banyak baris '
        '(AC-4.9)', () async {
      final summary = await repo.importProducts(
        rows: [
          row(excelRow: 2, name: 'Chiki', categoryName: 'Snack'),
          row(excelRow: 3, name: 'Taro', categoryName: 'Snack'),
          row(excelRow: 4, name: 'Teh', categoryName: 'Minuman'),
        ],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      final categories = await db.select(db.categories).get();
      expect(summary.categoriesCreatedCount, 2);
      expect(categories.map((c) => c.name), unorderedEquals(['Snack', 'Minuman']));

      final products = await db.select(db.products).get();
      final snackId = categories.firstWhere((c) => c.name == 'Snack').id;
      expect(
        products.where((p) => p.categoryId == snackId).length,
        2,
        reason: 'dua produk memakai kategori yang SAMA, bukan dua kategori kembar',
      );
    });

    test('kategori yang sudah ada dipakai ulang (pencocokan tanpa memandang '
        'huruf besar-kecil)', () async {
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: 'Sembako', createdAt: 0));

      final summary = await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Beras', categoryName: 'sembako')],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      expect(summary.categoriesCreatedCount, 0);
      expect(await db.select(db.categories).get(), hasLength(1));
    });

    test('opsi kategori otomatis MATI: produk tetap masuk tanpa kategori', () async {
      await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Beras', categoryName: 'Sembako')],
        columns: allColumns,
        options: const ProductImportOptions(autoCreateCategory: false),
        fileName: 'produk.xlsx',
      );

      expect(await db.select(db.categories).get(), isEmpty);
      expect((await db.select(db.products).getSingle()).categoryId, isNull);
    });
  });

  // ===================================================================
  // Kolom yang tidak ada di file (idempotensi export -> import, AC-4.2)
  // ===================================================================

  group('kolom yang tidak ada di file', () {
    test('tidak menimpa nilai lama — threshold produk selamat saat mengimpor '
        'ulang file export v1.0 (AC-4.2)', () async {
      final id = await seedProduct(
        name: 'Kopi',
        barcode: '899123',
        sellPrice: 2500,
        stock: 30,
        lowStockThreshold: 4,
      );

      // File export v1.0 tidak punya kolom "Batas Stok Menipis".
      await repo.importProducts(
        rows: [
          row(
            excelRow: 2,
            name: 'Kopi',
            barcode: '899123',
            sellPrice: 2500,
            stock: 30,
            unit: 'pcs',
            isActive: true,
          ),
        ],
        columns: const {
          ProductImportColumn.name,
          ProductImportColumn.barcode,
          ProductImportColumn.category,
          ProductImportColumn.sellPrice,
          ProductImportColumn.costPrice,
          ProductImportColumn.stock,
          ProductImportColumn.unit,
          ProductImportColumn.isActive,
        },
        options: const ProductImportOptions(),
        fileName: 'produk_stok.xlsx',
      );

      expect((await productById(id)).lowStockThreshold, 4);
    });

    test('impor ulang file yang sama bersifat idempoten: 0 produk baru, nilai '
        'tidak bergeser (AC-4.2)', () async {
      final rows = [
        row(
          excelRow: 2,
          name: 'Kopi',
          barcode: '899123',
          sellPrice: 2500,
          costPrice: 2000,
          stock: 30,
          unit: 'sachet',
          isActive: true,
        ),
      ];
      const options = ProductImportOptions();

      final first = await repo.importProducts(
        rows: rows,
        columns: allColumns,
        options: options,
        fileName: 'produk_stok.xlsx',
      );
      final afterFirst = await db.select(db.products).getSingle();

      final second = await repo.importProducts(
        rows: rows,
        columns: allColumns,
        options: options,
        fileName: 'produk_stok.xlsx',
      );
      final afterSecond = await db.select(db.products).getSingle();

      expect(first.createdCount, 1);
      expect(second.createdCount, 0);
      expect(second.updatedCount, 1);
      expect(afterSecond.copyWith(updatedAt: afterFirst.updatedAt), afterFirst);
      expect(await db.select(db.products).get(), hasLength(1));
    });
  });

  // ===================================================================
  // Atomisitas (AC-4.15)
  // ===================================================================

  group('atomisitas (K-4.5, AC-4.15)', () {
    test('error di baris ke-50 dari 100 -> NOL produk masuk', () async {
      final rows = [
        for (var i = 0; i < 100; i++)
          if (i == 49)
            row(
              excelRow: i + 2,
              name: 'Baris Rusak',
              issues: const [ProductImportIssue.error('harga jual tidak terbaca')],
            )
          else
            row(excelRow: i + 2, name: 'Produk $i', barcode: 'B$i'),
      ];

      await expectLater(
        repo.importProducts(
          rows: rows,
          columns: allColumns,
          options: const ProductImportOptions(),
          fileName: 'produk.xlsx',
        ),
        throwsA(
          isA<BarisImporTidakValidException>().having(
            (e) => e.toString(),
            'pesan',
            allOf(contains('baris 51'), contains('Tidak ada satu pun produk')),
          ),
        ),
      );

      expect(
        await db.select(db.products).get(),
        isEmpty,
        reason: '49 produk sebelum baris rusak wajib ikut dibatalkan',
      );
      expect(await db.select(db.categories).get(), isEmpty);
    });

    test('barcode kembar yang lolos ke repository tidak pernah menabrak '
        'partial unique index — pencocokan dibaca ulang di dalam transaksi', () async {
      // Parser sudah menandai duplikat barcode sebagai error (AC-4.5),
      // jadi keadaan ini hanya mungkin dari pemanggil lain. Yang penting:
      // database tidak boleh berakhir rusak atau setengah jalan.
      final rows = [
        for (var i = 0; i < 30; i++) row(excelRow: i + 2, name: 'Produk $i', barcode: 'B$i'),
        row(excelRow: 40, name: 'Produk Kembar', barcode: 'B0', sellPrice: 7777),
      ];

      final summary = await repo.importProducts(
        rows: rows,
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      final products = await db.select(db.products).get();
      expect(products, hasLength(30), reason: 'tidak ada produk kembar');
      expect(summary.createdCount, 30);
      expect(summary.updatedCount, 1);
      expect(
        products.firstWhere((p) => p.barcode == 'B0').sellPrice,
        7777,
        reason: 'baris terakhir memperbarui produk yang barusan dibuat',
      );
    });

    test('kategori yang sudah terbuat ikut dibatalkan saat impor gagal', () async {
      final rows = [
        row(excelRow: 2, name: 'Chiki', categoryName: 'Snack Baru'),
        row(
          excelRow: 3,
          name: 'Rusak',
          issues: const [ProductImportIssue.error('nama produk kosong')],
        ),
      ];

      await expectLater(
        repo.importProducts(
          rows: rows,
          columns: allColumns,
          options: const ProductImportOptions(),
          fileName: 'produk.xlsx',
        ),
        throwsA(isA<BarisImporTidakValidException>()),
      );

      expect(await db.select(db.categories).get(), isEmpty);
      expect(await db.select(db.products).get(), isEmpty);
    });
  });

  // ===================================================================
  // Produk baru & janji "tidak pernah menghapus" (K-4.6)
  // ===================================================================

  group('produk baru', () {
    test('nilai default dipasang saat kolomnya kosong (unit pcs, stok 0, '
        'aktif)', () async {
      await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Permen', sellPrice: 500)],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      final product = await db.select(db.products).getSingle();
      expect(product.unit, 'pcs');
      expect(product.stock, 0);
      expect(product.isActive, isTrue);
      expect(product.barcode, isNull);
    });

    test('stream daftar produk & hitungan stok menipis ikut ter-refresh '
        'sendiri setelah impor (AC-4.16)', () async {
      final namesFuture = repo
          .watchAll()
          .firstWhere((products) => products.isNotEmpty);
      final lowStockFuture = repo
          .watchLowStockCount(defaultThreshold: 5)
          .firstWhere((count) => count > 0);

      await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Kopi Sachet', barcode: '111', stock: 1)],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      expect((await namesFuture).single.name, 'Kopi Sachet');
      expect(await lowStockFuture, 1);
    });

    test('impor tidak pernah menghapus produk yang tidak ada di file '
        '(K-4.6)', () async {
      await seedProduct(name: 'Produk Lama', barcode: '999');

      await repo.importProducts(
        rows: [row(excelRow: 2, name: 'Produk Baru', barcode: '111')],
        columns: allColumns,
        options: const ProductImportOptions(),
        fileName: 'produk.xlsx',
      );

      final names = (await db.select(db.products).get()).map((p) => p.name);
      expect(names, containsAll(['Produk Lama', 'Produk Baru']));
    });
  });
}
