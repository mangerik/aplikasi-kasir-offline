import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/product_repository_impl.dart';

/// Uji performa pencarian produk (plan.md Milestone 6 poin 3, PRD §6:
/// "pencarian produk instan (< 100 ms) pada 5.000 produk").
///
/// 5.000 produk di-generate lewat `db.batch()` (bulk insert langsung ke
/// Drift, sama seperti pola `report_repository_impl_performance_test.dart`
/// Milestone 4 — jauh lebih cepat daripada insert satu-satu, dan test ini
/// HANYA perlu mengukur kecepatan QUERY pencarian, bukan kecepatan insert).
/// Query yang diukur adalah `ProductRepositoryImpl.watchAll(query: ...)` —
/// PERSIS method yang dipakai `productListProvider`/`posProductListProvider`
/// (tab Produk & grid Kasir) — diambil nilai pertamanya (`.first`) supaya
/// setara dengan satu kali eksekusi query di atas koneksi Drift in-memory
/// (bukan device nyata, tapi cukup untuk membuktikan query itu sendiri —
/// termasuk index `idx_products_name`/`idx_products_barcode` — tidak jadi
/// bottleneck berarti pada skala 5rb baris).
void main() {
  late AppDatabase db;
  late ProductRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'pencarian produk (watchAll query: ...) <100ms dengan 5.000 produk',
    () async {
      const totalProducts = 5000;
      final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;

      final rows = List<ProductsCompanion>.generate(totalProducts, (i) {
        // Sebagian produk memakai nama/barcode yang bisa dicocokkan pencarian
        // di bawah, supaya hasil query tidak kosong (sanity check nyata).
        final name = i % 37 == 0 ? 'Kopi Sachet Sasetan $i' : 'Produk Dummy $i';
        return ProductsCompanion.insert(
          name: name,
          barcode: Value('89999${i.toString().padLeft(8, '0')}'),
          sellPrice: 5000 + (i % 50) * 100,
          stock: Value((i % 30).toDouble()),
          createdAt: now,
          updatedAt: now,
        );
      });
      await db.batch((batch) => batch.insertAll(db.products, rows));

      // Query teks (nama ATAU barcode, LIKE '%...%') — jalur pencarian utama
      // dipakai kasir/tab Produk, bukan lookup exact barcode.
      final textStopwatch = Stopwatch()..start();
      final textResults = await repo.watchAll(query: 'Sasetan').first;
      textStopwatch.stop();

      // Query barcode persis — dipakai jalur scan barcode.
      final barcodeStopwatch = Stopwatch()..start();
      final barcodeResults = await repo.watchAll(query: '8999900000037').first;
      barcodeStopwatch.stop();

      // Query TANPA filter (daftar penuh, kasus terberat) — dipakai saat
      // kolom pencarian kosong.
      final allStopwatch = Stopwatch()..start();
      final allResults = await repo.watchAll().first;
      allStopwatch.stop();

      expect(textResults, isNotEmpty);
      expect(barcodeResults, isNotEmpty);
      expect(allResults, hasLength(totalProducts));

      expect(
        textStopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Pencarian teks produk harus <100ms pada 5.000 produk (PRD §6)',
      );
      expect(
        barcodeStopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Pencarian barcode produk harus <100ms pada 5.000 produk (PRD §6)',
      );
      expect(
        allStopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Memuat seluruh daftar produk (tanpa filter) harus <100ms pada 5.000 produk',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
