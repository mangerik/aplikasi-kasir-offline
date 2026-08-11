import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/stock_movement.dart';

/// Satu baris riwayat pergerakan stok (plan.md Milestone 4 poin 2): jenis,
/// qty ±, stok akhir, referensi transaksi, waktu.
class StockMovementTile extends StatelessWidget {
  const StockMovementTile({super.key, required this.movement, required this.unit});

  final StockMovement movement;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = movement.qtyChange >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final sign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMd, vertical: AppSizes.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(_iconFor(movement.type), color: color, size: 20),
          ),
          const SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(movement.typeLabel, style: theme.textTheme.titleMedium),
                    ),
                    Text(
                      '$sign${_formatNum(movement.qtyChange)} $unit',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.formatDateTime(movement.createdAt),
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  'Stok akhir: ${_formatNum(movement.stockAfter)} $unit',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                if (movement.referenceInvoiceNumber != null)
                  Text(
                    'Ref: ${movement.referenceInvoiceNumber}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                if (movement.note != null && movement.note!.isNotEmpty)
                  Text(
                    'Catatan: ${movement.note}',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'sale' => Icons.point_of_sale_outlined,
        'void_return' => Icons.undo,
        'adjust_in' => Icons.add_box_outlined,
        'adjust_out' => Icons.indeterminate_check_box_outlined,
        'opname' => Icons.fact_check_outlined,
        _ => Icons.swap_vert,
      };

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
