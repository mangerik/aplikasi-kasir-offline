import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/services/backup_service.dart';
import 'package:kasir_warung/features/settings/providers/auto_backup_providers.dart';
import 'package:kasir_warung/features/settings/providers/settings_providers.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

/// Logika pemicu backup otomatis (revisi pasca-v1.2.0): sekali per hari
/// kalender, dan selalu saat lisensi habis — tidak pernah melempar.
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() => DateFormatter.init());
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('auto_backup_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    // File sungguhan, bukan memori: createAutoBackup menyalin file .sqlite.
    db = AppDatabase(NativeDatabase(File('${tempDir.path}/kasir_warung.sqlite')));
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<int> autoFileCount() async =>
      (await BackupService.listBackups()).where((f) => f.isAuto).length;

  test('runDailyIfNeeded: hari baru → satu backup; panggilan kedua di hari '
      'yang sama → tidak ada file baru', () async {
    final service = container.read(autoBackupServiceProvider);

    await service.runDailyIfNeeded();
    expect(await autoFileCount(), 1);

    await service.runDailyIfNeeded();
    expect(await autoFileCount(), 1, reason: 'masih hari yang sama');

    final stamp = await container
        .read(settingsRepoProvider)
        .getValue(AutoBackupService.lastAutoBackupAtKey);
    expect(stamp, isNotNull);
  });

  test('runDailyIfNeeded: penanda kemarin → backup baru dibuat', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await container
        .read(settingsRepoProvider)
        .setValue(
          AutoBackupService.lastAutoBackupAtKey,
          DateFormatter.toEpochMillis(yesterday).toString(),
        );

    await container.read(autoBackupServiceProvider).runDailyIfNeeded();

    expect(await autoFileCount(), 1);
  });

  test('onLicenseExpired: SELALU membuat backup, walau harian sudah jalan '
      'hari ini', () async {
    final service = container.read(autoBackupServiceProvider);
    await service.runDailyIfNeeded();
    expect(await autoFileCount(), 1);

    await service.onLicenseExpired();

    expect(await autoFileCount(), 2);
  });

  test('kegagalan penyimpanan tidak melempar keluar (jaring pengaman '
      'senyap)', () async {
    // Arahkan path_provider ke folder yang tidak ada → createAutoBackup
    // gagal menemukan file database → harus tertelan senyap.
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      '${tempDir.path}/tidak_ada',
    );
    final service = container.read(autoBackupServiceProvider);

    await expectLater(service.runDailyIfNeeded(), completes);
    await expectLater(service.onLicenseExpired(), completes);
  });
}
