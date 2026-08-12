import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/points_settings.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_form_sheet.dart';
import '../widgets/merge_customers_sheet.dart';
import 'customer_detail_screen.dart';

/// Layar **Pelanggan** (PRD v1.1 §7.3.A & §7.6).
///
/// Menggantikan layar "Hutang Belum Lunas" yang berdiri sendiri: hutang
/// kini hanyalah **satu filter** di dalam daftar pelanggan, karena orang
/// yang berhutang dan orang yang berlangganan adalah orang yang sama —
/// memisahkan keduanya jadi dua layar memaksa pemilik warung mengingat di
/// layar mana sebuah nama tersimpan.
///
/// Navigasi bawah **tetap 5 tab**: layar ini dibuka dari kartu "Pelanggan"
/// di tab Laporan, dari sheet pembayaran, dan dari detail transaksi.
///
/// Mode pilih (long-press) dipakai untuk menggabungkan pelanggan kembar
/// (§7.3.D) — sengaja manual, karena penggabungan otomatis berbasis
/// kemiripan nama berisiko menyatukan dua orang berbeda.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key, this.initialOnlyWithDebt = false});

  /// `true` bila layar dibuka dari pintasan "Hutang berjalan".
  final bool initialOnlyWithDebt;

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<int> _selected = <int>{};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(customerFilterProvider.notifier)
        ..reset()
        ..setOnlyWithDebt(widget.initialOnlyWithDebt);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(customerListProvider.notifier).loadMore();
    }
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      _selectMode = _selected.isNotEmpty;
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
  }

  Future<void> _openMerge(List<CustomerListItem> items) async {
    final candidates =
        items.where((item) => _selected.contains(item.id)).toList();
    if (candidates.length < 2) return;
    final merged = await showMergeCustomers(context, candidates: candidates);
    if (merged == true) {
      _exitSelectMode();
      await ref.read(customerListProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(customerFilterProvider);
    final listAsync = ref.watch(customerListProvider);
    final points = ref.watch(pointsSettingsProvider).valueOrNull ??
        const PointsSettings();

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selected.length} dipilih' : 'Pelanggan'),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Batal pilih',
                onPressed: _exitSelectMode,
              )
            : null,
        actions: [
          if (_selectMode)
            TextButton.icon(
              onPressed: _selected.length < 2
                  ? null
                  : () => _openMerge(listAsync.valueOrNull?.items ?? const []),
              icon: const Icon(Icons.merge_rounded),
              label: const Text('Gabungkan'),
            )
          else
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Tambah pelanggan',
              onPressed: () async {
                final saved = await showCustomerForm(context);
                if (saved == true) {
                  await ref.read(customerListProvider.notifier).refresh();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(customerFilterProvider.notifier).setQuery(value),
            ),
            _FilterChips(filter: filter),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(customerListProvider.notifier).refresh(),
                child: listAsync.when(
                  data: (state) => _buildList(state, filter, points),
                  loading: () => const AppLoadingView(message: 'Memuat pelanggan...'),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      AppErrorView(
                        title: 'Daftar pelanggan gagal dimuat',
                        message: AppErrorMessage.from(e),
                        onRetry: () => ref.invalidate(customerListProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    CustomerListState state,
    CustomerFilter filter,
    PointsSettings points,
  ) {
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSizes.spaceXl),
        children: [
          if (filter.onlyWithDebt)
            EmptyState(
              icon: Icons.verified_outlined,
              tone: AppTone.success,
              title: 'Semua hutang sudah lunas',
              message: 'Tidak ada bon yang perlu ditagih. Catatan warungmu bersih.',
              actionLabel: 'Lihat semua pelanggan',
              onAction: () =>
                  ref.read(customerFilterProvider.notifier).setOnlyWithDebt(false),
            )
          else if (filter.query.trim().isNotEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Tidak ada yang cocok',
              message: 'Coba kata kunci lain, atau tambahkan pelanggan baru '
                  'lewat tombol + di kanan atas.',
            )
          else
            EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Belum ada pelanggan',
              message: 'Simpan pembeli langganan supaya kamu tidak perlu '
                  'mengetik namanya lagi setiap kali menagih.',
              actionLabel: 'Tambah Pelanggan',
              onAction: () async {
                final saved = await showCustomerForm(context);
                if (saved == true) {
                  await ref.read(customerListProvider.notifier).refresh();
                }
              },
            ),
        ],
      );
    }

    final showDebtSummary = filter.onlyWithDebt;
    final headerCount = showDebtSummary ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceMd,
        AppSizes.screenPadding,
        AppSizes.spaceXl,
      ),
      itemCount: state.items.length + headerCount + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (showDebtSummary && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
            child: _DebtTotalCard(
              total: state.totalDebt,
              debtorCount: state.debtorCount,
            ),
          );
        }
        final itemIndex = index - headerCount;
        if (itemIndex >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
            child: AppLoadingView(compact: true),
          );
        }
        final customer = state.items[itemIndex];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
          child: CustomerTile(
            customer: customer,
            points: points,
            selected: _selected.contains(customer.id),
            selectMode: _selectMode,
            onTap: () {
              if (_selectMode) {
                _toggleSelect(customer.id);
                return;
              }
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => CustomerDetailScreen(customerId: customer.id),
                    ),
                  )
                  .then((_) => ref.read(customerListProvider.notifier).refresh());
            },
            onLongPress: () => _toggleSelect(customer.id),
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceSm,
        AppSizes.screenPadding,
        AppSizes.spaceSm,
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Cari nama atau no. HP...',
          prefixIcon: Icon(Icons.search_rounded),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.filter});

  final CustomerFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(customerFilterProvider.notifier);
    return SizedBox(
      height: AppSizes.minTouchTarget,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: !filter.onlyWithDebt && !filter.includeInactive,
            onSelected: (_) => notifier
              ..setOnlyWithDebt(false)
              ..setIncludeInactive(false),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          ChoiceChip(
            label: const Text('Punya hutang'),
            avatar: const Icon(Icons.account_balance_wallet_outlined, size: AppSizes.iconSm),
            selected: filter.onlyWithDebt,
            onSelected: (value) => notifier.setOnlyWithDebt(value),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          ChoiceChip(
            label: const Text('Termasuk nonaktif'),
            selected: filter.includeInactive,
            onSelected: (value) => notifier.setIncludeInactive(value),
          ),
        ],
      ),
    );
  }
}

/// Angka utama saat filter hutang menyala — inilah yang dicari pemilik
/// warung ketika membuka layar ini lewat pintasan "Hutang berjalan".
class _DebtTotalCard extends StatelessWidget {
  const _DebtTotalCard({required this.total, required this.debtorCount});

  final int total;
  final int debtorCount;

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
            '$debtorCount pelanggan masih punya hutang',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Satu baris pelanggan pada daftar utama.
class CustomerTile extends StatelessWidget {
  const CustomerTile({
    super.key,
    required this.customer,
    required this.onTap,
    this.onLongPress,
    this.points = const PointsSettings(),
    this.selected = false,
    this.selectMode = false,
  });

  final CustomerListItem customer;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final PointsSettings points;
  final bool selected;
  final bool selectMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (customer.phone != null && customer.phone!.isNotEmpty) customer.phone!,
      if (customer.lastTransactionAt != null)
        'Terakhir ${DateFormatter.formatDateShort(customer.lastTransactionAt!)}'
      else
        'Belum pernah belanja',
    ];

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          if (selectMode)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.spaceSm),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? context.palette.primary
                    : context.palette.inkTertiary,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.spaceMs),
              child: AppIconBadge(
                icon: Icons.person_outline_rounded,
                tone: customer.hasDebt ? AppTone.accent : AppTone.neutral,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (!customer.isActive) ...[
                      const SizedBox(width: AppSizes.spaceSm),
                      const AppPill(label: 'Nonaktif', dense: true),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (points.enabled || customer.hasDebt) ...[
                  const SizedBox(height: AppSizes.spaceSm),
                  Wrap(
                    spacing: AppSizes.spaceSm,
                    runSpacing: AppSizes.spaceXs,
                    children: [
                      if (customer.hasDebt)
                        AppPill(
                          label: 'Hutang ${CurrencyFormatter.format(customer.totalDebt)}',
                          tone: AppTone.accent,
                          icon: Icons.account_balance_wallet_outlined,
                          dense: true,
                        ),
                      if (points.enabled)
                        AppPill(
                          label: '${customer.points} poin',
                          tone: AppTone.accent,
                          icon: Icons.stars_rounded,
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!selectMode)
            Icon(
              Icons.chevron_right_rounded,
              color: context.palette.inkTertiary,
            ),
        ],
      ),
    );
  }
}
