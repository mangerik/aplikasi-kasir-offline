import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/settings_repository_impl.dart';

void main() {
  late AppDatabase db;
  late SettingsRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsRepositoryImpl — getValue', () {
    test('mengembalikan null bila key belum pernah diisi (mis. pin_hash belum diset)', () async {
      final value = await repo.getValue('pin_hash');
      expect(value, isNull);
    });

    test('mengembalikan nilai tersimpan bila key sudah diisi', () async {
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'pin_hash', value: 'abc123'));

      final value = await repo.getValue('pin_hash');
      expect(value, 'abc123');
    });
  });
}
