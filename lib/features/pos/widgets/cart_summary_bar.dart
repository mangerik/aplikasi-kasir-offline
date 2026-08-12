import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/cart_provider.dart';
import 'cart_panel.dart';

/// Bar keranjang mengambang di bawah layar Kasir HP portrait — tap membuka
/// sheet keranjang penuh (architecture.md §5.1, plan.md Milestone 2 poin 2).
///
/// Desain (fondasi §4.3 & §7.3): kartu mengambang (`AppDecorations.floating`)
/// dengan total belanja sebagai elemen terbesar (`AppMoneySize.lg`) dan CTA
/// "Bayar" di kanan pada zona jempol, diberi `AppShadows.primaryGlow` supaya
/// tertarik keluar dari halaman.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key});

  static void openCartSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: CartPanel(onRequestClose: () => Navigator.of(sheetContext).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final isEmpty = cart.isEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.spaceMs,
          AppSizes.spaceSm,
          AppSizes.spaceMs,
          AppSizes.spaceSm,
        ),
        child: Container(
          decoration: AppDecorations.floating(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => openCartSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceMs,
                  vertical: AppSizes.spaceMs,
                ),
                child: Row(
                  children: [
                    AppIconBadge(
                      icon: Icons.shopping_basket_rounded,
                      tone: AppTone.primary,
                      filled: !isEmpty,
                    ),
                    const SizedBox(width: AppSizes.spaceMs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEmpty ? 'Keranjang kosong' : '${cart.lineCount} item',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSizes.spaceXs),
                          // Total tidak boleh membungkus ke baris kedua —
                          // nominal besar (mis. Rp1.250.000) dikecilkan
                          // proporsional, bukan dipotong.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AppMoneyText(
                              CurrencyFormatter.format(cart.total),
                              size: AppMoneySize.lg,
                              color: isEmpty ? AppColors.inkTertiary : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceMs),
                    _PayButton(
                      enabled: !isEmpty,
                      onPressed: () => openCartSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: AppSizes.buttonHeight,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.point_of_sale_rounded, size: AppSizes.iconSm),
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
