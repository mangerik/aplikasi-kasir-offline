import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/settings_providers.dart';

/// Banner lembut pengingat backup (plan.md Milestone 5 poin 7,
/// architecture.md §7: "jika > 7 hari tidak backup, tampilkan banner
/// lembut di Pengaturan").
///
/// Tampil bila belum PERNAH backup ATAU backup terakhir lebih dari 7 hari
/// yang lalu; kosong (`SizedBox.shrink`) di kasus lain — TIDAK ada dialog
/// pemaksa, sesuai kata "lembut".
///
/// Visual memakai [AppBanner] nada `warning` (docs/ui-redesign-foundation.md
/// §2.5: stok menipis & peringatan lunak) plus aksi langsung ke kartu
/// Backup lewat [onBackup] — pengingat tanpa jalan keluar hanya jadi
/// teguran.
class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key, this.onBackup});

  /// Dipanggil saat pengguna menekan "Backup Sekarang" pada banner —
  /// layar Pengaturan memakainya untuk menggulir ke kartu Backup.
  final VoidCallback? onBackup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBackupAsync = ref.watch(lastBackupAtProvider);
    return lastBackupAsync.when(
      data: (lastBackup) {
        final daysSince = lastBackup == null ? null : DateTime.now().difference(lastBackup).inDays;
        final shouldRemind = lastBackup == null || (daysSince != null && daysSince > 7);
        if (!shouldRemind) return const SizedBox.shrink();

        final title = lastBackup == null ? 'Data belum pernah dicadangkan' : 'Waktunya backup lagi';
        final message = lastBackup == null
            ? 'HP hilang atau rusak berarti catatan penjualan ikut hilang. '
                  'Backup cuma butuh beberapa detik.'
            : 'Sudah $daysSince hari sejak backup terakhir '
                  '(${DateFormatter.formatDate(lastBackup)}).';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceLg),
          child: AppBanner(
            tone: AppTone.warning,
            icon: Icons.shield_moon_outlined,
            title: title,
            message: message,
            actionLabel: onBackup != null ? 'Backup Sekarang' : null,
            onAction: onBackup,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
