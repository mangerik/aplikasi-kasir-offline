import 'package:drift/drift.dart';

/// Kategori produk. Lihat architecture.md §4.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();
}
