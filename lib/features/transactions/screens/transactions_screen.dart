import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/error_message.dart';
import '../providers/history_providers.dart';
import '../widgets/history_filter_sheet.dart';
import '../widgets/history_tile.dart';
import 'sale_detail_screen.dart';

/// Layar Riwayat transaksi (plan.md Milestone 3 poin 2): daftar semua
/// transaksi (terbaru dulu), filter tanggal/metode/status, infinite
/// scroll/pagination efisien (LIMIT/OFFSET, lihat
/// `features/transactions/providers/history_providers.dart`).
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

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyListProvider);
    final filter = ref.watch(historyFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Filter riwayat',
                icon: const Icon(Icons.filter_list),
                onPressed: () => HistoryFilterSheet.show(context),
              ),
              if (filter.isActive)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(historyListProvider.notifier).refresh(),
        child: historyAsync.when(
          data: (state) {
            if (state.items.isEmpty) {
              return _EmptyState(hasFilter: filter.isActive);
            }
            return ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: AppSizes.spaceLg),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSizes.spaceMd),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final sale = state.items[index];
                return HistoryTile(
                  sale: sale,
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: sale.id))),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.spaceLg),
              child: Text('Gagal memuat riwayat: ${AppErrorMessage.from(error)}', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              hasFilter ? 'Tidak ada transaksi yang cocok' : 'Belum ada transaksi',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              hasFilter
                  ? 'Coba ubah atau reset filter riwayat.'
                  : 'Transaksi yang sudah dibayar akan muncul di sini.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
