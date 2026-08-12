import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/sale.dart';
import '../providers/history_providers.dart';
import '../widgets/history_filter_sheet.dart';
import '../widgets/history_tile.dart';
import 'sale_detail_screen.dart';

/// Layar Riwayat transaksi (plan.md Milestone 3 poin 2): daftar semua
/// transaksi (terbaru dulu), filter tanggal/metode/status, infinite
/// scroll/pagination efisien (LIMIT/OFFSET, lihat
/// `features/transactions/providers/history_providers.dart`).
///
/// Desain (docs/ui-redesign-foundation.md): daftar kartu ringan yang
/// dikelompokkan per hari supaya mudah dipindai, nominal sebagai elemen
/// paling menonjol, dan status non-lunas ditandai [AppPill] bernada.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(historyListProvider.notifier).loadMore();
    }
  }

  void _openDetail(Sale sale) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale.id)));
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyListProvider);
    final filter = ref.watch(historyFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          IconButton(
            tooltip: filter.isActive ? 'Ubah filter riwayat' : 'Filter riwayat',
            // Ikon filled = filter sedang aktif (foundation §7.1 poin 13).
            icon: Icon(
              filter.isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: filter.isActive ? AppColors.primary : null,
            ),
            onPressed: () => HistoryFilterSheet.show(context),
          ),
          const SizedBox(width: AppSizes.spaceXs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(historyListProvider.notifier).refresh(),
        child: Column(
          children: [
            if (filter.isActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.spaceMs,
                  AppSizes.screenPadding,
                  0,
                ),
                child: AppBanner(
                  tone: AppTone.primary,
                  icon: Icons.filter_alt_outlined,
                  title: 'Filter aktif',
                  message: historyFilterSummary(filter),
                  actionLabel: 'Hapus filter',
                  onAction: () => ref.read(historyFilterProvider.notifier).reset(),
                ),
              ),
            Expanded(
              child: historyAsync.when(
                data: (state) {
                  if (state.items.isEmpty) {
                    return _emptyScroll(
                      filter.isActive
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Tidak ada transaksi yang cocok',
                              message:
                                  'Coba longgarkan rentang tanggalnya, atau hapus '
                                  'filter untuk melihat semua transaksi.',
                              actionLabel: 'Hapus Filter',
                              onAction: () =>
                                  ref.read(historyFilterProvider.notifier).reset(),
                              secondaryActionLabel: 'Ubah Filter',
                              onSecondaryAction: () => HistoryFilterSheet.show(context),
                            )
                          : EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'Belum ada transaksi',
                              message:
                                  'Setiap penjualan yang selesai dibayar akan '
                                  'tercatat di sini beserta strukmya.',
                              actionLabel: 'Mulai Jualan',
                              onAction: () => context.go(AppRoutes.pos),
                            ),
                    );
                  }
                  return _HistoryList(
                    controller: _scrollController,
                    items: state.items,
                    hasMore: state.hasMore,
                    onTapSale: _openDetail,
                  );
                },
                loading: () => const AppLoadingView(message: 'Memuat riwayat...'),
                error: (error, stack) => _emptyScroll(
                  AppErrorView(
                    title: 'Gagal memuat riwayat',
                    message: AppErrorMessage.from(error),
                    onRetry: () => ref.invalidate(historyListProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membungkus tampilan kosong/error dalam scroll view supaya
  /// pull-to-refresh tetap bisa dipakai walau kontennya pendek.
  Widget _emptyScroll(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.bottomSafePadding),
      children: [child],
    );
  }
}

/// Daftar riwayat yang dikelompokkan per hari.
///
/// Pengelompokan MURNI tampilan (dihitung dari data halaman yang sudah
/// dimuat) — tidak ada query/logika baru.
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.controller,
    required this.items,
    required this.hasMore,
    required this.onTapSale,
  });

  final ScrollController controller;
  final List<Sale> items;
  final bool hasMore;
  final void Function(Sale sale) onTapSale;

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(items);

    return ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceMs,
        AppSizes.screenPadding,
        AppSizes.bottomSafePadding,
      ),
      itemCount: rows.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
            child: AppLoadingView(compact: true),
          );
        }
        final row = rows[index];
        if (row.header != null) {
          return _DayHeader(day: row.header!, isFirst: index == 0);
        }
        final sale = row.sale!;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
          child: HistoryTile(sale: sale, onTap: () => onTapSale(sale)),
        );
      },
    );
  }

  static List<_HistoryRow> _buildRows(List<Sale> items) {
    final rows = <_HistoryRow>[];
    DateTime? currentDay;
    for (final sale in items) {
      final day = DateUtils.dateOnly(sale.createdAt.toLocal());
      if (currentDay == null || !DateUtils.isSameDay(currentDay, day)) {
        rows.add(_HistoryRow.header(day));
        currentDay = day;
      }
      rows.add(_HistoryRow.sale(sale));
    }
    return rows;
  }
}

class _HistoryRow {
  const _HistoryRow.header(DateTime this.header) : sale = null;
  const _HistoryRow.sale(Sale this.sale) : header = null;

  final DateTime? header;
  final Sale? sale;
}

/// Judul kelompok tanggal: "HARI INI" · "KEMARIN" · "12 AGU 2026".
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.isFirst});

  final DateTime day;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : AppSizes.spaceMs,
        bottom: AppSizes.spaceSm,
      ),
      child: Row(
        children: [
          Text(_label(day), style: AppTextStyles.eyebrow),
          const SizedBox(width: AppSizes.spaceMs),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  static String _label(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'HARI INI';
    if (diff == 1) return 'KEMARIN';
    return DateFormatter.formatDateShort(day).toUpperCase();
  }
}
