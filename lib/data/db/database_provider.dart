import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Instance tunggal [AppDatabase] untuk seluruh aplikasi (lihat
/// architecture.md §6, tabel Riverpod Provider).
///
/// Repository (Milestone 1+) mengonsumsi provider ini — layar `features/`
/// tidak boleh mengimpor Drift/`AppDatabase` secara langsung, selalu lewat
/// repository.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
