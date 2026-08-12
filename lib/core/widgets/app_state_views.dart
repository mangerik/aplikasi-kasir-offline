import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'empty_state.dart';

/// Tampilan loading standar.
///
/// Pakai ini untuk cabang `loading` dari `AsyncValue.when` supaya semua
/// layar punya indikator yang sama (bukan spinner telanjang berukuran acak).
///
/// ```dart
/// asyncValue.when(
///   data: (d) => ...,
///   loading: () => const AppLoadingView(),
///   error: (e, _) => AppErrorView(message: errorMessage(e), onRetry: ...),
/// )
/// ```
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSizes.spaceLg : AppSizes.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSizes.spaceMs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tampilan error standar dengan tombol coba lagi.
///
/// Pesan harus dalam bahasa manusia (pakai `errorMessage()` dari
/// `core/utils/error_message.dart`), bukan `Exception: ...`.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.title = 'Gagal memuat data',
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      tone: AppTone.danger,
      title: title,
      message: message,
      compact: compact,
      actionLabel: onRetry != null ? 'Coba Lagi' : null,
      onAction: onRetry,
    );
  }
}

/// Banner informasi/peringatan selebar konten.
///
/// Untuk pesan kontekstual yang menetap (mis. "Backup terakhir 30 hari lalu",
/// "5 produk stoknya menipis"). Untuk pesan sekilas pakai SnackBar.
///
/// ```dart
/// AppBanner(
///   tone: AppTone.warning,
///   icon: Icons.warning_amber_rounded,
///   message: '5 produk stoknya menipis.',
///   actionLabel: 'Lihat',
///   onAction: () => ...,
/// )
/// ```
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.tone = AppTone.info,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final AppTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = tone.colors;

    return Container(
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconMd, color: c.fg),
            const SizedBox(width: AppSizes.spaceMs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(color: c.fg),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.spaceXs),
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: c.fg,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spaceSm,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Tutup',
              iconSize: AppSizes.iconSm,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: c.fg,
                minimumSize: const Size.square(36),
              ),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}
