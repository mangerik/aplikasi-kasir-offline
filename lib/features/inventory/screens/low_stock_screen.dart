import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/product.dart';
import '../providers/stock_providers.dart';
import 'stock_adjustment_screen.dart';

/// Layar daftar "Stok Menipis" (plan.md Milestone 4 poin 3): produk aktif
/// dengan `stock <= threshold` (per produk, fallback default global dari
/// Pengaturan), urut stok paling sedikit dulu. Tap produk -> langsung buka
/// layar penyesuaian stok untuk mengisi ulang.
///
/// Layar ini dibaca sebagai **daftar belanja**: tiap kartu menunjukkan sisa
/// stok (angka besar), batas menipisnya, dan sebuah bar tipis yang bikin
/// "seberapa gawat" terbaca sekali lihat.
class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(lowStockListProvider);
    final lowStockThreshold =
        ref.watch(lowStockDefaultThresholdProvider).value ??
        Product.defaultLowStockThreshold;

    return Scaffold(
      appBar: AppBar(title: const Text('Stok Menipis')),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_outlined,
              tone: AppTone.success,
              title: 'Semua stok aman',
              message:
                  'Tidak ada barang yang perlu diisi ulang saat ini. '
                  'Kami akan mengingatkan begitu ada yang menipis.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceMs,
              AppSizes.screenPadding,
              AppSizes.spaceXl,
            ),
            itemCount: products.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spaceSm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spaceXs),
                  child: AppBanner(
                    tone: AppTone.warning,
                    icon: Icons.shopping_basket_outlined,
                    title: products.length == 1
                        ? '1 barang perlu diisi ulang'
                        : '${products.length} barang perlu diisi ulang',
                    message:
                        'Ketuk barangnya untuk mencatat stok masuk setelah belanja.',
                  ),
                );
              }
              final product = products[index - 1];
              return _LowStockCard(
                product: product,
                defaultThreshold: lowStockThreshold,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockAdjustmentScreen(product: product),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const AppLoadingView(message: 'Memeriksa stok…'),
        error: (error, stack) => AppErrorView(
          title: 'Gagal memuat stok menipis',
          message: AppErrorMessage.from(error),
          onRetry: () => ref.invalidate(lowStockListProvider),
        ),
      ),
    );
  }
}

/// Kartu satu produk yang stoknya menipis.
class _LowStockCard extends StatelessWidget {
  const _LowStockCard({
    required this.product,
    required this.onTap,
    required this.defaultThreshold,
  });

  final Product product;
  final VoidCallback onTap;
  final double defaultThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final threshold = product.lowStockThreshold ?? defaultThreshold;
    final isOut = product.stock <= 0;
    final tone = isOut ? AppTone.danger : AppTone.warning;
    final c = tone.colors;
    final ratio = threshold <= 0
        ? 0.0
        : (product.stock / threshold).clamp(0.0, 1.0).toDouble();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppIconBadge(
                icon: isOut
                    ? Icons.remove_shopping_cart_outlined
                    : Icons.warning_amber_rounded,
                tone: tone,
                size: AppIconBadgeSize.lg,
              ),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isOut
                                ? 'Habis'
                                : 'Sisa ${_formatNum(product.stock)} ${product.unit}',
                            style: AppTextStyles.numeric.copyWith(color: c.fg),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '  ·  batas ${_formatNum(threshold)} ${product.unit}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              AppMoneyText(
                CurrencyFormatter.format(product.sellPrice),
                size: AppMoneySize.sm,
                color: AppColors.inkSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMs),
          // Bar sisa stok terhadap batas — "seberapa gawat" tanpa perlu
          // membandingkan dua angka di kepala.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusXs),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: AppSizes.spaceXs + 2,
              color: c.fg,
              backgroundColor: c.bg,
            ),
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
