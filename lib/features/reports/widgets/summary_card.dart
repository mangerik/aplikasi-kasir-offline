import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';

/// Kartu angka ringkasan di dashboard Laporan (plan.md Milestone 4 poin 4).
///
/// Mengikuti resep foundation §7.3 "kartu angka ringkasan":
/// [AppCard] + eyebrow (label) + nominal besar (nilai). Label sengaja
/// dibuat kecil & tenang supaya ANGKA-nya yang pertama terbaca
/// (prinsip 1 design language).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = AppTone.primary,
    this.caption,
    this.hero = false,
    this.onTap,
  });

  /// Ditulis biasa; otomatis ditampilkan sebagai eyebrow kapital.
  final String label;

  /// Nilai siap tampil (sudah diformat), mis. `Rp1.250.000` atau `12`.
  final String value;

  final IconData icon;
  final AppTone tone;

  /// Keterangan pendukung di bawah angka (mis. "dari 12 transaksi").
  final String? caption;

  /// Kartu utama layar — lebih lega, angka lebih besar, sedikit terangkat.
  final bool hero;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = tone.colors;

    return AppCard(
      onTap: onTap,
      elevated: hero,
      padding: EdgeInsets.all(hero ? AppSizes.spaceMl : AppSizes.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(icon: icon, tone: tone, size: AppIconBadgeSize.sm),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.eyebrow,
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: AppSizes.iconSm,
                  color: AppColors.inkSecondary,
                ),
            ],
          ),
          SizedBox(height: hero ? AppSizes.spaceMs : AppSizes.spaceSm),
          AppMoneyText(
            value,
            size: hero ? AppMoneySize.lg : AppMoneySize.md,
            color: c.fg,
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSizes.spaceXs),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
