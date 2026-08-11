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

  group('SettingsRepositoryImpl — setValue', () {
    test('menyimpan nilai baru (insert) bila key belum ada', () async {
      await repo.setValue('store_name', 'Warung Bu Siti');
      expect(await repo.getValue('store_name'), 'Warung Bu Siti');
    });

    test('menimpa nilai lama (upsert) bila key sudah ada', () async {
      await repo.setValue('store_name', 'Nama Lama');
      await repo.setValue('store_name', 'Nama Baru');

      expect(await repo.getValue('store_name'), 'Nama Baru');
      final rows = await db.select(db.settings).get();
      expect(rows.where((r) => r.key == 'store_name'), hasLength(1));
    });
  });

  group('SettingsRepositoryImpl — deleteValue', () {
    test('menghapus key yang sudah diisi', () async {
      await repo.setValue('pin_hash', 'abc123');
      await repo.deleteValue('pin_hash');
      expect(await repo.getValue('pin_hash'), isNull);
    });

    test('tidak error bila key belum pernah diisi', () async {
      await expectLater(repo.deleteValue('tidak_ada'), completes);
    });
  });
}
