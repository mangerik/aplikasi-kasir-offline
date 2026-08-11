import '../../domain/repositories/settings_repository.dart';
import '../db/app_database.dart' as db;

/// Implementasi [SettingsRepository] di atas Drift/SQLite — tabel
/// `settings` (key-value), lihat architecture.md §4.
///
/// [getValue] sudah dipakai sejak Milestone 3 (hook PIN sebelum void,
/// lihat `features/transactions/utils/pin_gate.dart`). [setValue]/
/// [deleteValue] ditambah di Milestone 5 untuk layar Pengaturan penuh.
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

  @override
  Future<void> setValue(String key, String value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(db.SettingsCompanion.insert(key: key, value: value));
  }

  @override
  Future<void> deleteValue(String key) async {
    await (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();
  }
}
