import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
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
///
/// Desain (docs/ui-redesign-foundation.md): tile produk dibuat untuk
/// **dipindai cepat** — monogram huruf awal sebagai jangkar visual, nama
/// dua baris, harga memakai `AppMoneyText` (tabular figures), dan status
/// stok sebagai `AppPill` yang hanya berwarna saat butuh perhatian. Produk
/// yang sudah masuk keranjang memakai `AppCard(selected: true)` sehingga
/// kasir tahu apa yang sudah ditap tanpa membuka keranjang.
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

  void _clearFilter() {
    _searchController.clear();
    ref.read(posProductFilterProvider.notifier).setQuery('');
    ref.read(posProductFilterProvider.notifier).setCategory(null);
    setState(() {});
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
            AppSizes.screenPadding,
            AppSizes.spaceMs,
            AppSizes.screenPadding,
            AppSizes.spaceMs,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    ref.read(posProductFilterProvider.notifier).setQuery(value);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.close_rounded),
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
              _ToolButton(
                icon: Icons.qr_code_scanner_rounded,
                tooltip: 'Scan barcode',
                onTap: _scanBarcode,
              ),
              const SizedBox(width: AppSizes.spaceSm),
              _ToolButton(
                icon: Icons.edit_note_rounded,
                tooltip: 'Tambah item bebas',
                onTap: _addFreeItem,
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
        Expanded(
          child: productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                final hasFilter = filter.query.isNotEmpty || filter.categoryId != null;
                if (hasFilter) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Produk tidak ditemukan',
                    message: 'Coba kata kunci lain atau kembalikan filter '
                        'kategori ke "Semua".',
                    actionLabel: 'Tampilkan Semua',
                    onAction: _clearFilter,
                  );
                }
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Belum ada produk aktif',
                  message: 'Tambahkan barang jualanmu lewat tab Produk. Untuk '
                      'sekarang, penjualan tetap bisa dicatat sebagai item bebas.',
                  actionLabel: 'Tambah Item Bebas',
                  onAction: _addFreeItem,
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.spaceSm,
                  AppSizes.screenPadding,
                  AppSizes.spaceMd,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisSpacing: AppSizes.spaceMs,
                  crossAxisSpacing: AppSizes.spaceMs,
                  childAspectRatio: 0.88,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(product: product, lowStockThreshold: lowStockThreshold);
                },
              );
            },
            loading: () => const AppLoadingView(),
            error: (error, stack) => AppErrorView(
              title: 'Gagal memuat produk',
              message: AppErrorMessage.from(error),
              onRetry: () => ref.invalidate(posProductListProvider),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tombol ikon persegi setinggi field pencarian (56dp) — scan barcode &
/// item bebas. Sengaja bernada brand lembut supaya terbaca sebagai "alat",
/// bukan aksi utama.
class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppCard(
        width: _size,
        padding: EdgeInsets.zero,
        radius: AppSizes.radiusMd,
        color: AppColors.primary50,
        borderColor: AppColors.primary100,
        onTap: onTap,
        child: SizedBox(
          height: _size,
          child: Center(
            child: Icon(icon, size: AppSizes.iconMd, color: AppColors.primary),
          ),
        ),
      ),
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
    final inCart = cartQty > 0;
    final isOutOfStock = product.stock <= 0;
    final isLowStock = product.isLowStockWith(lowStockThreshold);

    return AppCard(
      selected: inCart,
      onTap: () => ref.read(cartProvider.notifier).addProduct(product),
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Monogram(name: product.name, onSelectedCard: inCart),
              const Spacer(),
              if (inCart)
                AppPill(
                  label: '${_formatQty(cartQty)}x',
                  tone: AppTone.primary,
                  filled: true,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSm),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          AppMoneyText(
            CurrencyFormatter.format(product.sellPrice),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSizes.spaceXs + 2),
          if (isOutOfStock)
            const AppPill(label: 'Stok habis', tone: AppTone.danger, dense: true)
          else if (isLowStock)
            AppPill(
              label: 'Sisa ${_formatQty(product.stock)} ${product.unit}',
              tone: AppTone.warning,
              dense: true,
            )
          else
            Text(
              'Stok ${_formatQty(product.stock)} ${product.unit}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }
}

/// Huruf awal produk dalam kotak lembut — jangkar visual supaya mata kasir
/// punya titik pegangan saat memindai grid, tanpa bergantung pada foto
/// produk (aplikasi ini offline & datanya sering tanpa gambar).
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.onSelectedCard});

  final String name;

  /// Kartu terpilih sudah berlatar `primary50`; monogram dibalik jadi
  /// putih hangat supaya tetap terbaca.
  final bool onSelectedCard;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();

    return AppCard(
      width: _size,
      padding: EdgeInsets.zero,
      radius: AppSizes.radiusSm,
      color: onSelectedCard ? AppColors.surface : AppColors.primary50,
      borderColor: onSelectedCard ? AppColors.primary100 : AppColors.primary50,
      child: SizedBox(
        height: _size,
        child: Center(
          child: Text(
            initial,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
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
      height: AppSizes.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.spaceSm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChip(
              label: 'Semua',
              selected: selectedId == null,
              onSelected: () => onSelect(null),
            );
          }
          final category = categories[index - 1];
          return _CategoryChip(
            label: category.name,
            selected: selectedId == category.id,
            onSelected: () => onSelect(category.id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMs,
          vertical: AppSizes.spaceSm,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
