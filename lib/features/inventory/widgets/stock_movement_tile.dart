import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/stock_movement.dart';

/// Satu baris riwayat pergerakan stok (plan.md Milestone 4 poin 2): jenis,
/// qty ±, stok akhir, referensi transaksi, waktu.
///
/// Arah pergerakan dibaca dari tiga sinyal sekaligus supaya tidak perlu
/// membaca teks: **ikon panah** (turun = masuk, naik = keluar), **warna
/// nada** (masuk hijau, keluar merah, opname biru), dan **tanda ± pada
/// angka**.
class StockMovementTile extends StatelessWidget {
  const StockMovementTile({super.key, required this.movement, required this.unit});

  final StockMovement movement;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpname = movement.type == 'opname';
    final isPositive = movement.qtyChange >= 0;
    final tone = isOpname
        ? AppTone.info
        : isPositive
        ? AppTone.success
        : AppTone.danger;
    final c = tone.colorsOf(context);
    final sign = isPositive ? '+' : '';

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIconBadge(icon: _iconFor(movement.type), tone: tone),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movement.typeLabel,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Text(
                      DateFormatter.formatDateTime(movement.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$sign${_formatNum(movement.qtyChange)} $unit',
                    style: context.textStyles.numeric.copyWith(
                      fontSize: 17,
                      color: c.fg,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(
                    'sisa ${_formatNum(movement.stockAfter)} $unit',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          if (movement.referenceInvoiceNumber != null ||
              (movement.note != null && movement.note!.isNotEmpty)) ...[
            const SizedBox(height: AppSizes.spaceSm),
            if (movement.referenceInvoiceNumber != null)
              AppPill(
                label: movement.referenceInvoiceNumber!,
                icon: Icons.receipt_long_outlined,
                dense: true,
              ),
            if (movement.note != null && movement.note!.isNotEmpty) ...[
              if (movement.referenceInvoiceNumber != null)
                const SizedBox(height: AppSizes.spaceSm),
              AppCard(
                color: context.palette.surfaceAlt,
                radius: AppSizes.radiusMd,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceMs,
                  vertical: AppSizes.spaceSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: AppSizes.iconSm,
                      color: context.palette.inkSecondary,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        movement.note!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'sale' => Icons.point_of_sale_outlined,
        'void_return' => Icons.undo_rounded,
        'adjust_in' => Icons.south_rounded,
        'adjust_out' => Icons.north_rounded,
        'opname' => Icons.fact_check_outlined,
        _ => Icons.swap_vert_rounded,
      };

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
