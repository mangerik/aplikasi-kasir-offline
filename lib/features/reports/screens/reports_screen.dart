import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../domain/repositories/report_repository.dart';
import '../providers/report_providers.dart';
import '../widgets/summary_card.dart';
import '../widgets/top_product_tile.dart';
import 'debt_list_screen.dart';

/// Dashboard Laporan (plan.md Milestone 4 poin 4-7, menggantikan stub
/// Milestone 0): ringkasan omzet/transaksi/laba kotor per metode bayar
/// untuk rentang tanggal terpilih (preset hari ini/kemarin/7 hari/bulan
/// ini/custom), produk terlaris, dan pintasan ke daftar hutang belum lunas.
///
/// Seluruh angka DIHITUNG DI SQL (`ReportRepository`, plan.md Milestone 4
/// poin 8) — layar ini murni menampilkan hasil.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportDateRangeProvider);
    final summaryAsync = ref.watch(dailySummaryProvider);
    final topProductsAsync = ref.watch(topProductsProvider);
    final sortBy = ref.watch(topProductSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            tooltip: 'Daftar hutang belum lunas',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DebtListScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailySummaryProvider);
          ref.invalidate(topProductsProvider);
          await ref.read(dailySummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          children: [
            const _PresetSelector(),
            const SizedBox(height: AppSizes.spaceXs),
            Text(
              '${DateFormatter.formatDateShort(range.start)} - '
              '${DateFormatter.formatDateShort(range.end)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            summaryAsync.when(
              data: (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          label: 'Omzet',
                          value: CurrencyFormatter.format(summary.totalOmzet),
                          icon: Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSizes.spaceSm),
                      Expanded(
                        child: SummaryCard(
                          label: 'Transaksi',
                          value: '${summary.transactionCount}',
                          icon: Icons.receipt_outlined,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spaceSm),
                  SummaryCard(
                    label: 'Laba Kotor',
                    value: CurrencyFormatter.format(summary.grossProfit),
                    icon: Icons.trending_up,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: AppSizes.spaceLg),
                  Text('Per Metode Bayar', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSizes.spaceSm),
                  if (summary.byPaymentMethod.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
                      child: Text(
                        'Belum ada transaksi pada rentang ini.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...summary.byPaymentMethod.map(
                      (method) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_methodLabel(method.method)} (${method.count})',
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(method.total),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.spaceXl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text('Gagal memuat ringkasan: ${AppErrorMessage.from(error)}'),
            ),
            const SizedBox(height: AppSizes.spaceLg),
            Row(
              children: [
                Expanded(
                  child: Text('Produk Terlaris', style: Theme.of(context).textTheme.titleMedium),
                ),
                SegmentedButton<TopProductSort>(
                  segments: const [
                    ButtonSegment(value: TopProductSort.qty, label: Text('Qty')),
                    ButtonSegment(value: TopProductSort.value, label: Text('Nilai')),
                  ],
                  selected: {sortBy},
                  onSelectionChanged: (selection) =>
                      ref.read(topProductSortProvider.notifier).set(selection.first),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceSm),
            topProductsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
                    child: Text(
                      'Belum ada penjualan pada rentang ini.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < products.length; i++)
                      TopProductTile(rank: i + 1, product: products[i]),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.spaceLg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Text('Gagal memuat produk terlaris: ${AppErrorMessage.from(error)}'),
            ),
            const SizedBox(height: AppSizes.spaceXl),
          ],
        ),
      ),
    );
  }

  String _methodLabel(String method) => switch (method) {
        'cash' => 'Tunai',
        'noncash' => 'Non-tunai',
        'debt' => 'Hutang',
        _ => method,
      };
}

class _PresetSelector extends ConsumerWidget {
  const _PresetSelector();

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).setCustomRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePreset = ref.watch(reportDateRangeProvider).preset;
    return Wrap(
      spacing: AppSizes.spaceSm,
      runSpacing: AppSizes.spaceSm,
      children: [
        _PresetChip(
          label: 'Hari ini',
          selected: activePreset == ReportRangePreset.today,
          onSelected: () =>
              ref.read(reportDateRangeProvider.notifier).setPreset(ReportRangePreset.today),
        ),
        _PresetChip(
          label: 'Kemarin',
          selected: activePreset == ReportRangePreset.yesterday,
          onSelected: () =>
              ref.read(reportDateRangeProvider.notifier).setPreset(ReportRangePreset.yesterday),
        ),
        _PresetChip(
          label: '7 Hari',
          selected: activePreset == ReportRangePreset.last7Days,
          onSelected: () =>
              ref.read(reportDateRangeProvider.notifier).setPreset(ReportRangePreset.last7Days),
        ),
        _PresetChip(
          label: 'Bulan Ini',
          selected: activePreset == ReportRangePreset.thisMonth,
          onSelected: () =>
              ref.read(reportDateRangeProvider.notifier).setPreset(ReportRangePreset.thisMonth),
        ),
        _PresetChip(
          label: 'Custom',
          selected: activePreset == ReportRangePreset.custom,
          onSelected: () => _pickCustomRange(context, ref),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onSelected: (_) => onSelected(),
    );
  }
}
