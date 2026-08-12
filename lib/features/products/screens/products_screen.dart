import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/product.dart';
import '../../inventory/providers/stock_providers.dart';
import '../../inventory/screens/low_stock_screen.dart';
import '../providers/category_providers.dart';
import '../providers/product_providers.dart';
import '../widgets/category_manage_dialog.dart';
import '../widgets/product_list_tile.dart';

/// Layar daftar produk — pencarian real-time (debounce), filter kategori
/// (chips), indikator stok menipis, harga format Rupiah (plan.md
/// Milestone 1).
///
/// Struktur visual (design language "Kertas & Daun"):
/// kolom pencarian → chip kategori → banner stok menipis (kalau ada) →
/// [SectionHeader] dengan jumlah hasil → daftar [ProductListTile] berupa
/// kartu terpisah, bukan baris berpembatas.
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

  void _clearFilter() {
    _searchController.clear();
    ref.read(productFilterProvider.notifier).setQuery('');
    ref.read(productFilterProvider.notifier).setCategory(null);
    setState(() {});
  }

  void _openLowStock() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LowStockScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);
    final filter = ref.watch(productFilterProvider);
    final lowStockCount = ref.watch(lowStockCountProvider).value ?? 0;
    final lowStockThreshold =
        ref.watch(lowStockDefaultThresholdProvider).value ??
        Product.defaultLowStockThreshold;

    final categories = categoriesAsync.value ?? const <Category>[];
    final hasFilter = filter.query.isNotEmpty || filter.categoryId != null;
    final products = productsAsync.value;

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
            onPressed: _openLowStock,
          ),
          IconButton(
            tooltip: 'Kelola kategori',
            icon: const Icon(Icons.sell_outlined),
            onPressed: () => CategoryManageDialog.show(context),
          ),
          const SizedBox(width: AppSizes.spaceXs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${AppRoutes.products}/tambah'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceSm,
              AppSizes.screenPadding,
              AppSizes.spaceMs,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                ref.read(productFilterProvider.notifier).setQuery(value);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Cari nama atau barcode…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(productFilterProvider.notifier).setQuery('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          if (categories.isNotEmpty)
            _CategoryChips(
              categories: categories,
              selectedId: filter.categoryId,
              onSelect: (id) =>
                  ref.read(productFilterProvider.notifier).setCategory(id),
            ),
          if (lowStockCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.spaceMs,
                AppSizes.screenPadding,
                0,
              ),
              child: AppBanner(
                tone: AppTone.warning,
                icon: Icons.warning_amber_rounded,
                message: lowStockCount == 1
                    ? '1 produk stoknya menipis dan perlu diisi ulang.'
                    : '$lowStockCount produk stoknya menipis dan perlu diisi ulang.',
                actionLabel: 'Lihat daftarnya',
                onAction: _openLowStock,
              ),
            ),
          if (products != null && products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.spaceMs,
                AppSizes.screenPadding,
                0,
              ),
              child: SectionHeader(
                title: _headerTitle(filter, categories),
                padding: const EdgeInsets.only(bottom: AppSizes.spaceSm),
                trailing: AppPill(
                  label: products.length == 1
                      ? '1 produk'
                      : '${products.length} produk',
                  dense: true,
                ),
              ),
            ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return _ProductsEmptyState(
                    hasFilter: hasFilter,
                    onClearFilter: _clearFilter,
                    onAdd: () => context.push('${AppRoutes.products}/tambah'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    AppSizes.spaceXs,
                    AppSizes.screenPadding,
                    AppSizes.bottomSafePadding,
                  ),
                  itemCount: products.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.spaceSm),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductListTile(
                      product: product,
                      categoryName: _categoryName(
                        categories,
                        product.categoryId,
                      ),
                      onTap: () => context.push(
                        '${AppRoutes.products}/${product.id}/ubah',
                      ),
                      lowStockThreshold: lowStockThreshold,
                    );
                  },
                );
              },
              loading: () => const AppLoadingView(message: 'Memuat produk…'),
              error: (error, stack) => AppErrorView(
                title: 'Gagal memuat produk',
                message: AppErrorMessage.from(error),
                onRetry: () => ref.invalidate(productListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _headerTitle(ProductFilter filter, List<Category> categories) {
    if (filter.query.isNotEmpty) return 'Hasil pencarian';
    final name = _categoryName(categories, filter.categoryId);
    return name ?? 'Semua produk';
  }

  String? _categoryName(List<Category> categories, int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return null;
  }
}

/// Baris chip filter kategori (§7.3: `ChoiceChip` dalam list horizontal,
/// tinggi >= 40 supaya tetap mudah ditekan sambil berdiri).
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
    return SizedBox(
      height: AppSizes.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.screenPadding,
        ),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.spaceSm),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : categories[index - 1];
          final selected = isAll
              ? selectedId == null
              : selectedId == category!.id;
          return Center(
            child: ChoiceChip(
              label: Text(isAll ? 'Semua' : category!.name),
              selected: selected,
              avatar: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: AppSizes.iconSm,
                      color: context.palette.primary,
                    )
                  : null,
              onSelected: (_) => onSelect(isAll ? null : category!.id),
            ),
          );
        },
      ),
    );
  }
}

/// Layar kosong daftar produk — selalu mengarahkan (§1 prinsip 5):
/// beda pesan & beda aksi untuk "belum punya produk" vs "filter tidak
/// menemukan apa-apa".
class _ProductsEmptyState extends StatelessWidget {
  const _ProductsEmptyState({
    required this.hasFilter,
    required this.onClearFilter,
    required this.onAdd,
  });

  final bool hasFilter;
  final VoidCallback onClearFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (hasFilter) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        tone: AppTone.neutral,
        title: 'Produk tidak ditemukan',
        message:
            'Tidak ada barang yang cocok dengan pencarian atau kategori ini. '
            'Coba kata kunci lain, atau tampilkan semua produk.',
        actionLabel: 'Tampilkan Semua',
        onAction: onClearFilter,
      );
    }
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Belum ada produk',
      message:
          'Daftarkan barang jualanmu dulu — nama dan harganya langsung bisa '
          'dipakai di layar Kasir.',
      actionLabel: 'Tambah Produk',
      onAction: onAdd,
    );
  }
}
