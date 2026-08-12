import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/customer_debt.dart';
import '../providers/report_providers.dart';
import 'customer_debt_transactions_screen.dart';

/// Layar daftar hutang belum lunas, DIKELOMPOKKAN PER PELANGGAN (plan.md
/// Milestone 4 poin 7) — total per pelanggan lewat agregasi SQL
/// `ReportRepository.getUnpaidDebts`. Tap satu pelanggan -> daftar
/// transaksi hutangnya.
///
/// Desain: total hutang berjalan tampil paling besar di atas (itu angka
/// yang dicari pemilik warung), lalu daftar pelanggan urut dari yang
/// terbesar dengan bar proporsi supaya prioritas penagihan langsung
/// kelihatan.
class DebtListScreen extends ConsumerWidget {
  const DebtListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(unpaidDebtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hutang Belum Lunas')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(unpaidDebtsProvider);
          await ref.read(unpaidDebtsProvider.future);
        },
        child: debtsAsync.when(
          data: (debts) {
            if (debts.isEmpty) {
              return _scroll(
                EmptyState(
                  icon: Icons.verified_outlined,
                  tone: AppTone.success,
                  title: 'Semua hutang sudah lunas',
                  message: 'Tidak ada bon yang perlu ditagih. Catatan warungmu bersih.',
                  actionLabel: 'Kembali',
                  onAction: () => Navigator.of(context).maybePop(),
                ),
              );
            }

            final total = debts.fold<int>(0, (sum, debt) => sum + debt.totalDebt);
            final transactions = debts.fold<int>(0, (sum, debt) => sum + debt.transactionCount);
            final largest = debts.fold<int>(0, (max, debt) => debt.totalDebt > max ? debt.totalDebt : max);

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.spaceMd,
                AppSizes.screenPadding,
                AppSizes.spaceXl,
              ),
              itemCount: debts.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _TotalCard(
                    total: total,
                    customerCount: debts.length,
                    transactionCount: transactions,
                  );
                }
                if (index == 1) {
                  return const Padding(
                    padding: EdgeInsets.only(top: AppSizes.spaceLg),
                    child: SectionHeader(
                      title: 'Daftar Pelanggan',
                      subtitle: 'Urut dari hutang terbesar',
                    ),
                  );
                }
                final debt = debts[index - 2];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                  child: _DebtTile(
                    debt: debt,
                    share: largest > 0 ? debt.totalDebt / largest : 0,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerDebtTransactionsScreen(customerName: debt.customerName),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const AppLoadingView(message: 'Menghitung hutang...'),
          error: (error, stack) => _scroll(
            AppErrorView(
              title: 'Gagal memuat daftar hutang',
              message: AppErrorMessage.from(error),
              onRetry: () => ref.invalidate(unpaidDebtsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scroll(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.spaceXl),
      children: [child],
    );
  }
}

/// Kartu angka utama: total seluruh hutang yang masih berjalan.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.customerCount,
    required this.transactionCount,
  });

  final int total;
  final int customerCount;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      color: context.palette.accent50,
      borderColor: context.palette.accent100,
      padding: const EdgeInsets.all(AppSizes.spaceMl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.account_balance_wallet_outlined,
                tone: AppTone.accent,
                size: AppIconBadgeSize.sm,
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: Text('TOTAL HUTANG BERJALAN', style: context.textStyles.eyebrow),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMs),
          AppMoneyText(
            CurrencyFormatter.format(total),
            size: AppMoneySize.lg,
            color: context.palette.accentText,
          ),
          const SizedBox(height: AppSizes.spaceXs),
          Text(
            '$customerCount pelanggan · $transactionCount transaksi belum lunas',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Satu pelanggan berhutang: nama, jumlah transaksi, nominal, dan bar
/// proporsi terhadap penghutang terbesar.
class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt, required this.share, required this.onTap});

  final CustomerDebt debt;
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        children: [
          Row(
            children: [
              const AppIconBadge(icon: Icons.person_outline, tone: AppTone.accent),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      debt.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${debt.transactionCount} transaksi belum lunas',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              AppMoneyText(
                CurrencyFormatter.format(debt.totalDebt),
                color: context.palette.accentText,
              ),
            ],
          ),
          if (share > 0) ...[
            const SizedBox(height: AppSizes.spaceSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              child: LinearProgressIndicator(
                value: share.clamp(0, 1),
                color: context.palette.accent,
                backgroundColor: context.palette.accent100,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
