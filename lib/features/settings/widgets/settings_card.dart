import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';

/// Kartu pembungkus seragam untuk tiap seksi layar Pengaturan (profil
/// toko, stok, export, backup/restore, PIN) — plan.md Milestone 5.
///
/// Visual mengikuti `docs/ui-redesign-foundation.md`: [AppCard] lega,
/// kepala kartu berupa [AppIconBadge] + judul + keterangan, lalu garis
/// tipis sebagai pemisah ke isi. Ikon WAJIB diisi supaya tiap seksi punya
/// jangkar visual yang gampang dikenali sambil scroll cepat.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = AppTone.primary,
    this.trailing,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Nada ikon kepala kartu — pakai untuk menandai status seksi
  /// (mis. [AppTone.success] saat kunci PIN aktif).
  final AppTone tone;

  /// Widget kanan di kepala kartu (biasanya [AppPill] status).
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceMl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIconBadge(icon: icon, tone: tone),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(color: context.palette.inkSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: AppSizes.spaceSm), trailing!],
            ],
          ),
          const Divider(height: AppSizes.spaceLg),
          ...children,
        ],
      ),
    );
  }
}
