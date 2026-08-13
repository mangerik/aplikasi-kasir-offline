import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/services/backup_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/auto_backup_providers.dart';
import '../providers/settings_providers.dart';
import 'settings_card.dart';

/// Seksi Backup & Restore database (plan.md Milestone 5 poin 4 & 5,
/// architecture.md §5.3).
///
/// - **Backup:** checkpoint WAL -> salin file `.sqlite` -> catat
///   `settings.last_backup_at` -> bagikan lewat `share_plus`.
/// - **Restore:** pilih file `.db` (`file_picker`) -> VALIDASI -> konfirmasi
///   GANDA (peringatan data lama tertimpa) -> tutup koneksi DB aktif ->
///   timpa file -> `ref.invalidate(databaseProvider)` supaya seluruh
///   repository/provider turunan otomatis memakai koneksi BARU tanpa
///   restart paksa aplikasi.
///
/// Visual: status backup terakhir naik jadi INFORMASI UTAMA kartu (nilai
/// lebih besar dari labelnya, prinsip §1.1 fondasi), lengkap dengan nada
/// warna — hijau bila baru saja, amber bila sudah lama/belum pernah.
class BackupRestoreSection extends ConsumerStatefulWidget {
  const BackupRestoreSection({super.key});

  @override
  ConsumerState<BackupRestoreSection> createState() => _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends ConsumerState<BackupRestoreSection> {
  bool _busy = false;
  String _busyLabel = '';

  Future<void> _backup() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Menyiapkan file backup…';
    });
    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService.createBackup(db);

      final nowMillis = DateFormatter.toEpochMillis(DateTime.now());
      await ref.read(settingsRepoProvider).setValue('last_backup_at', nowMillis.toString());
      ref
        ..invalidate(lastBackupAtProvider)
        ..invalidate(backupHistoryProvider);

      await BackupService.share(path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup berhasil dibuat.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal backup: ${AppErrorMessage.from(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// [presetPath] terisi bila restore dipicu dari panel "Riwayat di
  /// Perangkat" — file picker dilewati, sisanya (validasi + konfirmasi
  /// ganda) tetap jalur yang sama persis.
  Future<void> _restore({String? presetPath}) async {
    var path = presetPath;
    if (path == null) {
      // file_picker 12.x menghapus `FilePicker.platform`; API-nya kini static
      // langsung di kelas `FilePicker` (lihat `FilePicker.pickFiles`).
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Pilih file backup (.db)',
      );
      path = result?.files.single.path;
    }
    if (path == null || !mounted) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Memeriksa file backup…';
    });
    try {
      await BackupService.validateBackupFile(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(e))));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final confirmedOnce = await _confirm(
      title: 'Restore data?',
      message:
          'Seluruh data SAAT INI (produk, transaksi, riwayat) akan DIGANTI '
          'dengan isi file backup ini. Tindakan ini TIDAK BISA dibatalkan.',
    );
    if (confirmedOnce != true || !mounted) return;

    final confirmedTwice = await _confirm(
      title: 'Konfirmasi sekali lagi',
      message: 'Yakin ingin menimpa SEMUA data yang ada sekarang dengan file backup ini?',
      confirmLabel: 'Ya, Timpa Semua Data',
    );
    if (confirmedTwice != true || !mounted) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Memulihkan data…';
    });
    try {
      await ref.read(databaseProvider).close();
      await BackupService.restoreFrom(path);
      ref.invalidate(databaseProvider);
      // Backup membawa seluruh akun & perannya (AC-8.16). Sesi perangkat
      // TIDAK ikut terbawa — `active_user_id` hidup di `shared_preferences`
      // — jadi sesi lama dilepas dan aplikasi meminta masuk lagi dengan
      // akun-akun yang baru saja dipulihkan.
      await ref.read(sessionProvider.notifier).signOut();
      ref
        ..invalidate(multiUserSettingsProvider)
        ..invalidate(activeUsersProvider)
        ..invalidate(allUsersProvider);
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const AppIconBadge(
            icon: Icons.check_rounded,
            tone: AppTone.success,
            size: AppIconBadgeSize.lg,
          ),
          title: const Text('Restore berhasil'),
          content: const Text(
            'Data sudah dipulihkan dan aplikasi siap dipakai. Bila ada '
            'tampilan yang terasa janggal, mulai ulang aplikasi untuk '
            'memastikan semua layar memuat data terbaru.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal restore: ${AppErrorMessage.from(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Lanjutkan',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const AppIconBadge(
          icon: Icons.warning_amber_rounded,
          tone: AppTone.danger,
          size: AppIconBadgeSize.lg,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastBackupAsync = ref.watch(lastBackupAtProvider);
    return SettingsCard(
      icon: Icons.cloud_sync_outlined,
      title: 'Backup & Restore',
      subtitle: 'Satu file berisi seluruh data — bisa dipindah ke HP lain.',
      children: [
        lastBackupAsync.when(
          data: (lastBackup) => _LastBackupPanel(lastBackup: lastBackup),
          loading: () => const AppLoadingView(compact: true),
          error: (e, _) => AppErrorView(
            title: 'Status backup gagal dimuat',
            message: AppErrorMessage.from(e),
            compact: true,
            onRetry: () => ref.invalidate(lastBackupAtProvider),
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        if (_busy) ...[
          Row(
            children: [
              const SizedBox(
                width: AppSizes.iconSm,
                height: AppSizes.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(child: Text(_busyLabel, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMd),
        ],
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton.icon(
            onPressed: _busy ? null : _backup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Backup Sekarang'),
          ),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restore dari File'),
          ),
        ),
        const SizedBox(height: AppSizes.spaceMs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: AppSizes.iconSm,
              color: context.palette.inkSecondary,
            ),
            const SizedBox(width: AppSizes.spaceSm),
            Expanded(
              child: Text(
                'Restore menimpa SELURUH data yang ada sekarang — pastikan '
                'sudah backup dulu sebelum memulihkan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceLg),
        Text('RIWAYAT DI PERANGKAT', style: context.textStyles.eyebrow),
        const SizedBox(height: AppSizes.spaceSm),
        ref
            .watch(backupHistoryProvider)
            .when(
              data: (files) => files.isEmpty
                  ? Text(
                      'Belum ada file backup di perangkat ini.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : Column(
                      children: [
                        for (final file in files) ...[
                          _BackupHistoryTile(
                            info: file,
                            enabled: !_busy,
                            onRestore: () => _restore(presetPath: file.path),
                          ),
                          const SizedBox(height: AppSizes.spaceSm),
                        ],
                      ],
                    ),
              loading: () => const AppLoadingView(compact: true),
              // Riwayat hanyalah kenyamanan — kegagalan membacanya tidak
              // perlu kartu error, cukup tampil kosong.
              error: (_, _) => Text(
                'Belum ada file backup di perangkat ini.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        const SizedBox(height: AppSizes.spaceMs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: AppSizes.iconSm,
              color: context.palette.inkSecondary,
            ),
            const SizedBox(width: AppSizes.spaceSm),
            Expanded(
              child: Text(
                'Backup otomatis dibuat sekali sehari dan tepat saat masa '
                'berlaku habis; ${BackupService.autoBackupKeep} terbaru '
                'disimpan. File di daftar ini ikut hilang bila aplikasi '
                'dihapus — untuk salinan yang benar-benar aman, gunakan '
                '"Backup Sekarang" lalu simpan filenya di luar HP ini.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Satu baris riwayat backup: tanggal (informasi utama), ukuran + asal
/// (Otomatis/Manual), dan aksi pulihkan.
class _BackupHistoryTile extends StatelessWidget {
  const _BackupHistoryTile({
    required this.info,
    required this.enabled,
    required this.onRestore,
  });

  final BackupFileInfo info;
  final bool enabled;
  final VoidCallback onRestore;

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: context.palette.surfaceAlt,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          AppIconBadge(
            icon: info.isAuto
                ? Icons.schedule_outlined
                : Icons.save_alt_outlined,
            tone: AppTone.primary,
            size: AppIconBadgeSize.sm,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormatter.formatDateTime(info.modifiedAt),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSizes.spaceXs),
                Row(
                  children: [
                    AppPill(
                      label: info.isAuto ? 'Otomatis' : 'Manual',
                      tone: info.isAuto ? AppTone.neutral : AppTone.primary,
                      dense: true,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Text(
                      _formatSize(info.sizeBytes),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          IconButton(
            onPressed: enabled ? onRestore : null,
            tooltip: 'Pulihkan dari backup ini',
            icon: const Icon(Icons.restore_outlined),
          ),
        ],
      ),
    );
  }
}

/// Sub-panel status: kapan terakhir kali data diamankan.
class _LastBackupPanel extends StatelessWidget {
  const _LastBackupPanel({required this.lastBackup});

  final DateTime? lastBackup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = lastBackup == null ? null : DateTime.now().difference(lastBackup!).inDays;
    final stale = lastBackup == null || (days != null && days > 7);
    final tone = stale ? AppTone.warning : AppTone.success;

    return AppCard(
      color: context.palette.surfaceAlt,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          AppIconBadge(
            icon: stale ? Icons.history_toggle_off_outlined : Icons.verified_outlined,
            tone: tone,
            size: AppIconBadgeSize.sm,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('BACKUP TERAKHIR', style: context.textStyles.eyebrow),
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  lastBackup == null ? 'Belum pernah' : DateFormatter.formatDateTime(lastBackup!),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          if (days != null) ...[
            const SizedBox(width: AppSizes.spaceSm),
            AppPill(label: days == 0 ? 'Hari ini' : '$days hari lalu', tone: tone, dense: true),
          ],
        ],
      ),
    );
  }
}
