import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/sale_result.dart';
import '../screens/checkout_success_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/held_cart_providers.dart';
import 'cart_item_tile.dart';
import 'discount_dialog.dart';
import 'payment_sheet.dart';

/// Isi keranjang lengkap — dipakai baik di dalam sheet keranjang (HP
/// portrait, lihat `cart_summary_bar.dart`) maupun panel kanan tetap
/// (tablet, lihat `pos_screen.dart`), sesuai architecture.md §5.1.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, this.onRequestClose});

  /// Dipanggil setelah aksi yang "menutup" alur (hold berhasil, atau
  /// pembayaran berhasil) — dipakai untuk menutup sheet keranjang di HP.
  /// `null` bila panel ini dipakai inline (tablet), tidak perlu ditutup.
  final VoidCallback? onRequestClose;

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kosongkan Keranjang?'),
        content: const Text('Semua item di keranjang akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      ref.read(cartProvider.notifier).clear();
    }
  }

  Future<void> _hold(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final labelController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tahan Transaksi'),
        content: TextField(
          controller: labelController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label (opsional)',
            hintText: 'mis. nama pembeli',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tahan'),
          ),
        ],
      ),
    );
    final label = labelController.text.trim();
    labelController.dispose();
    if (confirmed != true) return;

    await ref
        .read(heldCartRepoProvider)
        .hold(
          label: label.isEmpty ? null : label,
          items: cart.items,
          transactionDiscount: cart.transactionDiscount,
        );
    ref.read(cartProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaksi ditahan.')));
      onRequestClose?.call();
    }
  }

  Future<void> _editTransactionDiscount(BuildContext context, WidgetRef ref, int subtotal) async {
    final cart = ref.read(cartProvider);
    final result = await DiscountDialog.show(
      context,
      title: 'Diskon Total Transaksi',
      baseAmount: subtotal,
      initialDiscount: cart.transactionDiscount,
    );
    if (result != null) {
      ref.read(cartProvider.notifier).setTransactionDiscount(result);
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final result = await showModalBottomSheet<SaleResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PaymentSheet(),
    );
    if (!context.mounted) return;
    if (result != null) {
      onRequestClose?.call();
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => CheckoutSuccessScreen(sale: result)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.spaceMd,
            AppSizes.spaceSm,
            AppSizes.spaceSm,
            AppSizes.spaceSm,
          ),
          child: Row(
            children: [
              Text('Keranjang', style: theme.textTheme.titleLarge),
              const Spacer(),
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmClear(context, ref),
                  child: const Text('Kosongkan'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: cart.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return CartItemTile(
                      item: item,
                      onIncrement: () => notifier.incrementQty(item.key),
                      onDecrement: () => notifier.decrementQty(item.key),
                      onSetQty: (qty) => notifier.setQty(item.key, qty),
                      onSetDiscount: (discount) => notifier.setItemDiscount(item.key, discount),
                      onRemove: () => notifier.removeItem(item.key),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: cart.isEmpty
                    ? null
                    : () => _editTransactionDiscount(context, ref, cart.subtotal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: theme.textTheme.bodyLarge),
                      Text(CurrencyFormatter.format(cart.subtotal)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: cart.isEmpty
                    ? null
                    : () => _editTransactionDiscount(context, ref, cart.subtotal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('Diskon Transaksi', style: theme.textTheme.bodyLarge),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                      Text(
                        cart.transactionDiscount > 0
                            ? '-${CurrencyFormatter.format(cart.transactionDiscount)}'
                            : CurrencyFormatter.format(0),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: theme.textTheme.titleLarge),
                  Text(
                    CurrencyFormatter.format(cart.total),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cart.isEmpty ? null : () => _hold(context, ref),
                      child: const Text('Tahan'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: cart.isEmpty ? null : () => _pay(context, ref),
                      child: const Text('Bayar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    // `SingleChildScrollView` (bukan langsung `Column`) supaya tetap aman
    // saat panel keranjang mendapat tinggi terbatas (mis. panel tablet di
    // layar pendek) — konten men-scroll alih-alih overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSizes.spaceMd),
            Text(
              'Keranjang masih kosong',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              'Tap produk atau scan barcode untuk mulai transaksi.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
