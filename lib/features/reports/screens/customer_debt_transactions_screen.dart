import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../transactions/screens/sale_detail_screen.dart';
import '../../transactions/widgets/history_tile.dart';
import '../providers/report_providers.dart';

/// Daftar transaksi hutang belum lunas milik SATU pelanggan (plan.md
/// Milestone 4 poin 7: "tap -> daftar transaksinya"). Tap satu transaksi
/// membuka Detail Transaksi (REUSE PENUH `SaleDetailScreen`/`HistoryTile`
/// dari Milestone 3 — tanpa duplikasi tampilan struk/pelunasan).
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
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
            itemCount: sales.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return HistoryTile(
                sale: sale,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale.id)),
                  );
                  // Setelah kembali dari Detail (mis. pelunasan), muat ulang
                  // supaya transaksi yang sudah lunas hilang dari daftar ini.
                  ref.invalidate(customerDebtTransactionsProvider(customerName));
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Text('Gagal memuat transaksi: $error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
            const SizedBox(height: AppSizes.spaceMd),
            Text('Semua transaksi sudah lunas', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
