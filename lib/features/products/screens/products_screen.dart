import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/category.dart';
import '../../inventory/providers/stock_providers.dart';
import '../../inventory/screens/low_stock_screen.dart';
import '../providers/category_providers.dart';
import '../providers/product_providers.dart';
import '../widgets/category_manage_dialog.dart';
import '../widgets/product_list_tile.dart';

/// Layar daftar produk — pencarian real-time (debounce), filter kategori
/// (chips), indikator stok menipis, harga format Rupiah (plan.md
/// Milestone 1).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);
    final filter = ref.watch(productFilterProvider);
    final lowStockCount = ref.watch(lowStockCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [
          IconButton(
            tooltip: 'Stok menipis',
            icon: Badge.count(
              count: lowStockCount,
              isLabelVisible: lowStockCount > 0,
              child: const Icon(Icons.warning_amber_rounded),
            ),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LowStockScreen())),
          ),
          IconButton(
            tooltip: 'Kelola kategori',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => CategoryManageDialog.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.products}/tambah'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spaceMd,
              AppSizes.spaceSm,
              AppSizes.spaceMd,
              AppSizes.spaceXs,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(productFilterProvider.notifier).setQuery(value);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Cari nama atau barcode produk...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(productFilterProvider.notifier).setQuery('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) => _CategoryChips(
              categories: categories,
              selectedId: filter.categoryId,
              onSelect: (id) => ref.read(productFilterProvider.notifier).setCategory(id),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSizes.spaceXs),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final categories = categoriesAsync.value ?? const <Category>[];
                if (products.isEmpty) {
                  final hasFilter = filter.query.isNotEmpty || filter.categoryId != null;
                  return _EmptyState(hasFilter: hasFilter);
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final categoryName = _categoryName(categories, product.categoryId);
                    return ProductListTile(
                      product: product,
                      categoryName: categoryName,
                      onTap: () => context.push('${AppRoutes.products}/${product.id}/ubah'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Gagal memuat produk: $error')),
            ),
          ),
        ],
      ),
    );
  }

  String? _categoryName(List<Category> categories, int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return null;
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

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
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              hasFilter ? 'Produk tidak ditemukan' : 'Belum ada produk',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              hasFilter
                  ? 'Coba ubah kata kunci pencarian atau filter kategori.'
                  : 'Tambahkan produk pertama lewat tombol "Tambah Produk" di bawah.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
