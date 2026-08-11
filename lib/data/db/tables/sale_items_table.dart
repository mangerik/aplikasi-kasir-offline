import 'package:drift/drift.dart';

import 'products_table.dart';
import 'sales_table.dart';

/// Item transaksi (detail) — snapshot, tidak berubah walau produk diedit
/// belakangan. Lihat architecture.md §4.
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId => integer().references(Sales, #id)();

  /// null = item bebas (barang tak terdaftar).
  IntColumn get productId => integer().nullable().references(Products, #id)();

  /// Snapshot nama produk saat transaksi.
  TextColumn get productName => text()();

  TextColumn get unit => text()();

  RealColumn get qty => real()();

  /// Snapshot harga jual saat transaksi.
  IntColumn get sellPrice => integer()();

  /// Snapshot harga modal (untuk hitung laba).
  IntColumn get costPrice => integer().nullable()();

  /// Diskon per item (nominal).
  IntColumn get discount => integer().withDefault(const Constant(0))();

  IntColumn get lineTotal => integer()();
}
