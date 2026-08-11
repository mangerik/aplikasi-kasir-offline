import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/services/backup_service.dart';
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
class BackupRestoreSection extends ConsumerStatefulWidget {
  const BackupRestoreSection({super.key});

  @override
  ConsumerState<BackupRestoreSection> createState() => _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends ConsumerState<BackupRestoreSection> {
  bool _busy = false;

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService.createBackup(db);

      final nowMillis = DateFormatter.toEpochMillis(DateTime.now());
      await ref.read(settingsRepoProvider).setValue('last_backup_at', nowMillis.toString());
      ref.invalidate(lastBackupAtProvider);

      await BackupService.share(path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup berhasil dibuat.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal backup: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      dialogTitle: 'Pilih file backup (.db)',
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await BackupService.validateBackupFile(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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

    setState(() => _busy = true);
    try {
      await ref.read(databaseProvider).close();
      await BackupService.restoreFrom(path);
      ref.invalidate(databaseProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal restore: $e')));
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
      title: 'Backup & Restore',
      subtitle: 'Satu file berisi seluruh data — bisa dipindahkan ke HP lain.',
      children: [
        lastBackupAsync.when(
          data: (lastBackup) => Text(
            lastBackup == null
                ? 'Belum pernah backup.'
                : 'Backup terakhir: ${DateFormatter.formatDateTime(lastBackup)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        if (_busy) const Padding(
          padding: EdgeInsets.only(bottom: AppSizes.spaceMd),
          child: LinearProgressIndicator(minHeight: 4),
        ),
        SizedBox(
          width: double.infinity,
          height: AppSizes.minTouchTarget,
          child: FilledButton.icon(
            onPressed: _busy ? null : _backup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Backup Sekarang'),
          ),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        SizedBox(
          width: double.infinity,
          height: AppSizes.minTouchTarget,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restore dari File'),
          ),
        ),
      ],
    );
  }
}
