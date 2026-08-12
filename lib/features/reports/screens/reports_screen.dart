import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/daily_summary.dart';
import '../../../domain/entities/top_product.dart';
import '../../../domain/repositories/report_repository.dart';
import '../../transactions/widgets/status_badge.dart';
import '../providers/report_providers.dart';
import '../widgets/summary_card.dart';
import '../widgets/top_product_tile.dart';
import 'debt_list_screen.dart';

/// Dashboard Laporan (plan.md Milestone 4 poin 4-7): ringkasan omzet/
/// transaksi/laba kotor per metode bayar untuk rentang tanggal terpilih,
/// produk terlaris, dan pintasan ke daftar hutang belum lunas.
///
/// Seluruh angka DIHITUNG DI SQL (`ReportRepository`, plan.md Milestone 4
/// poin 8) — layar ini murni menampilkan hasil.
///
/// Desain (docs/ui-redesign-foundation.md): satu angka utama (omzet) yang
/// mendominasi layar, dua angka pendukung di bawahnya, lalu cerita
/// pendukung (komposisi metode bayar & produk terlaris) dengan bar proporsi
/// supaya bisa dibaca sekilas tanpa membandingkan digit satu per satu.
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
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => _openDebtList(context),
          ),
          const SizedBox(width: AppSizes.spaceXs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailySummaryProvider);
          ref.invalidate(topProductsProvider);
          ref.invalidate(unpaidDebtsProvider);
          await ref.read(dailySummaryProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.spaceMs,
            AppSizes.screenPadding,
            AppSizes.bottomSafePadding,
          ),
          children: [
            const _PresetSelector(),
            const SizedBox(height: AppSizes.spaceSm),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: AppSizes.iconSm,
                  color: context.palette.inkSecondary,
                ),
                const SizedBox(width: AppSizes.spaceXs + 2),
                Expanded(
                  child: Text(
                    '${DateFormatter.formatDateShort(range.start)} — '
                    '${DateFormatter.formatDateShort(range.end)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceMd),

            // --- Angka utama.
            summaryAsync.when(
              data: (summary) => _SummarySection(summary: summary),
              loading: () => const AppLoadingView(compact: true),
              error: (error, stack) => AppErrorView(
                compact: true,
                title: 'Gagal memuat ringkasan',
                message: AppErrorMessage.from(error),
                onRetry: () => ref.invalidate(dailySummaryProvider),
              ),
            ),

            // --- Hutang berjalan (satu-satunya elemen beraksen di layar ini).
            const _DebtShortcut(),

            const SizedBox(height: AppSizes.spaceXl),

            // --- Produk terlaris.
            SectionHeader(
              title: 'Produk Terlaris',
              subtitle: 'Diurutkan berdasarkan '
                  '${sortBy == TopProductSort.qty ? 'jumlah terjual' : 'nilai penjualan'}',
              trailing: SegmentedButton<TopProductSort>(
                segments: const [
                  ButtonSegment(value: TopProductSort.qty, label: Text('Qty')),
                  ButtonSegment(value: TopProductSort.value, label: Text('Nilai')),
                ],
                selected: {sortBy},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    ref.read(topProductSortProvider.notifier).set(selection.first),
              ),
            ),
            topProductsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const EmptyState(
                    compact: true,
                    icon: Icons.inventory_2_outlined,
                    title: 'Belum ada barang terjual',
                    message: 'Coba pilih rentang tanggal yang lain untuk melihat '
                        'barang yang paling laku.',
                  );
                }
                return _TopProductList(products: products, sortBy: sortBy);
              },
              loading: () => const AppLoadingView(compact: true),
              error: (error, stack) => AppErrorView(
                compact: true,
                title: 'Gagal memuat produk terlaris',
                message: AppErrorMessage.from(error),
                onRetry: () => ref.invalidate(topProductsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openDebtList(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebtListScreen()));
  }
}

/// Blok angka: omzet (hero), transaksi & laba kotor, lalu komposisi
/// metode bayar.
class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final hasProfit = summary.grossProfit > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SummaryCard(
          hero: true,
          label: 'Omzet',
          value: CurrencyFormatter.format(summary.totalOmzet),
          icon: Icons.payments_outlined,
          caption: summary.transactionCount == 0
              ? 'Belum ada transaksi pada rentang ini'
              : 'Dari ${summary.transactionCount} transaksi selesai',
        ),
        const SizedBox(height: AppSizes.spaceSm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SummaryCard(
                label: 'Transaksi',
                value: '${summary.transactionCount}',
                icon: Icons.receipt_long_outlined,
                tone: AppTone.info,
              ),
            ),
            const SizedBox(width: AppSizes.spaceSm),
            Expanded(
              child: SummaryCard(
                label: 'Laba Kotor',
                value: CurrencyFormatter.format(summary.grossProfit),
                icon: Icons.trending_up_rounded,
                tone: hasProfit ? AppTone.success : AppTone.neutral,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceXl),
        SectionHeader(
          title: 'Cara Pelanggan Bayar',
          subtitle: 'Komposisi omzet per metode pembayaran',
        ),
        if (summary.byPaymentMethod.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.point_of_sale_outlined,
            title: 'Belum ada pembayaran masuk',
            message: 'Transaksi pada rentang tanggal ini belum ada. '
                'Coba pilih rentang lain di atas.',
          )
        else
          AppCard(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            child: Column(
              children: [
                for (var i = 0; i < summary.byPaymentMethod.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSizes.spaceMd),
                  _PaymentMethodRow(
                    entry: summary.byPaymentMethod[i],
                    share: _share(summary.byPaymentMethod[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  double _share(PaymentMethodTotal entry) {
    final total = summary.byPaymentMethod.fold<int>(0, (sum, e) => sum + e.total);
    if (total <= 0) return 0;
    return entry.total / total;
  }
}

/// Satu baris metode bayar + bar proporsinya terhadap total omzet.
class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({required this.entry, required this.share});

  final PaymentMethodTotal entry;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = paymentMethodTone(entry.method);
    final c = tone.colorsOf(context);

    return Column(
      children: [
        Row(
          children: [
            AppIconBadge(
              icon: paymentMethodIcon(entry.method),
              tone: tone,
              size: AppIconBadgeSize.sm,
            ),
            const SizedBox(width: AppSizes.spaceMs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(paymentMethodLabel(entry.method), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.count} transaksi · ${(share * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.spaceSm),
            AppMoneyText(CurrencyFormatter.format(entry.total)),
          ],
        ),
        const SizedBox(height: AppSizes.spaceSm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: LinearProgressIndicator(
            value: share.clamp(0, 1),
            color: c.fg,
            backgroundColor: c.bg,
          ),
        ),
      ],
    );
  }
}

/// Pintasan hutang berjalan — hanya muncul kalau memang ada hutang.
class _DebtShortcut extends ConsumerWidget {
  const _DebtShortcut();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(unpaidDebtsProvider);

    return debtsAsync.maybeWhen(
      data: (debts) {
        if (debts.isEmpty) return const SizedBox.shrink();
        final total = debts.fold<int>(0, (sum, debt) => sum + debt.totalDebt);

        return Padding(
          padding: const EdgeInsets.only(top: AppSizes.spaceMd),
          child: AppCard(
            color: context.palette.accent50,
            borderColor: context.palette.accent100,
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DebtListScreen())),
            child: Row(
              children: [
                const AppIconBadge(
                  icon: Icons.account_balance_wallet_outlined,
                  tone: AppTone.accent,
                ),
                const SizedBox(width: AppSizes.spaceMs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('PERLU DITAGIH', style: context.textStyles.eyebrow),
                      const SizedBox(height: AppSizes.spaceXs),
                      AppMoneyText(
                        CurrencyFormatter.format(total),
                        color: context.palette.accentText,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${debts.length} pelanggan masih punya hutang',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.accentText,
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Daftar produk terlaris dengan bar proporsi terhadap peringkat 1.
class _TopProductList extends StatelessWidget {
  const _TopProductList({required this.products, required this.sortBy});

  final List<TopProduct> products;
  final TopProductSort sortBy;

  @override
  Widget build(BuildContext context) {
    double metric(TopProduct p) =>
        sortBy == TopProductSort.qty ? p.qtySold : p.totalValue.toDouble();
    final top = metric(products.first);

    return Column(
      children: [
        for (var i = 0; i < products.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
            child: TopProductTile(
              rank: i + 1,
              product: products[i],
              share: top > 0 ? metric(products[i]) / top : 0,
            ),
          ),
      ],
    );
  }
}

/// Pemilih rentang tanggal laporan (plan.md Milestone 4 poin 5).
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

    return SizedBox(
      height: AppSizes.minTouchTarget,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
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
            label: 'Pilih Tanggal',
            icon: Icons.event_outlined,
            selected: activePreset == ReportRangePreset.custom,
            onSelected: () => _pickCustomRange(context, ref),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.spaceSm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: AppSizes.iconSm,
                color: selected ? context.palette.primary : context.palette.inkSecondary,
              ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMs,
          vertical: AppSizes.spaceSm + 2,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
