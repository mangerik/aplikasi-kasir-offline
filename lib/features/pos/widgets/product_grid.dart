import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/product.dart';
import '../../inventory/providers/stock_providers.dart';
import '../../products/providers/category_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../products/widgets/barcode_scanner_page.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_product_providers.dart';
import 'free_item_dialog.dart';

/// Grid produk layar Kasir: pencarian, filter kategori, scan barcode, dan
/// item bebas (plan.md Milestone 2 poin 2 & 4). Hanya menampilkan produk
/// AKTIF (`posProductListProvider` selalu `onlyActive: true`).
class ProductGrid extends ConsumerStatefulWidget {
  const ProductGrid({super.key});

  @override
  ConsumerState<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<ProductGrid> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
    if (scanned == null || !mounted) return;

    final product = await ref.read(productRepoProvider).getByBarcode(scanned);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk dengan barcode "$scanned" tidak ditemukan.')),
      );
      return;
    }
    ref.read(cartProvider.notifier).addProduct(product);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} ditambahkan ke keranjang.')));
  }

  Future<void> _addFreeItem() async {
    final input = await FreeItemDialog.show(context);
    if (input == null) return;
    ref
        .read(cartProvider.notifier)
        .addFreeItem(name: input.name, price: input.price, qty: input.qty, unit: input.unit);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(posProductListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);
    final filter = ref.watch(posProductFilterProvider);
    final lowStockThreshold =
        ref.watch(lowStockDefaultThresholdProvider).value ?? Product.defaultLowStockThreshold;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spaceMd,
            AppSizes.spaceSm,
            AppSizes.spaceMd,
            AppSizes.spaceXs,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    ref.read(posProductFilterProvider.notifier).setQuery(value);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(posProductFilterProvider.notifier).setQuery('');
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              IconButton.filledTonal(
                tooltip: 'Scan barcode',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
              ),
              const SizedBox(width: AppSizes.spaceSm),
              IconButton.filledTonal(
                tooltip: 'Tambah item bebas',
                icon: const Icon(Icons.edit_note),
                onPressed: _addFreeItem,
              ),
            ],
          ),
        ),
        categoriesAsync.when(
          data: (categories) => _CategoryChips(
            categories: categories,
            selectedId: filter.categoryId,
            onSelect: (id) => ref.read(posProductFilterProvider.notifier).setCategory(id),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSizes.spaceXs),
        Expanded(
          child: productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                final hasFilter = filter.query.isNotEmpty || filter.categoryId != null;
                return _EmptyState(hasFilter: hasFilter);
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spaceMd,
                  0,
                  AppSizes.spaceMd,
                  AppSizes.spaceMd,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: AppSizes.spaceSm,
                  crossAxisSpacing: AppSizes.spaceSm,
                  childAspectRatio: 0.95,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(product: product, lowStockThreshold: lowStockThreshold);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Gagal memuat produk: ${AppErrorMessage.from(error)}')),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, required this.lowStockThreshold});

  final Product product;
  final double lowStockThreshold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartQty = ref.watch(
      cartProvider.select((cart) {
        final key = 'p_${product.id}';
        for (final item in cart.items) {
          if (item.key == key) return item.qty;
        }
        return 0.0;
      }),
    );
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(cartProvider.notifier).addProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceSm),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    CurrencyFormatter.format(product.sellPrice),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Stok ${_formatQty(product.stock)} ${product.unit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: product.isLowStockWith(lowStockThreshold)
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (cartQty > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Text(
                      _formatQty(cartQty),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.selectedId, required this.onSelect});

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMd),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('Semua'),
              selected: selectedId == null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onSelected: (_) => onSelect(null),
            ),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(category.name),
                selected: selectedId == category.id,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onSelected: (_) => onSelect(category.id),
              ),
            ),
        ],
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
            const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              hasFilter ? 'Produk tidak ditemukan' : 'Belum ada produk aktif',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              hasFilter
                  ? 'Coba ubah kata kunci pencarian atau filter kategori.'
                  : 'Tambahkan produk lewat tab Produk terlebih dahulu.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
