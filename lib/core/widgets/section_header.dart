import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

/// Judul section di dalam layar (bukan judul AppBar).
///
/// Memberi ritme vertikal yang sama di semua layar: eyebrow opsional,
/// judul tebal, keterangan opsional, dan satu aksi teks di kanan.
///
/// ```dart
/// SectionHeader(
///   title: 'Produk Terlaris',
///   subtitle: '7 hari terakhir',
///   actionLabel: 'Lihat semua',
///   onAction: () => ...,
/// )
///
/// // Versi dengan eyebrow (untuk kartu ringkasan):
/// SectionHeader(eyebrow: 'RINGKASAN', title: 'Hari Ini')
/// ```
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSizes.spaceMs),
  });

  final String title;

  /// Label kapital kecil di atas judul. Tulis dalam HURUF BESAR.
  final String? eyebrow;
  final String? subtitle;

  /// Aksi teks di kanan. Diabaikan kalau [trailing] diisi.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Widget bebas di kanan (mis. [AppPill] atau tombol ikon).
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final right =
        trailing ??
        (actionLabel != null
            ? TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spaceSm,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!),
              )
            : null);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!, style: AppTextStyles.eyebrow),
                  const SizedBox(height: AppSizes.spaceXs),
                ],
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: AppSizes.spaceSm), right],
        ],
      ),
    );
  }
}
