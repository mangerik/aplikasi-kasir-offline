import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/services/backup_service.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3lib;

/// Fake `path_provider` — [BackupService] menyimpan/membaca file lewat
/// `getApplicationDocumentsDirectory()`, yang tidak tersedia di
/// lingkungan `flutter_test`. Arahkan ke folder temp sistem.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_service_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    dbPath = '${tempDir.path}/kasir_warung.sqlite';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupService.createBackup', () {
    test('menghasilkan file .db bernama kasir_backup_YYYYMMDD_HHmm.db yang valid', () async {
      final db = AppDatabase(NativeDatabase(File(dbPath)));
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: 'Sembako', createdAt: 1));

      final backupPath = await BackupService.createBackup(db);
      await db.close();

      expect(await File(backupPath).exists(), isTrue);
      expect(backupPath, matches(RegExp(r'kasir_backup_\d{8}_\d{4}\.db$')));

      // File backup harus lolos validasi (tabel wajib lengkap).
      await BackupService.validateBackupFile(backupPath);

      // Data yang sudah di-checkpoint WAL ikut tersalin.
      final restoredDb = AppDatabase(NativeDatabase(File(backupPath)));
      final categories = await restoredDb.select(restoredDb.categories).get();
      expect(categories, hasLength(1));
      expect(categories.single.name, 'Sembako');
      await restoredDb.close();
    });
  });

  group('BackupService.validateBackupFile', () {
    test('menolak file yang tidak ada', () async {
      expect(
        () => BackupService.validateBackupFile('${tempDir.path}/tidak_ada.db'),
        throwsA(isA<FileBackupTidakValidException>()),
      );
    });

    test('menolak file yang bukan SQLite sama sekali', () async {
      final bogusFile = File('${tempDir.path}/bukan_database.db');
      await bogusFile.writeAsString('ini bukan file database sqlite');

      expect(
        () => BackupService.validateBackupFile(bogusFile.path),
        throwsA(isA<FileBackupTidakValidException>()),
      );
    });

    test('menolak file SQLite valid tapi tabel wajib tidak lengkap', () async {
      final incompletePath = '${tempDir.path}/tidak_lengkap.db';
      final raw = sqlite3lib.sqlite3.open(incompletePath);
      raw.execute('CREATE TABLE hanya_satu_tabel (id INTEGER PRIMARY KEY)');
      raw.close();

      expect(
        () => BackupService.validateBackupFile(incompletePath),
        throwsA(isA<FileBackupTidakValidException>()),
      );
    });

    test('menerima file backup Kasir Warung yang sah', () async {
      final db = AppDatabase(NativeDatabase(File(dbPath)));
      final backupPath = await BackupService.createBackup(db);
      await db.close();

      await expectLater(BackupService.validateBackupFile(backupPath), completes);
    });
  });

  group('BackupService.restoreFrom', () {
    test('menimpa file database aktif dengan isi file backup', () async {
      // DB "lama" berisi 1 kategori.
      final oldDb = AppDatabase(NativeDatabase(File(dbPath)));
      await oldDb
          .into(oldDb.categories)
          .insert(CategoriesCompanion.insert(name: 'Kategori Lama', createdAt: 1));
      await oldDb.close();

      // File backup "dari HP lain" berisi 2 kategori berbeda — file
      // database SQLite utuh di path TERPISAH (persis seperti file .db
      // hasil `createBackup` di device lain, yang cuma salinan file
      // database apa adanya).
      final newDbPath = '${tempDir.path}/db_baru.sqlite';
      final newDb = AppDatabase(NativeDatabase(File(newDbPath)));
      await newDb
          .into(newDb.categories)
          .insert(CategoriesCompanion.insert(name: 'Kategori Baru 1', createdAt: 1));
      await newDb
          .into(newDb.categories)
          .insert(CategoriesCompanion.insert(name: 'Kategori Baru 2', createdAt: 1));
      await newDb.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await newDb.close();

      // Restore: timpa file DB aktif (dbPath) dengan file dari HP lain.
      await BackupService.restoreFrom(newDbPath);

      final reopened = AppDatabase(NativeDatabase(File(dbPath)));
      final categories = await reopened.select(reopened.categories).get();
      expect(categories.map((c) => c.name), ['Kategori Baru 1', 'Kategori Baru 2']);
      await reopened.close();
    });

    test('menghapus sidecar WAL/SHM lama sebelum menimpa', () async {
      final db = AppDatabase(NativeDatabase(File(dbPath)));
      await db
          .into(db.categories)
          .insert(CategoriesCompanion.insert(name: 'A', createdAt: 1));
      await db.close();

      // Simulasikan sisa file WAL/SHM lama di lokasi DB aktif.
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');
      await walFile.writeAsString('sisa wal lama');
      await shmFile.writeAsString('sisa shm lama');

      final otherDbPath = '${tempDir.path}/lain.sqlite';
      final otherDb = AppDatabase(NativeDatabase(File(otherDbPath)));
      await otherDb
          .into(otherDb.categories)
          .insert(CategoriesCompanion.insert(name: 'B', createdAt: 1));
      await otherDb.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await otherDb.close();

      await BackupService.restoreFrom(otherDbPath);

      expect(await walFile.exists(), isFalse);
      expect(await shmFile.exists(), isFalse);
    });
  });
}
