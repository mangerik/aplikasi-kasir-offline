import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/settings_providers.dart';

/// Banner lembut pengingat backup (plan.md Milestone 5 poin 7,
/// architecture.md §7: "jika > 7 hari tidak backup, tampilkan banner
/// lembut di Pengaturan").
///
/// Tampil bila belum PERNAH backup ATAU backup terakhir lebih dari 7 hari
/// yang lalu; kosong (`SizedBox.shrink`) di kasus lain — TIDAK ada dialog
/// pemaksa, sesuai kata "lembut".
class BackupReminderBanner extends ConsumerWidget {
  const BackupReminderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBackupAsync = ref.watch(lastBackupAtProvider);
    return lastBackupAsync.when(
      data: (lastBackup) {
        final daysSince = lastBackup == null
            ? null
            : DateTime.now().difference(lastBackup).inDays;
        final shouldRemind = lastBackup == null || (daysSince != null && daysSince > 7);
        if (!shouldRemind) return const SizedBox.shrink();

        final message = lastBackup == null
            ? 'Anda belum pernah backup data. Backup rutin mencegah kehilangan data.'
            : 'Sudah $daysSince hari sejak backup terakhir '
                  '(${DateFormatter.formatDate(lastBackup)}). Yuk backup lagi.';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSizes.spaceMd),
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.warning),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
