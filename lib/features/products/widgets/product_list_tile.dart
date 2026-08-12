import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/product.dart';

/// Kartu satu produk di daftar Produk.
///
/// Susunan mengikuti resep §7.3 fondasi ("baris item di list"):
/// [AppIconBadge] sebagai leading, nama produk `titleMedium`, baris meta
/// (kategori + sisa stok bergaya angka), status stok sebagai [AppPill]
/// bernada [AppTone], dan harga jual sebagai [AppMoneyText] di kanan.
///
/// Prinsip §1 poin 1 dipatuhi: dua angka yang dicari pemilik warung —
/// **harga** dan **sisa stok** — tampil lebih tebal daripada labelnya.
class ProductListTile extends StatelessWidget {
  const ProductListTile({
    super.key,
    required this.product,
    required this.categoryName,
    required this.onTap,
    required this.lowStockThreshold,
  });

  final Product product;
  final String? categoryName;
  final VoidCallback onTap;

  /// Threshold default global (`settings.low_stock_default`) dipakai bila
  /// produk ini tidak punya threshold sendiri — lihat [Product.isLowStockWith].
  final double lowStockThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = product.stock <= 0;
    final isLow = !isOut && product.isLowStockWith(lowStockThreshold);
    final inactive = !product.isActive;

    // Nada stok: habis -> danger, menipis -> warning, aman -> netral.
    // Stok aman sengaja TIDAK diberi warna supaya warna hanya muncul saat
    // butuh tindakan (§2.2: hemat aksen, satu fokus per layar).
    final stockTone = isOut
        ? AppTone.danger
        : isLow
        ? AppTone.warning
        : AppTone.neutral;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconBadge(
            icon: inactive
                ? Icons.visibility_off_outlined
                : Icons.inventory_2_outlined,
            tone: inactive ? AppTone.neutral : AppTone.primary,
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: inactive ? AppColors.inkSecondary : AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.spaceXs),
                // Baris meta memakai Wrap: di layar sempit chip-nya turun ke
                // baris berikutnya, bukan meluber.
                Wrap(
                  spacing: AppSizes.spaceSm,
                  runSpacing: AppSizes.spaceXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${_formatStock(product.stock)} ${product.unit}',
                      style: AppTextStyles.numeric.copyWith(
                        fontSize: 13,
                        color: stockTone.colors.fg,
                      ),
                    ),
                    if (isOut || isLow)
                      AppPill(
                        label: isOut ? 'Stok habis' : 'Stok menipis',
                        tone: stockTone,
                        icon: isOut
                            ? Icons.remove_shopping_cart_outlined
                            : Icons.warning_amber_rounded,
                        dense: true,
                      ),
                    // Kategori hanya ditampilkan saat stok aman: kalau stok
                    // butuh tindakan, statusnya yang harus dibaca duluan —
                    // sekaligus menjaga baris meta tetap ringkas di HP kecil.
                    if (categoryName != null && !isOut && !isLow)
                      AppPill(label: _shortCategory(categoryName!), dense: true),
                    if (inactive) const AppPill(label: 'Nonaktif', dense: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spaceMs),
          AppMoneyText(
            CurrencyFormatter.format(product.sellPrice),
            color: inactive ? AppColors.inkSecondary : AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// Pill tidak bisa memendekkan teksnya sendiri, jadi nama kategori yang
  /// kepanjangan dipotong di sini supaya tidak mendorong baris meta melebihi
  /// lebar kartu di HP kecil.
  static String _shortCategory(String name) =>
      name.length <= 16 ? name : '${name.substring(0, 15)}…';

  String _formatStock(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
