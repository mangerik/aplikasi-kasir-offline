import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';

/// Satu angka ringkasan impor: **nilainya besar, labelnya kecil di bawah**
/// (fondasi §1: yang dibaca kasir adalah angkanya, bukan namanya).
class ImportStat {
  const ImportStat({
    required this.value,
    required this.label,
    this.tone = AppTone.neutral,
  });

  final int value;
  final String label;
  final AppTone tone;
}

/// Kartu ringkasan pratinjau/hasil impor: "120 baris dibaca · 84 baru ·
/// 30 diperbarui · 6 bermasalah" (PRD v1.1 §4.4).
class ImportSummaryCard extends StatelessWidget {
  const ImportSummaryCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.stats,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<ImportStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSizes.spaceMl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: context.textStyles.eyebrow),
          const SizedBox(height: AppSizes.spaceXs),
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSizes.spaceXs),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.inkSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spaceMd),
          Wrap(
            spacing: AppSizes.spaceLg,
            runSpacing: AppSizes.spaceMd,
            children: [for (final stat in stats) _StatBlock(stat: stat)],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.stat});

  final ImportStat stat;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = stat.tone == AppTone.neutral
        ? palette.ink
        : stat.tone.colorsOf(context).fg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${stat.value}',
          style: AppTextStyles.moneyLarge.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkSecondary),
        ),
      ],
    );
  }
}
