import 'package:drift/drift.dart';

/// Transaksi penjualan (header). Lihat architecture.md §4.
///
/// `paymentMethod`: 'cash' | 'noncash' | 'debt'.
/// `status`: 'completed' | 'debt_unpaid' | 'voided'.
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Format: `YYYYMMDD-XXXX`, dibangkitkan berurutan per hari.
  TextColumn get invoiceNumber => text().unique()();

  IntColumn get subtotal => integer()();

  /// Diskon level transaksi.
  IntColumn get discount => integer().withDefault(const Constant(0))();

  IntColumn get total => integer()();

  TextColumn get paymentMethod => text()();

  IntColumn get paidAmount => integer().withDefault(const Constant(0))();

  IntColumn get changeAmount => integer().withDefault(const Constant(0))();

  /// Wajib jika hutang.
  TextColumn get customerName => text().nullable()();

  TextColumn get status => text()();

  TextColumn get note => text().nullable()();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();

  /// Epoch millis UTC.
  IntColumn get voidedAt => integer().nullable()();

  /// Epoch millis UTC.
  IntColumn get debtPaidAt => integer().nullable()();
}
