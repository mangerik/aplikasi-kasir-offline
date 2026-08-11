import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/sale.dart';
import 'status_badge.dart';

/// Satu baris daftar riwayat transaksi (plan.md Milestone 3 poin 2).
class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVoided = sale.status == 'voided';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceXs,
      ),
      title: Text(
        sale.invoiceNumber,
        style: theme.textTheme.titleMedium?.copyWith(
          decoration: isVoided ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormatter.formatDateTime(sale.createdAt)),
          Text(
            sale.customerName != null
                ? '${paymentMethodLabel(sale.paymentMethod)} · ${sale.customerName}'
                : paymentMethodLabel(sale.paymentMethod),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.format(sale.total),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          StatusBadge(status: sale.status),
        ],
      ),
    );
  }
}
