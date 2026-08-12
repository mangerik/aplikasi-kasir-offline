import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/cart_item.dart';
import 'discount_dialog.dart';

/// Satu baris item di dalam keranjang: nama, harga satuan, diskon (bila
/// ada), stepper qty (+/-, tap angka untuk isi manual), tombol diskon, dan
/// tombol hapus.
///
/// Desain (docs/ui-redesign-foundation.md): tiap item adalah `AppCard`
/// sendiri — bukan baris list bergaris — supaya stepper qty punya ruang
/// sentuh 44dp yang tidak bertabrakan dengan tombol hapus saat kasir
/// buru-buru. Nominal baris memakai `AppMoneyText` agar digit sejajar antar
/// item.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSetQty,
    required this.onSetDiscount,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<double> onSetQty;
  final ValueChanged<int> onSetDiscount;
  final VoidCallback onRemove;

  Future<void> _editQty(BuildContext context) async {
    final controller = TextEditingController(text: _formatQty(item.qty));
    final newQty = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Qty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(dialogContext).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSizes.spaceMd),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.moneyLarge,
              decoration: InputDecoration(
                labelText: 'Qty (${item.unit})',
                suffixText: item.unit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newQty != null && newQty > 0) onSetQty(newQty);
  }

  Future<void> _editDiscount(BuildContext context) async {
    final result = await DiscountDialog.show(
      context,
      title: 'Diskon "${item.name}"',
      baseAmount: item.grossTotal,
      initialDiscount: item.discount,
    );
    if (result != null) onSetDiscount(result);
  }

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = item.discount > 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '${CurrencyFormatter.format(item.sellPrice)} / ${item.unit}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppMoneyText(CurrencyFormatter.format(item.lineTotal)),
                  if (hasDiscount) ...[
                    const SizedBox(height: AppSizes.spaceXs),
                    AppMoneyText(
                      CurrencyFormatter.format(item.grossTotal),
                      size: AppMoneySize.sm,
                      strikethrough: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (hasDiscount) ...[
            const SizedBox(height: AppSizes.spaceSm),
            AppPill(
              label: 'Diskon -${CurrencyFormatter.format(item.discount)}',
              tone: AppTone.accent,
              icon: Icons.local_offer_outlined,
              dense: true,
            ),
          ],
          const SizedBox(height: AppSizes.spaceMs),
          Row(
            children: [
              _QtyStepper(
                qtyLabel: _formatQty(item.qty),
                unit: item.unit,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
                onEdit: () => _editQty(context),
              ),
              const Spacer(),
              // Icon-only (bukan tombol berlabel) supaya baris ini tidak
              // overflow di HP sempit (<360dp) — tetap >= 48dp dan punya
              // tooltip berbahasa Indonesia untuk aksesibilitas (plan.md
              // Milestone 6 poin 2).
              IconButton(
                tooltip: 'Beri diskon item ini',
                onPressed: () => _editDiscount(context),
                icon: Icon(
                  Icons.local_offer_outlined,
                  color: hasDiscount ? AppColors.accentText : AppColors.inkSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Hapus dari keranjang',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stepper qty: −  [qty]  + dalam satu sub-panel `surfaceAlt`.
/// Tap angka membuka input manual (berguna untuk satuan kg/liter).
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qtyLabel,
    required this.unit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
  });

  final String qtyLabel;
  final String unit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceAlt,
      borderColor: AppColors.border,
      radius: AppSizes.radiusMd,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: _height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              tooltip: 'Kurangi qty',
              onTap: onDecrement,
            ),
            InkWell(
              onTap: onEdit,
              child: Container(
                constraints: const BoxConstraints(minWidth: 56),
                height: _height,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceXs),
                child: Text(
                  '$qtyLabel $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.numeric,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              tooltip: 'Tambah qty',
              onTap: onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _QtyStepper._height,
          height: _QtyStepper._height,
          child: Icon(icon, size: AppSizes.iconMd, color: AppColors.primary),
        ),
      ),
    );
  }
}
