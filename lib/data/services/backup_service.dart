import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3lib;

import '../../domain/repositories/repository_exceptions.dart';
import '../db/app_database.dart';

/// Backup & restore seluruh database (plan.md Milestone 5 poin 4 & 5,
/// architecture.md §5.3).
///
/// - **Backup:** checkpoint WAL (`PRAGMA wal_checkpoint(TRUNCATE)`) supaya
///   seluruh data ter-flush ke file utama (bukan tertinggal di
///   `-wal`/`-shm`), lalu salin file `.sqlite` menjadi
///   `kasir_backup_YYYYMMDD_HHmm.db`.
/// - **Restore:** [validateBackupFile] WAJIB dipanggil & lolos, koneksi DB
///   aktif WAJIB ditutup ([AppDatabase.close]) oleh pemanggil SEBELUM
///   [restoreFrom] dipanggil (service ini tidak menutup koneksi sendiri —
///   itu tanggung jawab provider Riverpod yang memegang instance
///   `AppDatabase`, lihat `settings/providers/backup_providers.dart`).
abstract final class BackupService {
  static const String _dbFileName = 'kasir_warung.sqlite';

  /// Tabel wajib ada di file backup yang valid — sesuai daftar tabel Drift
  /// di `app_database.dart` (architecture.md §4).
  static const List<String> _requiredTables = [
    'categories',
    'products',
    'sales',
    'sale_items',
    'stock_movements',
    'held_carts',
    'settings',
  ];

  static Future<String> _dbFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_dbFileName';
  }

  /// Membuat satu file backup baru dari database aktif [db], mengembalikan
  /// path file backup yang dihasilkan.
  static Future<String> createBackup(AppDatabase db) async {
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    final dbFile = File(await _dbFilePath());
    if (!await dbFile.exists()) {
      throw const FileBackupTidakValidException('Database aplikasi tidak ditemukan.');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${docsDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final backupFile = await dbFile.copy('${backupDir.path}/${_backupFileName()}');
    return backupFile.path;
  }

  static String _backupFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'kasir_backup_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.db';
  }

  /// Bagikan file backup lewat `share_plus`.
  static Future<void> share(String filePath) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], subject: 'Backup Kasir Warung'),
    );
  }

  /// Validasi file [path] sebagai backup database yang SAH: bisa dibuka
  /// sebagai SQLite dan memuat seluruh [_requiredTables]. Melempar
  /// `FileBackupTidakValidException` (pesan Bahasa Indonesia siap tampil)
  /// bila tidak valid — TIDAK PERNAH mengubah database aktif.
  static Future<void> validateBackupFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileBackupTidakValidException('File tidak ditemukan.');
    }
    if (await file.length() == 0) {
      throw const FileBackupTidakValidException('File kosong.');
    }

    late sqlite3lib.Database sqliteDb;
    try {
      sqliteDb = sqlite3lib.sqlite3.open(path, mode: sqlite3lib.OpenMode.readOnly);
    } catch (_) {
      throw const FileBackupTidakValidException('Bukan file database SQLite yang valid.');
    }

    try {
      final tableRows = sqliteDb.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = tableRows.map((row) => row['name'] as String).toSet();
      final missing = _requiredTables.where((t) => !tableNames.contains(t)).toList();
      if (missing.isNotEmpty) {
        throw FileBackupTidakValidException(
          'Bukan backup Kasir Warung — tabel wajib tidak lengkap (${missing.join(', ')}).',
        );
      }

      // `PRAGMA user_version` dipakai Drift untuk menandai schemaVersion —
      // sekadar dibaca di sini untuk memastikan file bisa di-query PRAGMA
      // tanpa error (bukti file tidak korup), migrasi sungguhan berjalan
      // otomatis lewat `MigrationStrategy` saat [AppDatabase] baru dibuka
      // setelah [restoreFrom].
      sqliteDb.select('PRAGMA user_version');
    } on FileBackupTidakValidException {
      rethrow;
    } catch (e) {
      throw FileBackupTidakValidException('File database rusak atau tidak terbaca ($e).');
    } finally {
      sqliteDb.close();
    }
  }

  /// Menimpa file database aktif dengan file backup [backupFilePath].
  ///
  /// WAJIB dipanggil setelah [validateBackupFile] lolos DAN setelah
  /// koneksi [AppDatabase] lama ditutup oleh pemanggil (lihat catatan
  /// kelas). File sidecar WAL/SHM lama dihapus dulu supaya tidak
  /// "menempel" ke file database baru.
  static Future<void> restoreFrom(String backupFilePath) async {
    final dbPath = await _dbFilePath();

    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    await File(backupFilePath).copy(dbPath);
  }
}
