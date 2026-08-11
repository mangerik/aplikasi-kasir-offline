import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../domain/entities/customer_debt.dart';
import '../providers/report_providers.dart';
import 'customer_debt_transactions_screen.dart';

/// Layar daftar hutang belum lunas, DIKELOMPOKKAN PER PELANGGAN (plan.md
/// Milestone 4 poin 7) — total per pelanggan lewat agregasi SQL
/// `ReportRepository.getUnpaidDebts`. Tap satu pelanggan -> daftar
/// transaksi hutangnya.
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
              return const _EmptyState();
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
              itemCount: debts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final debt = debts[index];
                return _DebtTile(
                  debt: debt,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerDebtTransactionsScreen(customerName: debt.customerName),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              child: Text('Gagal memuat daftar hutang: ${AppErrorMessage.from(error)}', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt, required this.onTap});

  final CustomerDebt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceXs,
      ),
      leading: const CircleAvatar(
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        child: Icon(Icons.person_outline),
      ),
      title: Text(debt.customerName, style: theme.textTheme.titleMedium),
      subtitle: Text('${debt.transactionCount} transaksi belum lunas'),
      trailing: Text(
        CurrencyFormatter.format(debt.totalDebt),
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.danger,
          fontWeight: FontWeight.bold,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
            const SizedBox(height: AppSizes.spaceMd),
            Text('Tidak ada hutang belum lunas', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              'Semua transaksi hutang sudah dilunasi.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
