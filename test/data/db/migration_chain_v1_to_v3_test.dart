import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/error_message.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/services/backup_service.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3lib;

import '../../fixtures/v1_database_fixture.dart';
import '../../fixtures/v2_database_fixture.dart';

/// Uji **rantai migrasi penuh 1 → 2 → 3 dalam satu jalur** dari snapshot
/// database v1.0 nyata (checklist M15, PRD v1.1 AC-10.1 s.d. AC-10.5).
///
/// M12 menguji langkah 1 → 2, M13 menguji langkah 2 → 3. Yang TIDAK diuji
/// keduanya adalah jalur yang justru paling banyak dilalui pengguna nyata:
/// warung yang melewatkan v1.1 dan langsung memasang v1.2 di atas database
/// v1.0-nya, sehingga **dua** migrasi berjalan berurutan dalam satu kali
/// buka aplikasi. Di situlah dua migrasi yang masing-masing benar masih bisa
/// salah bersama — mis. backfill M12 yang belum ter-commit saat M13 mulai,
/// atau kegagalan di langkah kedua yang meninggalkan database sebagai "v2
/// setengah jadi" yang tidak dikenali versi mana pun.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kasir_rantai_migrasi_');
    dbPath = '${tempDir.path}/kasir_warung.sqlite';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Membuka file lewat [AppDatabase] — inilah yang menjalankan
  /// `MigrationStrategy`. Query pertama memaksa `onUpgrade` benar-benar
  /// berjalan (Drift menundanya sampai ada pemakaian).
  Future<AppDatabase> open(String path) async {
    final db = AppDatabase(NativeDatabase(File(path)));
    await db.customSelect('SELECT 1').get();
    return db;
  }

  /// Snapshot bentuk tabel (`nama kolom` → `tipe`) langsung dari SQLite.
  Map<String, Map<String, String>> tableShapes(String path, List<String> tables) {
    final raw = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    try {
      return {
        for (final table in tables)
          table: {
            for (final row in raw.select('PRAGMA table_info($table)'))
              row['name'] as String: row['type'] as String,
          },
      };
    } finally {
      raw.close();
    }
  }

  Set<String> indexNames(String path) {
    final raw = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    try {
      return raw
          .select("SELECT name FROM sqlite_master WHERE type = 'index'")
          .map((row) => row['name'] as String)
          .toSet();
    } finally {
      raw.close();
    }
  }

  int userVersion(String path) {
    final raw = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    try {
      return raw.select('PRAGMA user_version').first['user_version'] as int;
    } finally {
      raw.close();
    }
  }

  List<String?> customerNames(String path) {
    final raw = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    try {
      return raw
          .select('SELECT customer_name FROM sales ORDER BY id')
          .map((row) => row['customer_name'] as String?)
          .toList();
    } finally {
      raw.close();
    }
  }

  Map<String, String> settingsMap(String path) {
    final raw = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    try {
      return {
        for (final row in raw.select('SELECT key, value FROM settings'))
          row['key'] as String: row['value'] as String,
      };
    } finally {
      raw.close();
    }
  }

  group('rantai 1 → 2 → 3 dalam satu kali buka (AC-10.1, AC-10.3)', () {
    test('database v1.0 nyata berakhir di skema 3 dengan seluruh baris utuh', () async {
      V1DatabaseFixture.create(dbPath);
      expect(userVersion(dbPath), 1, reason: 'prasyarat: fixture memang v1.0');
      final barisSebelum = V1DatabaseFixture.rowCounts(dbPath);
      final hutangSebelum = V1DatabaseFixture.totalUnpaidDebt(dbPath);
      final namaSebelum = customerNames(dbPath);

      final db = await open(dbPath);
      await db.close();

      expect(userVersion(dbPath), kAppSchemaVersion);
      expect(kAppSchemaVersion, 3, reason: 'rilis v1.2.0 mengunci skema di 3');
      expect(
        V1DatabaseFixture.rowCounts(dbPath),
        barisSebelum,
        reason: 'tidak boleh ada satu baris pun yang hilang (AC-10.3)',
      );
      expect(
        V1DatabaseFixture.totalUnpaidDebt(dbPath),
        hutangSebelum,
        reason: 'selisih total hutang sebelum vs sesudah migrasi wajib Rp0 (PRD §11.2)',
      );
      expect(
        customerNames(dbPath),
        namaSebelum,
        reason: '`sales.customer_name` adalah snapshot historis (K-7.1, AC-7.3)',
      );
    });

    test('AC-10.4: tidak ada kolom v1.0 yang hilang atau berubah tipe', () async {
      V1DatabaseFixture.create(dbPath);
      const tabelV1 = [
        'categories',
        'products',
        'sales',
        'sale_items',
        'stock_movements',
        'held_carts',
        'settings',
      ];
      final bentukSebelum = tableShapes(dbPath, tabelV1);

      final db = await open(dbPath);
      await db.close();

      final bentukSesudah = tableShapes(dbPath, tabelV1);
      for (final table in tabelV1) {
        bentukSebelum[table]!.forEach((kolom, tipe) {
          expect(
            bentukSesudah[table],
            containsPair(kolom, tipe),
            reason: 'kolom v1.0 `$table.$kolom` hilang/berubah tipe — '
                'migrasi tidak boleh destruktif (AC-10.4)',
          );
        });
      }

      // Yang BOLEH bertambah: kolom baru M12 & M13 — dan hanya itu.
      expect(bentukSesudah['sales']!.keys, containsAll(['customer_id', 'user_id', 'user_name', 'voided_by_user_id']));
      expect(bentukSesudah['stock_movements']!.keys, contains('user_id'));
    });

    test('backfill M12 & M13 keduanya berjalan di rantai yang sama', () async {
      V1DatabaseFixture.create(dbPath, withGlobalPin: true);

      final db = await open(dbPath);
      addTearDown(db.close);

      // M12: satu pelanggan per kelompok nama, `customer_id` terisi.
      final pelanggan = await db.select(db.customers).get();
      expect(pelanggan.map((c) => c.name), containsAll(['Bu Ani', 'Pak Joko']));
      final terhubung = await db
          .customSelect('SELECT COUNT(*) AS c FROM sales WHERE customer_id IS NOT NULL')
          .getSingle();
      expect(terhubung.read<int>('c'), greaterThan(0));

      // M13: PIN global v1.0 menjadi akun Pemilik — pemilik warung yang
      // melompat dari v1.0 ke v1.2 tetap masuk dengan PIN yang SAMA (AC-8.2).
      final akun = await db.select(db.users).get();
      expect(akun, hasLength(1));
      expect(akun.single.name, 'Pemilik');
      expect(akun.single.role, 'owner');
      expect(akun.single.pinHash, V1DatabaseFixture.globalPinHash);
      expect(akun.single.pinSalt, V1DatabaseFixture.globalPinSalt);
    });

    test('seluruh index M12, M13 & M14 lahir dari rantai, bukan hanya onCreate', () async {
      V1DatabaseFixture.create(dbPath);

      final db = await open(dbPath);
      await db.close();

      expect(
        indexNames(dbPath),
        containsAll([
          // v1.0 — wajib tetap ada.
          'idx_products_name',
          'idx_products_barcode',
          'idx_products_barcode_unique',
          'idx_sales_created_at',
          'idx_sales_status',
          'idx_sale_items_sale_id',
          'idx_stock_movements_product_created',
          // M12.
          'idx_customers_name_nocase',
          'idx_sales_customer',
          'idx_point_entries_customer',
          // M13.
          'idx_users_name_nocase',
          'idx_sales_user',
          // M14 — lahir di `beforeOpen`, bukan lewat kenaikan schemaVersion.
          'idx_sales_status_created',
        ]),
      );
    });

    test('fitur baru tetap MATI setelah migrasi (AC-7.6, AC-8.1)', () async {
      V1DatabaseFixture.create(dbPath, withGlobalPin: true);

      final db = await open(dbPath);
      await db.close();

      final settings = settingsMap(dbPath);
      expect(
        settings['points_enabled'],
        isNull,
        reason: 'migrasi tidak boleh menyalakan program poin sendiri (K-7.4)',
      );
      expect(
        settings['multi_user_enabled'],
        isNull,
        reason: 'migrasi menyiapkan akun, pemilik yang menyalakan (K-8.8)',
      );
      // Key PIN lama dibiarkan utuh supaya gerbang PIN v1.0 tetap berlaku.
      expect(settings['pin_hash'], V1DatabaseFixture.globalPinHash);
      expect(settings['pin_salt'], V1DatabaseFixture.globalPinSalt);
      expect(settings['store_name'], 'Warung Lama');
    });

    test('membuka ulang database yang sudah v3 tidak menjalankan migrasi lagi', () async {
      V1DatabaseFixture.create(dbPath, withGlobalPin: true);

      final pertama = await open(dbPath);
      final pelangganPertama = (await pertama.select(pertama.customers).get()).length;
      await pertama.close();

      final kedua = await open(dbPath);
      addTearDown(kedua.close);
      expect((await kedua.select(kedua.customers).get()).length, pelangganPertama);
      expect((await kedua.select(kedua.users).get()), hasLength(1));
    });
  });

  group('AC-10.5: kegagalan di tengah rantai mengembalikan database ke v1.0 utuh', () {
    /// Menyuntikkan kegagalan dengan cara yang sedekat mungkin dengan yang
    /// bisa terjadi di lapangan: file v1.0 yang sudah "kotor" — memuat tabel
    /// `customers` sisa percobaan lain dengan bentuk yang berbeda. Drift
    /// memakai `CREATE TABLE IF NOT EXISTS`, jadi tabelnya lolos dibuat, dan
    /// migrasi baru pecah beberapa langkah kemudian saat index dibuat di
    /// atas kolom yang tidak ada.
    void kotoriDatabase(String path) {
      final raw = sqlite3lib.sqlite3.open(path);
      raw
        ..execute('CREATE TABLE customers (id INTEGER PRIMARY KEY)')
        ..close();
    }

    test('database kembali ke keadaan SEMULA — bukan v2 setengah jadi', () async {
      V1DatabaseFixture.create(dbPath);
      kotoriDatabase(dbPath);
      final barisSebelum = V1DatabaseFixture.rowCounts(dbPath);
      final hutangSebelum = V1DatabaseFixture.totalUnpaidDebt(dbPath);

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<MigrasiDatabaseGagalException>()),
      );
      await db.close();

      expect(userVersion(dbPath), 1, reason: 'versi skema tidak boleh ikut naik');
      expect(V1DatabaseFixture.rowCounts(dbPath), barisSebelum);
      expect(V1DatabaseFixture.totalUnpaidDebt(dbPath), hutangSebelum);

      // Langkah 1 → 2 yang SUDAH berjalan sebelum kegagalan wajib ikut
      // tergulung: kolom `sales.customer_id` tidak boleh tertinggal.
      final bentukSales = tableShapes(dbPath, ['sales'])['sales']!;
      expect(bentukSales.keys, isNot(contains('customer_id')));
      expect(bentukSales.keys, isNot(contains('user_id')));
      expect(
        indexNames(dbPath),
        isNot(contains('idx_sales_customer')),
      );

      // Tabel `users` milik langkah 2 → 3 tidak pernah lahir.
      final raw = sqlite3lib.sqlite3.open(dbPath, mode: sqlite3lib.OpenMode.readOnly);
      addTearDown(raw.close);
      final tabel = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tabel, isNot(contains('users')));
      expect(tabel, isNot(contains('customer_point_entries')));
    });

    test('pesannya Bahasa Indonesia siap tampil, bukan SqliteException mentah', () async {
      V1DatabaseFixture.create(dbPath);
      kotoriDatabase(dbPath);

      final db = AppDatabase(NativeDatabase(File(dbPath)));
      Object? tertangkap;
      try {
        await db.customSelect('SELECT 1').get();
      } catch (e) {
        tertangkap = e;
      }
      await db.close();

      expect(tertangkap, isA<MigrasiDatabaseGagalException>());
      final pesan = AppErrorMessage.from(tertangkap!);
      expect(pesan, isNot(AppErrorMessage.generic));
      expect(pesan, contains('Data Anda TIDAK berubah'));
      expect(pesan, contains('backup'));
      expect(pesan, isNot(contains('SqliteException')));
      expect(pesan, isNot(contains('no such column')));
      // Penyebab teknisnya tetap tersimpan untuk laporan bug, tapi tidak
      // ikut naik ke layar.
      expect((tertangkap as MigrasiDatabaseGagalException).penyebab, isNotNull);
      expect(tertangkap.dari, 1);
      expect(tertangkap.ke, kAppSchemaVersion);
    });
  });

  group('restore backup lintas versi pada rilis v1.2.0 (AC-10.2, AC-10.3)', () {
    /// Meniru `BackupService.restoreFrom` tanpa `path_provider`: file backup
    /// menimpa file database aktif, lalu aplikasi membukanya kembali.
    Future<AppDatabase> restoreLalyBuka(String backupPath) async {
      await BackupService.validateBackupFile(backupPath);
      File(backupPath).copySync(dbPath);
      return open(dbPath);
    }

    test('backup v1.0 (user_version 1) diterima & termigrasi sampai skema 3', () async {
      final backupPath = '${tempDir.path}/backup_v1.db';
      V1DatabaseFixture.create(backupPath, withGlobalPin: true);
      final barisSebelum = V1DatabaseFixture.rowCounts(backupPath);

      final db = await restoreLalyBuka(backupPath);
      await db.close();

      expect(userVersion(dbPath), kAppSchemaVersion);
      expect(V1DatabaseFixture.rowCounts(dbPath), barisSebelum);
      // Catatan M14: index grafik wajib ada juga pada database hasil restore
      // backup v1.0 — ia lahir di `beforeOpen`, bukan lewat `onUpgrade`.
      expect(indexNames(dbPath), contains('idx_sales_status_created'));
    });

    test('backup v1.1 (user_version 2) diterima & termigrasi ke skema 3', () async {
      final backupPath = '${tempDir.path}/backup_v2.db';
      V2DatabaseFixture.create(backupPath);
      final barisSebelum = V2DatabaseFixture.rowCounts(backupPath);

      final db = await restoreLalyBuka(backupPath);
      addTearDown(db.close);

      expect(userVersion(dbPath), kAppSchemaVersion);
      expect(V2DatabaseFixture.rowCounts(dbPath), barisSebelum);
      expect(await db.select(db.users).get(), hasLength(1));
      expect(indexNames(dbPath), contains('idx_sales_status_created'));
    });

    test('backup v1.2 (user_version 3, versi sendiri) diterima apa adanya', () async {
      V1DatabaseFixture.create(dbPath);
      final db = await open(dbPath);
      await db.close();

      final backupPath = '${tempDir.path}/backup_v3.db';
      File(dbPath).copySync(backupPath);

      await BackupService.validateBackupFile(backupPath);
      expect(userVersion(backupPath), kAppSchemaVersion);
    });

    test('backup dari versi LEBIH BARU tetap ditolak pada versi final (AC-10.2)', () async {
      V1DatabaseFixture.create(dbPath);
      final db = await open(dbPath);
      await db.close();

      final masaDepanPath = '${tempDir.path}/backup_v4.db';
      File(dbPath).copySync(masaDepanPath);
      final raw = sqlite3lib.sqlite3.open(masaDepanPath);
      raw
        ..execute('PRAGMA user_version = ${kAppSchemaVersion + 1}')
        ..close();

      await expectLater(
        BackupService.validateBackupFile(masaDepanPath),
        throwsA(
          isA<FileBackupTidakValidException>().having(
            (e) => AppErrorMessage.from(e),
            'pesan siap tampil',
            contains(BackupService.versiLebihBaruMessage),
          ),
        ),
      );
    });

    test('gerbang AC-10.2 memakai angka yang sama dengan yang ditulis Drift', () async {
      V1DatabaseFixture.create(dbPath);
      final db = await open(dbPath);
      expect(db.schemaVersion, kAppSchemaVersion);
      await db.close();

      // Yang benar-benar tertulis di file = yang dibandingkan guard backup.
      expect(userVersion(dbPath), kAppSchemaVersion);
    });
  });
}
