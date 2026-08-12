import 'package:drift/drift.dart';

import 'customers_table.dart';

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

  /// Wajib jika hutang. **SNAPSHOT HISTORIS** (K-7.1) — tidak pernah
  /// dihapus dan tidak pernah ikut berubah saat pelanggan di-*rename*,
  /// persis seperti `sale_items.product_name`. Untuk identitas pelanggan
  /// yang hidup, pakai [customerId].
  TextColumn get customerName => text().nullable()();

  /// Tautan ke pelanggan (PRD v1.1 §7.5, `schemaVersion` 2). `null` untuk
  /// transaksi tanpa pelanggan — alur kasir tanpa nama tetap nol tap
  /// tambahan (AC-7.5).
  IntColumn get customerId =>
      integer().nullable().references(Customers, #id)();

  TextColumn get status => text()();

  TextColumn get note => text().nullable()();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();

  /// Epoch millis UTC.
  IntColumn get voidedAt => integer().nullable()();

  /// Epoch millis UTC.
  IntColumn get debtPaidAt => integer().nullable()();
}
