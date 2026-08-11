import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/product.dart';
import '../providers/stock_providers.dart';
import '../widgets/stock_movement_tile.dart';
import 'stock_adjustment_screen.dart';

/// Layar riwayat pergerakan stok SATU produk (plan.md Milestone 4 poin 2):
/// jenis, qty ±, stok akhir, referensi transaksi, waktu — terbaru dulu,
/// infinite scroll (pola sama dengan Riwayat Transaksi Milestone 3).
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
      appBar: AppBar(title: Text('Riwayat Stok — ${widget.product.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdjustment,
        icon: const Icon(Icons.tune),
        label: const Text('Sesuaikan Stok'),
      ),
      body: stateAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: AppSizes.spaceXl * 2),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSizes.spaceMd),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return StockMovementTile(
                movement: state.items[index],
                unit: widget.product.unit,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Text('Gagal memuat riwayat stok: $error', textAlign: TextAlign.center),
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
            const Icon(Icons.swap_vert, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSizes.spaceMd),
            Text('Belum ada pergerakan stok', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              'Pergerakan stok (penjualan, void, penyesuaian manual) akan muncul di sini.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
