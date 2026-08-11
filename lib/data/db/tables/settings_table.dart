import 'package:drift/drift.dart';

/// Pengaturan key-value: `store_name`, `store_address`, `store_phone`,
/// `low_stock_default`, `pin_hash`, dll. Lihat architecture.md §4.
class Settings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
