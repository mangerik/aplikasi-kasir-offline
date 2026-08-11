import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/product.dart';
import '../providers/stock_providers.dart';
import 'stock_adjustment_screen.dart';

/// Layar daftar "Stok Menipis" (plan.md Milestone 4 poin 3): produk aktif
/// dengan `stock <= threshold` (per produk, fallback default global dari
/// Pengaturan), urut stok paling sedikit dulu. Tap produk -> langsung buka
/// layar penyesuaian stok untuk mengisi ulang.
class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(lowStockListProvider);
    final lowStockThreshold =
        ref.watch(lowStockDefaultThresholdProvider).value ?? Product.defaultLowStockThreshold;

    return Scaffold(
      appBar: AppBar(title: const Text('Stok Menipis')),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return _LowStockTile(
                product: product,
                defaultThreshold: lowStockThreshold,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: product)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Text('Gagal memuat daftar stok menipis: $error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.product, required this.onTap, required this.defaultThreshold});

  final Product product;
  final VoidCallback onTap;
  final double defaultThreshold;

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
        child: Icon(Icons.warning_amber_rounded),
      ),
      title: Text(product.name, style: theme.textTheme.titleMedium),
      subtitle: Text(
        'Stok: ${_formatNum(product.stock)} ${product.unit} '
        '(batas: ${_formatNum(product.lowStockThreshold ?? defaultThreshold)} ${product.unit})',
      ),
      trailing: Text(CurrencyFormatter.format(product.sellPrice)),
    );
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
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
            const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
            const SizedBox(height: AppSizes.spaceMd),
            Text('Semua stok aman', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              'Tidak ada produk dengan stok menipis saat ini.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
