import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/services/backup_service.dart';
import '../../../domain/repositories/settings_repository.dart';
import 'settings_providers.dart';

/// Backup otomatis lokal (revisi pasca-v1.2.0, keputusan user 2026-08-13):
/// aplikasi memotret datanya sendiri ke folder `backups/` — sekali per
/// hari saat dibuka, dan SELALU tepat saat masa berlaku lisensi habis —
/// lalu merotasi hingga [BackupService.autoBackupKeep] file. Kalau ada
/// data terhapus/rusak, selalu ada potret yang tinggal direstore dari
/// "Riwayat Backup di Perangkat" di Pengaturan.
///
/// Ini PELENGKAP tombol "Cadangkan Data", bukan penggantinya: file
/// otomatis hidup di penyimpanan internal aplikasi yang ikut lenyap bila
/// aplikasi di-uninstall (dan sengaja tidak ikut Auto Backup Google —
/// lihat `AndroidManifest.xml`). Karena itu kunci `last_backup_at` milik
/// pengingat backup TIDAK disentuh — pengingat tetap menagih salinan yang
/// dibagikan KELUAR perangkat.
final Provider<AutoBackupService> autoBackupServiceProvider =
    Provider<AutoBackupService>(AutoBackupService.new);

/// Daftar file backup (otomatis + manual) di perangkat, terbaru dulu —
/// bahan panel "Riwayat Backup di Perangkat".
final FutureProvider<List<BackupFileInfo>> backupHistoryProvider =
    FutureProvider<List<BackupFileInfo>>((ref) => BackupService.listBackups());

class AutoBackupService {
  AutoBackupService(this._ref);

  final Ref _ref;

  /// Kunci `settings` penanda hari terakhir backup otomatis berjalan —
  /// SENGAJA berbeda dari `last_backup_at` (lihat catatan provider).
  static const String lastAutoBackupAtKey = 'last_auto_backup_at';

  bool _running = false;

  /// Dipanggil sekali setelah frame pertama (lihat `app.dart`): membuat
  /// backup otomatis bila hari kalender terakhirnya bukan hari ini.
  ///
  /// TIDAK PERNAH melempar — backup otomatis adalah jaring pengaman,
  /// kegagalannya (mis. penyimpanan penuh) tidak boleh mengganggu kasir.
  Future<void> runDailyIfNeeded() async {
    if (_running) return;
    _running = true;
    try {
      final repo = _ref.read(settingsRepoProvider);
      final raw = await repo.getValue(lastAutoBackupAtKey);
      final lastMillis = raw == null ? null : int.tryParse(raw);
      final last = lastMillis == null
          ? null
          : DateFormatter.fromEpochMillis(lastMillis);
      final now = DateTime.now();
      final sameDay =
          last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day;
      if (sameDay) return;
      await _create(repo);
    } catch (_) {
      // Sengaja senyap (lihat dok method).
    } finally {
      _running = false;
    }
  }

  /// Dipanggil saat keadaan lisensi BERPINDAH dari masih-berlaku menjadi
  /// kedaluwarsa (lihat listener di `app.dart`): data terpotret persis
  /// sebelum layar terkunci, berapa kali pun itu terjadi.
  Future<void> onLicenseExpired() async {
    try {
      await _create(_ref.read(settingsRepoProvider));
    } catch (_) {
      // Sengaja senyap (lihat dok [runDailyIfNeeded]).
    }
  }

  Future<void> _create(SettingsRepository repo) async {
    await BackupService.createAutoBackup(_ref.read(databaseProvider));
    await repo.setValue(
      lastAutoBackupAtKey,
      DateFormatter.toEpochMillis(DateTime.now()).toString(),
    );
    _ref.invalidate(backupHistoryProvider);
  }
}
