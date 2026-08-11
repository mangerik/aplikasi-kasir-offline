import 'package:drift/drift.dart';

import 'categories_table.dart';

/// Produk. Lihat architecture.md §4.
///
/// `barcode` unik hanya jika terisi — dijamin lewat partial unique index
/// yang dibuat manual di [AppDatabase] (bukan lewat constraint kolom biasa,
/// karena SQLite `UNIQUE` standar tidak mengizinkan banyak baris NULL di
/// beberapa dialect lain; SQLite sendiri sebenarnya sudah memperbolehkan
/// banyak NULL, tapi partial index dipertahankan sesuai dokumentasi
/// arsitektur agar eksplisit).
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get barcode => text().nullable()();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// Harga jual (Rp).
  IntColumn get sellPrice => integer()();

  /// Harga modal (Rp), opsional.
  IntColumn get costPrice => integer().nullable()();

  /// REAL agar mendukung satuan desimal (kg/liter).
  RealColumn get stock => real().withDefault(const Constant(0))();

  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  /// null = pakai default global dari `settings`.
  RealColumn get lowStockThreshold => real().nullable()();

  TextColumn get imagePath => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();

  /// Epoch millis UTC.
  IntColumn get updatedAt => integer()();
}
