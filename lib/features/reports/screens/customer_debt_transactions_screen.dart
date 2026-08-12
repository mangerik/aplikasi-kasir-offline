import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/sale.dart';
import '../../transactions/screens/sale_detail_screen.dart';
import '../../transactions/widgets/history_tile.dart';
import '../providers/report_providers.dart';

/// Daftar transaksi hutang belum lunas milik SATU pelanggan (plan.md
/// Milestone 4 poin 7: "tap -> daftar transaksinya"). Tap satu transaksi
/// membuka Detail Transaksi (REUSE PENUH `SaleDetailScreen`/`HistoryTile`
/// dari Milestone 3 — tanpa duplikasi tampilan struk/pelunasan).
///
/// Desain: total hutang pelanggan ini tampil di kartu paling atas, baru
/// rincian transaksinya — supaya pemilik warung tahu angka tagihannya
/// sebelum membuka struk satu per satu.
class CustomerDebtTransactionsScreen extends ConsumerWidget {
  const CustomerDebtTransactionsScreen({super.key, required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(customerDebtTransactionsProvider(customerName));

    return Scaffold(
      appBar: AppBar(title: Text(customerName)),
      body: salesAsync.when(
        data: (sales) {
          if (sales.isEmpty) {
            // Semua transaksi pelanggan ini baru saja dilunasi (mis. lewat
            // layar Detail yang dibuka dari sini) — arahkan kembali.
            return EmptyState(
              icon: Icons.verified_outlined,
              tone: AppTone.success,
              title: 'Hutang $customerName lunas',
              message: 'Tidak ada lagi transaksi yang perlu ditagih ke pelanggan ini.',
              actionLabel: 'Kembali',
              onAction: () => Navigator.of(context).maybePop(),
            );
          }

          final total = sales.fold<int>(0, (sum, sale) => sum + sale.total);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceMd,
              AppSizes.screenPadding,
              AppSizes.spaceXl,
            ),
            itemCount: sales.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CustomerTotalCard(
                  customerName: customerName,
                  total: total,
                  transactionCount: sales.length,
                );
              }
              if (index == 1) {
                return const Padding(
                  padding: EdgeInsets.only(top: AppSizes.spaceLg),
                  child: SectionHeader(
                    title: 'Transaksi Belum Lunas',
                    subtitle: 'Buka salah satu untuk menandai lunas',
                  ),
                );
              }
              final sale = sales[index - 2];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                child: HistoryTile(
                  sale: sale,
                  showDate: true,
                  onTap: () => _openDetail(context, ref, sale),
                ),
              );
            },
          );
        },
        loading: () => const AppLoadingView(message: 'Memuat transaksi...'),
        error: (error, stack) => AppErrorView(
          title: 'Gagal memuat transaksi',
          message: AppErrorMessage.from(error),
          onRetry: () => ref.invalidate(customerDebtTransactionsProvider(customerName)),
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref, Sale sale) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale.id)));
    // Setelah kembali dari Detail (mis. pelunasan), muat ulang supaya
    // transaksi yang sudah lunas hilang dari daftar ini.
    ref.invalidate(customerDebtTransactionsProvider(customerName));
  }
}

/// Kartu total hutang satu pelanggan.
class _CustomerTotalCard extends StatelessWidget {
  const _CustomerTotalCard({
    required this.customerName,
    required this.total,
    required this.transactionCount,
  });

  final String customerName;
  final int total;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      color: context.palette.accent50,
      borderColor: context.palette.accent100,
      padding: const EdgeInsets.all(AppSizes.spaceMl),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.person_outline,
            tone: AppTone.accent,
            size: AppIconBadgeSize.lg,
          ),
          const SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SISA HUTANG', style: context.textStyles.eyebrow),
                const SizedBox(height: AppSizes.spaceXs),
                AppMoneyText(
                  CurrencyFormatter.format(total),
                  size: AppMoneySize.lg,
                  color: context.palette.accentText,
                ),
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  '$transactionCount transaksi atas nama $customerName',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
