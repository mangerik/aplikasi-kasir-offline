import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/sale.dart';
import 'status_badge.dart';

/// Satu baris daftar riwayat transaksi.
///
/// Susunan (foundation §7.3 "baris item di list"):
/// ikon metode bayar → no. struk + waktu/metode/pelanggan → nominal + status.
/// Nominal selalu jadi elemen paling menonjol di baris (prinsip 1: angka
/// lebih penting dari labelnya).
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.sale,
    required this.onTap,
    this.showDate = false,
  });

  final Sale sale;
  final VoidCallback onTap;

  /// `true` → keterangan memuat tanggal lengkap. Dipakai di daftar yang
  /// TIDAK dikelompokkan per hari (mis. hutang satu pelanggan). Di layar
  /// Riwayat tanggal sudah jadi judul kelompok, jadi cukup jamnya.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVoided = sale.status == 'voided';
    final isDebt = sale.status == 'debt_unpaid';

    final tone = isVoided ? AppTone.danger : paymentMethodTone(sale.paymentMethod);
    final icon = isVoided ? Icons.block_outlined : paymentMethodIcon(sale.paymentMethod);

    final time = showDate
        ? DateFormatter.formatDateTime(sale.createdAt)
        : DateFormatter.formatTime(sale.createdAt);
    final meta = <String>[
      time,
      paymentMethodLabel(sale.paymentMethod),
      if (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
        sale.customerName!.trim(),
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconBadge(icon: icon, tone: tone),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sale.invoiceNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              AppMoneyText(
                CurrencyFormatter.format(sale.total),
                strikethrough: isVoided,
                color: isDebt ? AppColors.accentText : null,
              ),
              if (sale.status != 'completed') ...[
                const SizedBox(height: AppSizes.spaceXs),
                StatusBadge(status: sale.status, dense: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
