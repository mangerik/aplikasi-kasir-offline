import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/user_repository_impl.dart';
import 'package:kasir_warung/data/services/backup_service.dart';
import 'package:kasir_warung/domain/entities/app_user.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3lib;

import '../../fixtures/v1_database_fixture.dart';
import '../../fixtures/v2_database_fixture.dart';

/// Uji migrasi `schemaVersion` 2 → 3 di atas **snapshot database v2
/// nyata** (PRD v1.1 AC-10.1) — bukan `createAll()` dari nol.
///
/// Yang dipertaruhkan di sini: pemilik warung yang sudah memasang PIN
/// sejak v1.0 harus tetap bisa masuk memakai PIN yang SAMA setelah
/// aplikasinya diperbarui (AC-8.2). Migrasi yang lupa memindahkan PIN itu
/// akan mengunci pemilik dari datanya sendiri pada hari update — kegagalan
/// terburuk yang bisa dilakukan milestone ini.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kasir_migrasi_v2_');
    dbPath = '${tempDir.path}/kasir_warung.sqlite';
    V2DatabaseFixture.create(dbPath);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<AppDatabase> openMigrated() async {
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test(
    'fixture v2 memang berskema 2 & belum punya tabel users '
    '(prasyarat uji migrasi, AC-10.1)',
    () {
      final raw = sqlite3lib.sqlite3.open(dbPath, mode: sqlite3lib.OpenMode.readOnly);
      addTearDown(raw.close);
      expect(raw.select('PRAGMA user_version').first['user_version'], 2);

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tables, contains('customers'));
      expect(tables, isNot(contains('users')));

      final salesColumns = raw
          .select('PRAGMA table_info(sales)')
          .map((row) => row['name'] as String)
          .toSet();
      expect(salesColumns, contains('customer_id'));
      expect(salesColumns, isNot(contains('user_id')));
      expect(salesColumns, isNot(contains('user_name')));
      expect(salesColumns, isNot(contains('voided_by_user_id')));
    },
  );

  test('membuka database v2 menaikkan user_version ke 3', () async {
    final db = await openMigrated();
    addTearDown(db.close);

    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.read<int>('user_version'), kAppSchemaVersion);
    expect(kAppSchemaVersion, 3);
  });

  test('kolom & tabel M13 terbentuk (PRD §8.5)', () async {
    final db = await openMigrated();
    await db.close();

    final raw = sqlite3lib.sqlite3.open(dbPath, mode: sqlite3lib.OpenMode.readOnly);
    addTearDown(raw.close);

    final salesColumns = raw
        .select('PRAGMA table_info(sales)')
        .map((row) => row['name'] as String)
        .toSet();
    expect(salesColumns, containsAll(['user_id', 'user_name', 'voided_by_user_id']));
    // AC-10.4: kolom lama TETAP ada, tidak ada penulisan ulang tabel.
    expect(salesColumns, containsAll(['customer_id', 'customer_name']));

    final movementColumns = raw
        .select('PRAGMA table_info(stock_movements)')
        .map((row) => row['name'] as String)
        .toSet();
    expect(movementColumns, contains('user_id'));

    final indexes = raw
        .select("SELECT name FROM sqlite_master WHERE type = 'index'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(indexes, contains('idx_users_name_nocase'));
    expect(indexes, contains('idx_sales_user'));
    // Index M12 & M0 tidak boleh hilang.
    expect(indexes, contains('idx_sales_customer'));
    expect(indexes, contains('idx_sales_created_at'));
  });

  test(
    'AC-8.2: PIN global lama menjadi PIN akun "Pemilik" — hash & salt '
    'disalin apa adanya, bukan dibuat ulang',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);

      final users = await db.select(db.users).get();
      expect(users, hasLength(1));
      final owner = users.single;
      expect(owner.name, 'Pemilik');
      expect(owner.role, 'owner');
      expect(owner.isActive, isTrue);
      expect(owner.pinHash, V2DatabaseFixture.pinHash);
      expect(owner.pinSalt, V2DatabaseFixture.pinSalt);
      expect(owner.lastLoginAt, isNull);
    },
  );

  test(
    'AC-8.1: multi_user_enabled TIDAK dinyalakan oleh migrasi & key PIN '
    'lama tetap utuh (perilaku v1.0 dipertahankan)',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);

      final rows = await db.customSelect(
        "SELECT key, value FROM settings",
      ).get();
      final settings = {
        for (final row in rows) row.read<String>('key'): row.read<String>('value'),
      };
      expect(settings['multi_user_enabled'], isNull,
          reason: 'multi-user harus MATI secara default (K-8.5)');
      expect(settings['pin_hash'], V2DatabaseFixture.pinHash);
      expect(settings['pin_salt'], V2DatabaseFixture.pinSalt);
      expect(settings['store_name'], 'Warung Bu Ani');
    },
  );

  test(
    'warung yang belum pernah memasang PIN tidak melahirkan akun Pemilik',
    () async {
      final noPinPath = '${tempDir.path}/tanpa_pin.sqlite';
      V2DatabaseFixture.create(noPinPath, withGlobalPin: false);

      final db = AppDatabase(NativeDatabase(File(noPinPath)));
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      expect(await db.select(db.users).get(), isEmpty);
    },
  );

  test('AC-10.3 & AC-10.4: tidak ada satu baris pun yang hilang', () async {
    final before = V2DatabaseFixture.rowCounts(dbPath);

    final db = await openMigrated();
    await db.close();

    final after = V2DatabaseFixture.rowCounts(dbPath);
    expect(after, before);
  });

  test(
    'transaksi lama tetap ber-user_id NULL — migrasi tidak mengarang jejak',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);

      final rows = await db.select(db.sales).get();
      expect(rows, isNotEmpty);
      expect(rows.every((s) => s.userId == null), isTrue);
      expect(rows.every((s) => s.userName == null), isTrue);
      expect(rows.every((s) => s.voidedByUserId == null), isTrue);
    },
  );

  test('migrasi idempoten: membuka ulang tidak menggandakan akun', () async {
    final first = await openMigrated();
    final countFirst = (await first.select(first.users).get()).length;
    await first.close();

    final second = await openMigrated();
    addTearDown(second.close);
    final countSecond = (await second.select(second.users).get()).length;

    expect(countSecond, countFirst);
    expect(countSecond, 1);
  });

  test(
    'AC-8.15: dua pengguna dengan PIN sama persis tetap masuk ke akunnya '
    'masing-masing',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);
      final repo = UserRepositoryImpl(db);

      final ani = await repo.createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '123456',
      );
      final budi = await repo.createUser(
        name: 'Budi',
        role: UserRole.cashier,
        pin: '123456',
      );

      // Salt per pengguna (K-8.3) → hash berbeda walau PIN-nya sama.
      final aniPin = await repo.storedPin(ani.id);
      final budiPin = await repo.storedPin(budi.id);
      expect(aniPin!.hash, isNot(budiPin!.hash));

      expect((await repo.authenticate(userId: ani.id, pin: '123456'))?.id, ani.id);
      expect((await repo.authenticate(userId: budi.id, pin: '123456'))?.id, budi.id);
      expect(await repo.authenticate(userId: ani.id, pin: '654321'), isNull);
    },
  );

  test(
    'AC-8.7: mengganti nama pengguna TIDAK mengubah user_name transaksi lama',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);
      final repo = UserRepositoryImpl(db);

      final ani = await repo.createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '111111',
      );
      await db.customStatement(
        'UPDATE sales SET user_id = ?1, user_name = ?2 WHERE id = 1',
        [ani.id, 'Ani'],
      );

      await repo.rename(userId: ani.id, name: 'Ani Suryani');

      final row = await db.customSelect(
        'SELECT user_name FROM sales WHERE id = 1',
      ).getSingle();
      expect(row.read<String>('user_name'), 'Ani');
      expect((await repo.findById(ani.id))!.name, 'Ani Suryani');
    },
  );

  test('nama pengguna aktif wajib unik (case-insensitive)', () async {
    final db = await openMigrated();
    addTearDown(db.close);
    final repo = UserRepositoryImpl(db);

    await repo.createUser(name: 'Ani', role: UserRole.cashier, pin: '111111');
    await expectLater(
      repo.createUser(name: 'ani', role: UserRole.cashier, pin: '222222'),
      throwsA(isA<NamaPenggunaSudahAdaException>()),
    );

    // Setelah dinonaktifkan, nama itu boleh dipakai lagi (index parsial).
    final ani = (await repo.listUsers()).firstWhere((u) => u.name == 'Ani');
    await repo.setActive(userId: ani.id, isActive: false);
    final baru = await repo.createUser(
      name: 'ANI',
      role: UserRole.cashier,
      pin: '222222',
    );
    expect(baru.name, 'ANI');
  });

  test('Pemilik aktif terakhir tidak boleh dinonaktifkan', () async {
    final db = await openMigrated();
    addTearDown(db.close);
    final repo = UserRepositoryImpl(db);

    final owner = (await repo.firstOwner())!;
    await expectLater(
      repo.setActive(userId: owner.id, isActive: false),
      throwsA(isA<PemilikTerakhirException>()),
    );
  });

  group('rantai penuh v1 → v2 → v3 (AC-10.3)', () {
    test('database v1.0 nyata termigrasi sampai skema 3 tanpa kehilangan '
        'baris', () async {
      final v1Path = '${tempDir.path}/v1.sqlite';
      V1DatabaseFixture.create(v1Path);
      final before = V1DatabaseFixture.rowCounts(v1Path);

      final db = AppDatabase(NativeDatabase(File(v1Path)));
      await db.customSelect('SELECT 1').get();
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 3);
      // Backfill M12 tetap berjalan di rantai yang sama.
      expect(await db.select(db.customers).get(), isNotEmpty);
      // Tidak ada PIN global di fixture v1 → tidak ada akun Pemilik.
      expect(await db.select(db.users).get(), isEmpty);
      await db.close();

      final after = V1DatabaseFixture.rowCounts(v1Path);
      expect(after, before);
    });
  });

  group('gerbang backup dua arah (AC-10.2)', () {
    test('backup v2 (user_version 2) TETAP diterima & termigrasi otomatis',
        () async {
      await BackupService.validateBackupFile(dbPath);

      final db = await openMigrated();
      addTearDown(db.close);
      expect(await db.select(db.users).get(), hasLength(1));
    });

    test('backup dari aplikasi LEBIH BARU (user_version 4) ditolak', () async {
      final futurePath = '${tempDir.path}/masa_depan.db';
      File(dbPath).copySync(futurePath);
      final raw = sqlite3lib.sqlite3.open(futurePath);
      raw
        ..execute('PRAGMA user_version = ${kAppSchemaVersion + 1}')
        ..close();

      await expectLater(
        BackupService.validateBackupFile(futurePath),
        throwsA(
          isA<FileBackupTidakValidException>().having(
            (e) => e.toString(),
            'pesan',
            contains(BackupService.versiLebihBaruMessage),
          ),
        ),
      );
    });

    test('backup schema 3 membawa seluruh akun & perannya (AC-8.16)', () async {
      final db = await openMigrated();
      final repo = UserRepositoryImpl(db);
      await repo.createUser(name: 'Ani', role: UserRole.cashier, pin: '111111');
      await db.close();

      final backupPath = '${tempDir.path}/backup_v3.db';
      File(dbPath).copySync(backupPath);
      await BackupService.validateBackupFile(backupPath);

      final restored = AppDatabase(NativeDatabase(File(backupPath)));
      addTearDown(restored.close);
      final users = await UserRepositoryImpl(restored).listUsers();
      expect(users.map((u) => u.name), containsAll(['Pemilik', 'Ani']));
      expect(
        users.firstWhere((u) => u.name == 'Pemilik').role,
        UserRole.owner,
      );
      expect(users.firstWhere((u) => u.name == 'Ani').role, UserRole.cashier);
    });
  });
}
