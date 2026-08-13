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
/// Satu file backup yang ditemukan di folder `backups/` perangkat —
/// bahan layar "Riwayat Backup di Perangkat" (revisi pasca-v1.2.0).
class BackupFileInfo {
  const BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.modifiedAt,
    required this.sizeBytes,
    required this.isAuto,
  });

  final String path;
  final String fileName;
  final DateTime modifiedAt;
  final int sizeBytes;

  /// `true` bila file lahir dari backup OTOMATIS (harian / saat lisensi
  /// habis) — hanya kelompok ini yang dirotasi; file buatan manual tidak
  /// pernah dihapus sistem.
  final bool isAuto;
}

abstract final class BackupService {
  static const String _dbFileName = 'kasir_warung.sqlite';

  /// Awalan nama file backup OTOMATIS — pembeda dari backup manual, dan
  /// kunci rotasi: hanya file berawalan ini yang boleh dihapus otomatis.
  static const String autoBackupPrefix = 'kasir_backup_otomatis_';

  /// Banyak file backup otomatis yang dipertahankan (keputusan user,
  /// revisi 2026-08-13): rotasi menghapus yang paling lama di luar 7 ini.
  static const int autoBackupKeep = 7;

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

  /// Backup OTOMATIS: sama persis dengan [createBackup], tapi bernama
  /// berawalan [autoBackupPrefix] lalu merotasi kelompoknya sendiri —
  /// hanya [autoBackupKeep] file otomatis terbaru yang dipertahankan.
  /// Backup manual TIDAK pernah ikut terhapus.
  static Future<String> createAutoBackup(AppDatabase db) async {
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

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final base =
        '$autoBackupPrefix${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    // Dua backup dalam detik yang sama (mis. pemicu harian & pemicu
    // lisensi berhimpit) tidak boleh saling timpa.
    var candidate = File('${backupDir.path}/$base.db');
    var counter = 2;
    while (await candidate.exists()) {
      candidate = File('${backupDir.path}/${base}_${counter++}.db');
    }

    final backupFile = await dbFile.copy(candidate.path);
    await _pruneAutoBackups(backupDir);
    return backupFile.path;
  }

  static Future<void> _pruneAutoBackups(Directory backupDir) async {
    final autos = <BackupFileInfo>[];
    await for (final entry in backupDir.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!name.startsWith(autoBackupPrefix) || !name.endsWith('.db')) continue;
      final stat = await entry.stat();
      autos.add(
        BackupFileInfo(
          path: entry.path,
          fileName: name,
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
          isAuto: true,
        ),
      );
    }
    if (autos.length <= autoBackupKeep) return;

    autos.sort(_newestFirst);
    for (final old in autos.skip(autoBackupKeep)) {
      try {
        await File(old.path).delete();
      } catch (_) {
        // File yang gagal dihapus (mis. sedang dibaca) dibiarkan; rotasi
        // berikutnya akan mencobanya lagi.
      }
    }
  }

  static int _newestFirst(BackupFileInfo a, BackupFileInfo b) {
    final byTime = b.modifiedAt.compareTo(a.modifiedAt);
    return byTime != 0 ? byTime : b.fileName.compareTo(a.fileName);
  }

  /// Seluruh file backup (otomatis + manual) yang ada di folder `backups/`
  /// perangkat, terbaru lebih dulu. TIDAK PERNAH melempar — kegagalan
  /// membaca folder (mis. belum pernah backup) berarti daftar kosong,
  /// karena daftar riwayat tidak boleh merobohkan layar Pengaturan.
  static Future<List<BackupFileInfo>> listBackups() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) return const [];

      final infos = <BackupFileInfo>[];
      await for (final entry in backupDir.list()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (!name.endsWith('.db')) continue;
        final stat = await entry.stat();
        infos.add(
          BackupFileInfo(
            path: entry.path,
            fileName: name,
            modifiedAt: stat.modified,
            sizeBytes: stat.size,
            isAuto: name.startsWith(autoBackupPrefix),
          ),
        );
      }
      infos.sort(_newestFirst);
      return infos;
    } catch (_) {
      return const [];
    }
  }

  /// Bagikan file backup lewat `share_plus`.
  static Future<void> share(String filePath) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], subject: 'Backup Kasir Warung'),
    );
  }

  /// Pesan penolakan backup dari aplikasi versi lebih baru (PRD v1.1
  /// AC-10.2). Dikonstankan supaya test menguji kalimat yang persis sama
  /// dengan yang dilihat pengguna.
  static const String versiLebihBaruMessage =
      'File backup berasal dari versi aplikasi yang lebih baru. '
      'Perbarui aplikasi ini terlebih dahulu.';

  /// Validasi file [path] sebagai backup database yang SAH: bisa dibuka
  /// sebagai SQLite, memuat seluruh [_requiredTables], dan `PRAGMA
  /// user_version`-nya TIDAK lebih tinggi daripada [kAppSchemaVersion].
  /// Melempar `FileBackupTidakValidException` (pesan Bahasa Indonesia siap
  /// tampil) bila tidak valid — TIDAK PERNAH mengubah database aktif.
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

      // `PRAGMA user_version` adalah tempat Drift menuliskan schemaVersion.
      // GERBANG MIGRASI (AC-10.2): file dari aplikasi yang LEBIH BARU tidak
      // boleh direstore — build ini tidak tahu bentuk skemanya dan Drift
      // hanya bisa migrasi maju, sehingga menerimanya berarti membuka
      // database yang tabelnya asing dengan data pengguna di dalamnya.
      //
      // Sebaliknya, file yang user_version-nya SAMA atau LEBIH LAMA tetap
      // diterima: migrasi majunya berjalan otomatis lewat
      // `MigrationStrategy` saat [AppDatabase] baru dibuka setelah
      // [restoreFrom] (AC-10.3).
      final versionRows = sqliteDb.select('PRAGMA user_version');
      final fileVersion =
          versionRows.isEmpty ? 0 : (versionRows.first['user_version'] as int? ?? 0);
      if (fileVersion > kAppSchemaVersion) {
        throw const FileBackupTidakValidException(versiLebihBaruMessage);
      }
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
