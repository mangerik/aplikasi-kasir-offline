import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// Label & warna Bahasa Indonesia untuk `sales.status`
/// (`'completed' | 'debt_unpaid' | 'voided'`) — dipakai layar Riwayat &
/// Detail Transaksi (plan.md Milestone 3 poin 2 & 5: "Transaksi void tetap
/// tampil di riwayat dengan penanda").
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  static (String, Color) _labelAndColor(String status) {
    return switch (status) {
      'completed' => ('Lunas', AppColors.success),
      'debt_unpaid' => ('Hutang', AppColors.warning),
      'voided' => ('Batal', AppColors.danger),
      _ => (status, AppColors.textSecondary),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceSm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Label Bahasa Indonesia untuk `sales.payment_method`
/// (`'cash' | 'noncash' | 'debt'`).
String paymentMethodLabel(String method) {
  return switch (method) {
    'cash' => 'Tunai',
    'noncash' => 'Non-tunai',
    'debt' => 'Hutang',
    _ => method,
  };
}
