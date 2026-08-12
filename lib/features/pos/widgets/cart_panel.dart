import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
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
///
/// Desain (docs/ui-redesign-foundation.md §7.3): daftar item berupa kartu,
/// ringkasan nominal memakai `AppKeyValueRow` dengan baris Total
/// `emphasized`, dan aksi utama (Bayar) di bar bawah setinggi
/// `AppSizes.buttonHeightLarge` dengan `AppShadows.primaryGlow`.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, this.onRequestClose});

  /// Dipanggil setelah aksi yang "menutup" alur (hold berhasil, atau
  /// pembayaran berhasil) — dipakai untuk menutup sheet keranjang di HP.
  /// `null` bila panel ini dipakai inline (tablet), tidak perlu ditutup.
  final VoidCallback? onRequestClose;

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kosongkan Keranjang?'),
        content: const Text('Semua item di keranjang akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onDark,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tahan Transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keranjang diparkir dulu supaya kamu bisa melayani pembeli '
              'lain. Beri label agar mudah dikenali.',
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            TextField(
              controller: labelController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Label (opsional)',
                hintText: 'mis. nama pembeli',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
    final isEmpty = cart.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.spaceMs,
            AppSizes.spaceSm,
            0,
          ),
          child: SectionHeader(
            title: 'Keranjang',
            subtitle: isEmpty ? 'Belum ada item' : '${cart.lineCount} item',
            actionLabel: isEmpty ? null : 'Kosongkan',
            onAction: isEmpty ? null : () => _confirmClear(context, ref),
          ),
        ),
        Expanded(
          child: isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_basket_outlined,
                  title: 'Keranjang masih kosong',
                  message: 'Tap produk di grid atau scan barcode untuk mulai '
                      'transaksi. Barang tak terdaftar bisa dicatat lewat '
                      'item bebas.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    AppSizes.spaceXs,
                    AppSizes.screenPadding,
                    AppSizes.spaceMd,
                  ),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spaceSm),
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
        _CheckoutBar(
          subtotal: cart.subtotal,
          transactionDiscount: cart.transactionDiscount,
          total: cart.total,
          enabled: !isEmpty,
          onEditDiscount: () => _editTransactionDiscount(context, ref, cart.subtotal),
          onHold: () => _hold(context, ref),
          onPay: () => _pay(context, ref),
        ),
      ],
    );
  }
}

/// Bar bawah keranjang: ringkasan nominal + aksi Tahan/Bayar.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.subtotal,
    required this.transactionDiscount,
    required this.total,
    required this.enabled,
    required this.onEditDiscount,
    required this.onHold,
    required this.onPay,
  });

  final int subtotal;
  final int transactionDiscount;
  final int total;
  final bool enabled;
  final VoidCallback onEditDiscount;
  final VoidCallback onHold;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = transactionDiscount > 0;

    return Container(
      decoration: AppDecorations.floating(radius: AppSizes.radius2xl),
      margin: const EdgeInsets.fromLTRB(
        AppSizes.spaceMs,
        0,
        AppSizes.spaceMs,
        AppSizes.spaceMs,
      ),
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCard(
              color: AppColors.surfaceAlt,
              radius: AppSizes.radiusMd,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceMd,
                vertical: AppSizes.spaceSm,
              ),
              child: Column(
                children: [
                  AppKeyValueRow(
                    label: 'Subtotal',
                    value: CurrencyFormatter.format(subtotal),
                  ),
                  InkWell(
                    onTap: enabled ? onEditDiscount : null,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: AppKeyValueRow(
                      label: 'Diskon transaksi',
                      icon: Icons.local_offer_outlined,
                      value: hasDiscount
                          ? '-${CurrencyFormatter.format(transactionDiscount)}'
                          : 'Atur',
                      valueColor: hasDiscount
                          ? AppColors.dangerText
                          : AppColors.primary,
                    ),
                  ),
                  const Divider(),
                  AppKeyValueRow(
                    label: 'Total',
                    value: CurrencyFormatter.format(total),
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            Row(
              children: [
                // Tanpa ikon & flex 2:3 — di HP sempit label "Tahan"
                // beserta ikonnya tidak muat berdampingan dengan CTA Bayar
                // yang sengaja dibuat dominan.
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: AppSizes.buttonHeightLarge,
                    child: OutlinedButton(
                      onPressed: enabled ? onHold : null,
                      child: const Text('Tahan'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.spaceSm),
                Expanded(
                  flex: 3,
                  child: _PayCta(enabled: enabled, onPressed: onPay),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PayCta extends StatelessWidget {
  const _PayCta({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: AppSizes.buttonHeightLarge,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.point_of_sale_rounded, size: AppSizes.iconMd),
        label: const Text('Bayar'),
      ),
    );
    if (!enabled) return button;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: AppShadows.primaryGlow,
      ),
      child: button,
    );
  }
}
