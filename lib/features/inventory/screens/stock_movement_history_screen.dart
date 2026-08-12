import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/product.dart';
import '../providers/stock_providers.dart';
import '../widgets/stock_movement_tile.dart';
import 'stock_adjustment_screen.dart';

/// Layar riwayat pergerakan stok SATU produk (plan.md Milestone 4 poin 2):
/// jenis, qty ±, stok akhir, referensi transaksi, waktu — terbaru dulu,
/// infinite scroll (pola sama dengan Riwayat Transaksi Milestone 3).
///
/// Judul AppBar dipersingkat jadi "Riwayat Stok"; nama produk & stok
/// terakhir pindah ke kartu ringkasan di atas daftar supaya tidak terpotong
/// di HP kecil dan tetap terbaca sebagai konteks.
class StockMovementHistoryScreen extends ConsumerStatefulWidget {
  const StockMovementHistoryScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StockMovementHistoryScreen> createState() => _StockMovementHistoryScreenState();
}

class _StockMovementHistoryScreenState extends ConsumerState<StockMovementHistoryScreen> {
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
      ref.read(stockMovementListProvider(widget.product.id).notifier).loadMore();
    }
  }

  Future<void> _openAdjustment() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: widget.product)),
    );
    if (saved == true) {
      await ref.read(stockMovementListProvider(widget.product.id).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(stockMovementListProvider(widget.product.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Stok')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdjustment,
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Sesuaikan Stok'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceMs,
              AppSizes.screenPadding,
              AppSizes.spaceSm,
            ),
            child: _ProductSummary(product: widget.product),
          ),
          Expanded(
            child: stateAsync.when(
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.swap_vert_rounded,
                    tone: AppTone.neutral,
                    title: 'Belum ada pergerakan stok',
                    message:
                        'Penjualan, pembatalan, dan penyesuaian manual akan '
                        'tercatat di sini lengkap dengan alasannya.',
                    actionLabel: 'Sesuaikan Stok',
                    onAction: _openAdjustment,
                  );
                }
                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    AppSizes.spaceXs,
                    AppSizes.screenPadding,
                    AppSizes.bottomSafePadding,
                  ),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.spaceSm),
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return const AppLoadingView(compact: true);
                    }
                    return StockMovementTile(
                      movement: state.items[index],
                      unit: widget.product.unit,
                    );
                  },
                );
              },
              loading: () => const AppLoadingView(message: 'Memuat riwayat…'),
              error: (error, stack) => AppErrorView(
                title: 'Gagal memuat riwayat stok',
                message: AppErrorMessage.from(error),
                onRetry: () =>
                    ref.invalidate(stockMovementListProvider(widget.product.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu konteks di atas daftar: produk mana & stok terakhirnya.
class _ProductSummary extends StatelessWidget {
  const _ProductSummary({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.inventory_2_outlined,
            size: AppIconBadgeSize.md,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Text(
              product.name,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('STOK KINI', style: AppTextStyles.eyebrow),
              const SizedBox(height: AppSizes.spaceXs),
              Text(
                '${_formatNum(product.stock)} ${product.unit}',
                style: AppTextStyles.numeric.copyWith(fontSize: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
