import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/top_product.dart';

/// Satu baris "produk terlaris" (plan.md Milestone 4 poin 6): peringkat,
/// nama, qty terjual, dan nilai penjualan.
///
/// [share] (0..1) menggambar bar proporsi terhadap produk teratas supaya
/// jarak antar peringkat langsung terlihat, bukan cuma terbaca.
class TopProductTile extends StatelessWidget {
  const TopProductTile({
    super.key,
    required this.rank,
    required this.product,
    this.share = 0,
  });

  final int rank;
  final TopProduct product;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTop = rank == 1;

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppPill(
                label: '$rank',
                tone: rank <= 3 ? AppTone.primary : AppTone.neutral,
                filled: isTop,
                dense: true,
              ),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatNum(product.qtySold)} ${product.unit} terjual',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              AppMoneyText(CurrencyFormatter.format(product.totalValue)),
            ],
          ),
          if (share > 0) ...[
            const SizedBox(height: AppSizes.spaceSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              child: LinearProgressIndicator(value: share.clamp(0, 1)),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
