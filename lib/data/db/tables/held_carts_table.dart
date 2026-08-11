import 'package:drift/drift.dart';

/// Transaksi yang ditahan/parkir (hold). Lihat architecture.md §4.
class HeldCarts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get label => text().nullable()();

  /// Serialisasi (JSON) isi keranjang.
  TextColumn get cartJson => text()();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();
}
