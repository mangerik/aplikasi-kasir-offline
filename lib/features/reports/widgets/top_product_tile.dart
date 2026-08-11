import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/top_product.dart';

/// Satu baris "produk terlaris" (plan.md Milestone 4 poin 6): peringkat,
/// nama, qty terjual, dan nilai penjualan.
class TopProductTile extends StatelessWidget {
  const TopProductTile({super.key, required this.rank, required this.product});

  final int rank;
  final TopProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMd),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.primary,
        child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(product.productName, style: theme.textTheme.titleMedium),
      subtitle: Text('${_formatNum(product.qtySold)} ${product.unit} terjual'),
      trailing: Text(
        CurrencyFormatter.format(product.totalValue),
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
