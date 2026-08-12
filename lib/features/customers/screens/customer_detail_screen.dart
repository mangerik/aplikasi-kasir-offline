import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/customer_point_entry.dart';
import '../../../domain/entities/points_settings.dart';
import '../../../domain/entities/sale.dart';
import '../../settings/providers/settings_providers.dart';
import '../../transactions/screens/sale_detail_screen.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_form_sheet.dart';

/// Detail satu pelanggan (PRD v1.1 §7.3.A): ringkasan, riwayat belanja,
/// riwayat poin.
///
/// Urutan bagian mengikuti urutan pertanyaan pemilik warung: *berapa*
/// (kartu ringkasan, angka besar di atas label kecil) → *dari mana*
/// (riwayat belanja) → *poinnya bagaimana* (buku besar). Riwayat belanja
/// dipaginasi 20 baris sekali muat, sehingga pelanggan dengan 5.000
/// transaksi pun tetap membuka layar ini seketika (AC-7.15).
class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(customerSalesProvider(widget.customerId).notifier).loadMore();
    }
  }

  void _refreshAll() {
    ref
      ..invalidate(customerDetailProvider(widget.customerId))
      ..invalidate(customerSummaryProvider(widget.customerId))
      ..invalidate(customerPointEntriesProvider(widget.customerId))
      ..invalidate(customerSalesProvider(widget.customerId))
      ..invalidate(customerListProvider)
      ..invalidate(customerDebtOverviewProvider);
  }

  Future<void> _edit(Customer customer) async {
    final saved = await showCustomerForm(context, customer: customer);
    if (saved == true) _refreshAll();
  }

  Future<void> _toggleActive(Customer customer) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(customerRepoProvider);
      if (customer.isActive) {
        await repo.deactivate(customer.id);
      } else {
        await repo.reactivate(customer.id);
      }
      _refreshAll();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            customer.isActive
                ? '${customer.name} dinonaktifkan.'
                : '${customer.name} diaktifkan kembali.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AppErrorMessage.from(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customerId));
    final points =
        ref.watch(pointsSettingsProvider).valueOrNull ?? const PointsSettings();

    return Scaffold(
      appBar: AppBar(
        title: Text(customerAsync.valueOrNull?.name ?? 'Pelanggan'),
        actions: [
          if (customerAsync.valueOrNull != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Ubah data pelanggan',
              onPressed: () => _edit(customerAsync.value!),
            ),
            IconButton(
              icon: Icon(
                customerAsync.value!.isActive
                    ? Icons.person_off_outlined
                    : Icons.person_add_alt_outlined,
              ),
              tooltip: customerAsync.value!.isActive
                  ? 'Nonaktifkan pelanggan'
                  : 'Aktifkan kembali',
              onPressed: () => _toggleActive(customerAsync.value!),
            ),
          ],
        ],
      ),
      body: customerAsync.when(
        data: (customer) => _buildBody(customer, points),
        loading: () => const AppLoadingView(message: 'Memuat pelanggan…'),
        error: (e, _) => AppErrorView(
          title: 'Pelanggan gagal dimuat',
          message: AppErrorMessage.from(e),
          onRetry: () => ref.invalidate(customerDetailProvider(widget.customerId)),
        ),
      ),
    );
  }

  Widget _buildBody(Customer customer, PointsSettings points) {
    final summaryAsync = ref.watch(customerSummaryProvider(widget.customerId));
    final salesAsync = ref.watch(customerSalesProvider(widget.customerId));
    final entriesAsync = ref.watch(customerPointEntriesProvider(widget.customerId));

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.spaceMd,
          AppSizes.screenPadding,
          AppSizes.spaceXl,
        ),
        children: [
          _IdentityCard(customer: customer),
          const SizedBox(height: AppSizes.spaceLg),
          summaryAsync.when(
            data: (summary) => _SummaryGrid(summary: summary, points: points),
            loading: () => const AppLoadingView(compact: true),
            error: (e, _) => AppErrorView(
              title: 'Ringkasan gagal dihitung',
              message: AppErrorMessage.from(e),
              compact: true,
            ),
          ),
          const SizedBox(height: AppSizes.spaceXl),
          const SectionHeader(
            eyebrow: 'RIWAYAT',
            title: 'Belanja',
            subtitle: 'Transaksi terbaru di atas.',
          ),
          salesAsync.when(
            data: (state) => _SalesList(state: state),
            loading: () => const AppLoadingView(compact: true),
            error: (e, _) => AppErrorView(
              title: 'Riwayat belanja gagal dimuat',
              message: AppErrorMessage.from(e),
              compact: true,
            ),
          ),
          if (points.enabled) ...[
            const SizedBox(height: AppSizes.spaceXl),
            const SectionHeader(
              eyebrow: 'PROGRAM POIN',
              title: 'Buku Besar Poin',
              subtitle: 'Setiap poin masuk & keluar tercatat di sini.',
            ),
            entriesAsync.when(
              data: (entries) => _PointEntryList(entries: entries),
              loading: () => const AppLoadingView(compact: true),
              error: (e, _) => AppErrorView(
                title: 'Riwayat poin gagal dimuat',
                message: AppErrorMessage.from(e),
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSizes.spaceMl),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.person_outline_rounded,
            tone: AppTone.primary,
            size: AppIconBadgeSize.lg,
          ),
          const SizedBox(width: AppSizes.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(customer.name, style: theme.textTheme.titleLarge),
                if (customer.hasPhone) ...[
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(customer.phone!, style: theme.textTheme.bodyMedium),
                ],
                if (customer.note != null && customer.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.spaceXs),
                  Text(customer.note!, style: theme.textTheme.bodySmall),
                ],
                if (!customer.isActive) ...[
                  const SizedBox(height: AppSizes.spaceSm),
                  AppPill(
                    label: customer.isMerged
                        ? 'Digabung ke pelanggan lain'
                        : 'Nonaktif',
                    tone: AppTone.neutral,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empat angka ringkasan — nilainya besar, labelnya kecil (angka yang
/// dicari, bukan namanya).
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.points});

  final CustomerSummary summary;
  final PointsSettings points;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _SummaryTile(
        label: 'TOTAL BELANJA',
        value: CurrencyFormatter.format(summary.totalSpent),
        icon: Icons.shopping_bag_outlined,
        tone: AppTone.primary,
      ),
      _SummaryTile(
        label: 'JUMLAH TRANSAKSI',
        value: '${summary.transactionCount}',
        icon: Icons.receipt_long_outlined,
        tone: AppTone.info,
      ),
      _SummaryTile(
        label: 'SISA HUTANG',
        value: CurrencyFormatter.format(summary.totalDebt),
        icon: Icons.account_balance_wallet_outlined,
        tone: summary.totalDebt > 0 ? AppTone.accent : AppTone.success,
      ),
      if (points.enabled)
        _SummaryTile(
          label: 'SALDO POIN',
          value: '${summary.points}',
          icon: Icons.stars_rounded,
          tone: AppTone.accent,
        ),
    ];

    return Column(
      children: [
        for (var row = 0; row < tiles.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSizes.spaceSm),
          // `IntrinsicHeight` supaya dua kartu dalam satu baris sama
          // tinggi walau panjang angkanya berbeda — tanpa itu barisnya
          // terlihat "patah" saat salah satu nominal jauh lebih panjang.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = row; i < row + 2 && i < tiles.length; i++) ...[
                  if (i > row) const SizedBox(width: AppSizes.spaceSm),
                  Expanded(child: tiles[i]),
                ],
                if (row + 2 > tiles.length) ...[
                  const SizedBox(width: AppSizes.spaceSm),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final c = tone.colorsOf(context);
    return AppCard(
      color: c.bg,
      borderColor: c.border,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: c.fg),
          const SizedBox(height: AppSizes.spaceSm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.money.copyWith(color: c.fg),
          ),
          const SizedBox(height: AppSizes.spaceXs),
          Text(label, style: context.textStyles.eyebrow),
        ],
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({required this.state});

  final CustomerSalesState state;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada transaksi',
        message: 'Transaksi yang memilih pelanggan ini akan muncul di sini.',
        compact: true,
      );
    }

    return Column(
      children: [
        for (final sale in state.items) ...[
          _SaleTile(sale: sale),
          const SizedBox(height: AppSizes.spaceSm),
        ],
        if (state.hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
            child: AppLoadingView(compact: true),
          ),
      ],
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, tone) = switch (sale.status) {
      'voided' => ('Batal', AppTone.danger),
      'debt_unpaid' => ('Hutang', AppTone.accent),
      _ => ('Lunas', AppTone.success),
    };

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id)),
      ),
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sale.invoiceNumber, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  DateFormatter.formatDateTime(sale.createdAt),
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
                strikethrough: sale.status == 'voided',
              ),
              const SizedBox(height: AppSizes.spaceXs),
              AppPill(label: label, tone: tone, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// Riwayat poin: tanda +/− berwarna sukses/danger, saldo setelahnya di
/// baris kedua supaya sengketa "kok poinnya berkurang?" bisa ditelusuri
/// baris demi baris.
class _PointEntryList extends StatelessWidget {
  const _PointEntryList({required this.entries});

  final List<CustomerPointEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.stars_outlined,
        title: 'Belum ada poin',
        message: 'Poin muncul otomatis setiap pelanggan ini belanja, selama '
            'program poin menyala.',
        compact: true,
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceSm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.palette.border),
            _PointEntryRow(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _PointEntryRow extends StatelessWidget {
  const _PointEntryRow({required this.entry});

  final CustomerPointEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = entry.points > 0;
    final color = entry.points == 0
        ? context.palette.inkSecondary
        : (positive ? context.palette.successText : context.palette.dangerText);
    final sign = entry.points > 0 ? '+' : '';

    final subtitle = <String>[
      DateFormatter.formatDateTime(entry.createdAt),
      if (entry.invoiceNumber != null) entry.invoiceNumber!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.typeLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.palette.inkTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$sign${entry.points}',
                style: context.textStyles.numeric.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              Text(
                'sisa ${entry.balanceAfter}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
