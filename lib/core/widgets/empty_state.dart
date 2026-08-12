import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_palette.dart';
import '../constants/app_sizes.dart';
import 'app_pill.dart';

/// Tampilan layar/daftar kosong.
///
/// Layar kosong BUKAN kegagalan — ini kesempatan mengarahkan pengguna.
/// Karena itu widget ini mewajibkan [title] dan menganjurkan [actionLabel]:
/// jangan pernah menampilkan sekadar tulisan "Tidak ada data".
///
/// ```dart
/// EmptyState(
///   icon: Icons.inventory_2_outlined,
///   title: 'Belum ada produk',
///   message: 'Tambahkan barang jualanmu supaya bisa langsung dipakai '
///       'di layar kasir.',
///   actionLabel: 'Tambah Produk',
///   onAction: () => ...,
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.tone = AppTone.primary,
    this.compact = false,
  });

  final IconData icon;
  final String title;

  /// Kalimat pengarah — jelaskan apa yang bisa dilakukan pengguna,
  /// bukan mengulang judul.
  final String? message;

  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Nada warna ikon. [AppTone.danger] dipakai [AppErrorView].
  final AppTone tone;

  /// Versi ringkas untuk dipakai di dalam kartu/section, bukan satu layar penuh.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: compact ? AppSizes.spaceLg : AppSizes.space2xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconBadge(
                icon: icon,
                tone: tone,
                size: compact ? AppIconBadgeSize.lg : AppIconBadgeSize.xl,
              ),
              SizedBox(
                height: compact ? AppSizes.spaceMd : AppSizes.spaceMl,
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.headlineSmall,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSizes.spaceSm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.palette.inkSecondary,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? AppSizes.spaceMd : AppSizes.spaceLg),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: AppSizes.spaceSm),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
