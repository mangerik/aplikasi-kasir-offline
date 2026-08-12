import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/customer_repository_impl.dart';
import 'package:kasir_warung/data/services/backup_service.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3lib;

import '../../fixtures/v1_database_fixture.dart';

/// Uji migrasi `schemaVersion` 1 → 2 di atas **snapshot database v1
/// nyata** (PRD v1.1 AC-10.1) — bukan `createAll()` dari nol.
///
/// Ini uji terpenting Milestone 12. Backfill yang salah kelompok berarti
/// daftar hutang pemilik warung berubah setelah update aplikasi, dan itu
/// soal uang: satu angka meleset, kepercayaan hilang.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kasir_migrasi_v1_');
    dbPath = '${tempDir.path}/kasir_warung.sqlite';
    V1DatabaseFixture.create(dbPath);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Membuka file v1 lewat [AppDatabase] — inilah yang menjalankan
  /// `MigrationStrategy.onUpgrade`.
  Future<AppDatabase> openMigrated() async {
    final db = AppDatabase(NativeDatabase(File(dbPath)));
    // `beforeOpen`/`onUpgrade` baru berjalan saat query pertama.
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test(
    'fixture v1 memang berskema 1 & belum punya tabel pelanggan '
    '(prasyarat uji migrasi, AC-10.1)',
    () {
      final raw = sqlite3lib.sqlite3.open(dbPath, mode: sqlite3lib.OpenMode.readOnly);
      addTearDown(raw.close);
      expect(raw.select('PRAGMA user_version').first['user_version'], 1);

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tables, contains('sales'));
      expect(tables, isNot(contains('customers')));
      expect(tables, isNot(contains('customer_point_entries')));

      final salesColumns = raw
          .select('PRAGMA table_info(sales)')
          .map((row) => row['name'] as String)
          .toSet();
      expect(salesColumns, contains('customer_name'));
      expect(salesColumns, isNot(contains('customer_id')));
    },
  );

  test('membuka database v1 menaikkan user_version ke 2', () async {
    final db = await openMigrated();
    addTearDown(db.close);

    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.read<int>('user_version'), kAppSchemaVersion);
    expect(kAppSchemaVersion, 2);
  });

  test(
    'AC-7.1: "Bu Ani" / "bu ani" / "Bu Ani " menjadi SATU pelanggan '
    'dengan tiga transaksi, ejaan terbanyak yang menang',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);

      final anis = await db.customSelect(
        "SELECT id, name FROM customers WHERE LOWER(name) = 'bu ani'",
      ).get();
      expect(anis, hasLength(1), reason: 'tiga ejaan harus jadi satu pelanggan');
      // "Bu Ani" muncul 2x (termasuk yang berspasi ekor, yang di-TRIM
      // menjadi ejaan yang sama), "bu ani" 1x → ejaan terbanyak menang.
      expect(anis.single.read<String>('name'), 'Bu Ani');

      final aniId = anis.single.read<int>('id');
      final sales = await db.customSelect(
        'SELECT customer_name FROM sales WHERE customer_id = ?1 '
        'ORDER BY created_at',
        variables: [Variable.withInt(aniId)],
      ).get();
      expect(sales, hasLength(3));
      // AC-7.3: snapshot nama pada transaksi lama TIDAK ikut dirapikan.
      expect(
        sales.map((row) => row.read<String>('customer_name')).toList(),
        ['Bu Ani', 'bu ani', 'Bu Ani '],
      );
    },
  );

  test(
    'AC-7.1: daftar hutang menampilkan SATU baris dengan total gabungan',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);

      final debtors = await CustomerRepositoryImpl(db).search(onlyWithDebt: true);
      final ani = debtors.where((c) => c.name == 'Bu Ani');
      expect(ani, hasLength(1));
      expect(ani.single.totalDebt, 25000 + 15000);
      expect(ani.single.debtTransactionCount, 2);
    },
  );

  test('AC-7.2: total hutang sebelum vs sesudah migrasi IDENTIK', () async {
    final before = V1DatabaseFixture.totalUnpaidDebt(dbPath);
    expect(before, greaterThan(0));

    final db = await openMigrated();
    addTearDown(db.close);

    final row = await db.customSelect(
      "SELECT COALESCE(SUM(total), 0) AS total FROM sales "
      "WHERE status = 'debt_unpaid'",
    ).getSingle();
    expect(row.read<int>('total'), before);

    // Dan jumlah per pelanggan pun sama persis totalnya.
    final debtors = await CustomerRepositoryImpl(db).search(onlyWithDebt: true);
    expect(
      debtors.fold<int>(0, (sum, item) => sum + item.totalDebt),
      before,
    );
  });

  test('AC-10.3 & AC-10.4: tidak ada satu baris pun yang hilang', () async {
    final before = V1DatabaseFixture.rowCounts(dbPath);

    final db = await openMigrated();
    await db.close();

    final after = V1DatabaseFixture.rowCounts(dbPath);
    expect(after, before);

    // Kolom lama tetap ada (tidak ada DROP COLUMN / penulisan ulang tabel).
    final raw = sqlite3lib.sqlite3.open(dbPath, mode: sqlite3lib.OpenMode.readOnly);
    addTearDown(raw.close);
    final salesColumns = raw
        .select('PRAGMA table_info(sales)')
        .map((row) => row['name'] as String)
        .toSet();
    expect(salesColumns, contains('customer_name'));
    expect(salesColumns, contains('customer_id'));
    expect(
      raw.select("SELECT value FROM settings WHERE key = 'store_name'").first['value'],
      'Warung Lama',
    );
  });

  test(
    'nama kosong / hanya spasi / NULL TIDAK melahirkan pelanggan',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);

      final names = (await db.select(db.customers).get())
          .map((row) => row.name)
          .toSet();
      expect(names, {'Bu Ani', 'Pak Joko', 'Mbak Sri'});

      final orphan = await db.customSelect(
        "SELECT COUNT(*) AS c FROM sales "
        "WHERE customer_id IS NULL AND TRIM(IFNULL(customer_name, '')) != ''",
      ).getSingle();
      expect(orphan.read<int>('c'), 0,
          reason: 'setiap transaksi bernama harus tertaut ke pelanggan');
    },
  );

  test(
    'pelanggan hasil backfill lahir tanpa poin — tidak ada poin surut (K-7.4)',
    () async {
      final db = await openMigrated();
      addTearDown(db.close);

      final customers = await db.select(db.customers).get();
      expect(customers, isNotEmpty);
      expect(customers.every((c) => c.points == 0), isTrue);
      expect(customers.every((c) => c.isActive), isTrue);
      expect(customers.every((c) => c.mergedIntoId == null), isTrue);

      final entries = await db.select(db.customerPointEntries).get();
      expect(entries, isEmpty);
    },
  );

  test('index M12 terbentuk saat migrasi, bukan hanya saat onCreate', () async {
    final db = await openMigrated();
    await db.close();

    final raw = sqlite3lib.sqlite3.open(dbPath, mode: sqlite3lib.OpenMode.readOnly);
    addTearDown(raw.close);
    final indexes = raw
        .select("SELECT name FROM sqlite_master WHERE type = 'index'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(indexes, contains('idx_customers_name_nocase'));
    expect(indexes, contains('idx_sales_customer'));
    expect(indexes, contains('idx_point_entries_customer'));
    // Index lama tidak boleh hilang.
    expect(indexes, contains('idx_sales_created_at'));
  });

  test('migrasi bersifat idempoten: membuka ulang tidak menggandakan '
      'pelanggan', () async {
    final first = await openMigrated();
    final countAfterFirst = (await first.select(first.customers).get()).length;
    await first.close();

    final second = await openMigrated();
    addTearDown(second.close);
    final countAfterSecond = (await second.select(second.customers).get()).length;

    expect(countAfterSecond, countAfterFirst);
  });

  group('gerbang backup dua arah dengan skema baru (AC-10.2, AC-10.3)', () {
    test('backup v1 (user_version 1) TETAP diterima & termigrasi otomatis',
        () async {
      await BackupService.validateBackupFile(dbPath);

      final db = await openMigrated();
      addTearDown(db.close);
      final customers = await db.select(db.customers).get();
      expect(customers, isNotEmpty);
    });

    test('backup dari aplikasi LEBIH BARU (user_version 3) ditolak', () async {
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

    test('backup ber-user_version SAMA (2) diterima', () async {
      final db = await openMigrated();
      await db.close();

      final samePath = '${tempDir.path}/sama.db';
      File(dbPath).copySync(samePath);
      await BackupService.validateBackupFile(samePath);
    });

    test('backup v2 memuat seluruh tabel wajib yang divalidasi', () async {
      final db = await openMigrated();
      await db.close();

      final raw = sqlite3lib.sqlite3.open(dbPath, mode: sqlite3lib.OpenMode.readOnly);
      addTearDown(raw.close);
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tables, containsAll(['customers', 'customer_point_entries']));
    });
  });
}
