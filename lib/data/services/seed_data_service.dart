import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../../core/utils/date_formatter.dart';
import '../db/app_database.dart';

/// Mengisi beberapa kategori & produk contoh agar pengembangan/QA UI tidak
/// mulai dari database kosong.
///
/// Hanya berjalan saat [kDebugMode] (lihat plan.md Milestone 0) dan hanya
/// jika tabel `products` masih kosong, supaya aman dipanggil berulang kali
/// (mis. tiap hot restart) tanpa membuat data ganda.
class SeedDataService {
  const SeedDataService(this._db);

  final AppDatabase _db;

  Future<void> seedIfNeeded() async {
    if (!kDebugMode) return;

    final existing = await (_db.select(
      _db.products,
    )..limit(1)).getSingleOrNull();
    if (existing != null) return;

    final now = DateFormatter.toEpochMillis(DateTime.now());

    await _db.transaction(() async {
      final sembakoId = await _db
          .into(_db.categories)
          .insert(CategoriesCompanion.insert(name: 'Sembako', createdAt: now));
      final minumanId = await _db
          .into(_db.categories)
          .insert(CategoriesCompanion.insert(name: 'Minuman', createdAt: now));
      final snackId = await _db.into(_db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Makanan Ringan',
              createdAt: now,
            ),
          );

      final products = <ProductsCompanion>[
        ProductsCompanion.insert(
          name: 'Beras 5kg',
          categoryId: Value(sembakoId),
          barcode: const Value('8991002123001'),
          sellPrice: 65000,
          costPrice: const Value(60000),
          stock: const Value(20),
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          name: 'Minyak Goreng 1L',
          categoryId: Value(sembakoId),
          barcode: const Value('8991002123002'),
          sellPrice: 18000,
          costPrice: const Value(16000),
          stock: const Value(30),
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          name: 'Gula Pasir 1kg',
          categoryId: Value(sembakoId),
          barcode: const Value('8991002123003'),
          sellPrice: 15000,
          costPrice: const Value(13500),
          stock: const Value(25),
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          name: 'Teh Botol Sosro 450ml',
          categoryId: Value(minumanId),
          barcode: const Value('8991002123004'),
          sellPrice: 5000,
          costPrice: const Value(4000),
          stock: const Value(48),
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          name: 'Air Mineral 600ml',
          categoryId: Value(minumanId),
          barcode: const Value('8991002123005'),
          sellPrice: 4000,
          costPrice: const Value(3000),
          stock: const Value(60),
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          name: 'Indomie Goreng',
          categoryId: Value(snackId),
          barcode: const Value('8991002123006'),
          sellPrice: 3500,
          costPrice: const Value(2800),
          stock: const Value(100),
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          name: 'Kerupuk (per 100g)',
          categoryId: Value(snackId),
          sellPrice: 2000,
          costPrice: const Value(1200),
          stock: const Value(5),
          unit: const Value('kg'),
          lowStockThreshold: const Value(2),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      for (final product in products) {
        await _db.into(_db.products).insert(product);
      }
    });
  }
}
