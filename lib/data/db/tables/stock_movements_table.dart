import 'package:drift/drift.dart';

import 'products_table.dart';
import 'sales_table.dart';
import 'users_table.dart';

/// Pergerakan stok (audit trail). Lihat architecture.md §4.
///
/// `type`: 'sale' | 'void_return' | 'adjust_in' | 'adjust_out' | 'opname'.
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId => integer().references(Products, #id)();

  TextColumn get type => text()();

  /// +masuk / -keluar.
  RealColumn get qtyChange => real()();

  RealColumn get stockAfter => real()();

  IntColumn get referenceSaleId =>
      integer().nullable().references(Sales, #id)();

  TextColumn get note => text().nullable()();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();

  /// Siapa yang melakukan penyesuaian ini (PRD v1.1 §8.3.D, AC-8.8).
  /// `null` untuk pergerakan lama & mode single-user.
  IntColumn get userId => integer().nullable().references(Users, #id)();
}
