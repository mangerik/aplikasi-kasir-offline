import '../../domain/repositories/settings_repository.dart';
import '../db/app_database.dart' as db;

/// Implementasi [SettingsRepository] di atas Drift/SQLite — tabel
/// `settings` (key-value), lihat architecture.md §4.
///
/// Milestone 3 hanya memakai [getValue] (hook PIN sebelum void, lihat
/// `features/transactions/utils/pin_gate.dart`). Method tulis (`setValue`,
/// dsb.) menyusul di Milestone 5 bersama layar Pengaturan.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Future<String?> getValue(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
