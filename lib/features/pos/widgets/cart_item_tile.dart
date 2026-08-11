import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/cart_item.dart';
import 'discount_dialog.dart';

/// Satu baris item di dalam keranjang: nama, harga x qty, diskon (bila
/// ada), stepper qty (+/-, tap angka untuk isi manual), dan tombol hapus.
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
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Qty (${item.unit})'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSm, horizontal: AppSizes.spaceMd),
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
                    Text(item.name, style: theme.textTheme.titleMedium),
                    Text(
                      '${CurrencyFormatter.format(item.sellPrice)} / ${item.unit}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (item.discount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Diskon: -${CurrencyFormatter.format(item.discount)}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.warning),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus dari keranjang',
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: onRemove,
              ),
            ],
          ),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Kurangi qty',
                icon: const Icon(Icons.remove),
                onPressed: onDecrement,
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _editQty(context),
                  child: Center(
                    child: Text(
                      '${_formatQty(item.qty)} ${item.unit}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Tambah qty',
                icon: const Icon(Icons.add),
                onPressed: onIncrement,
              ),
              // Icon-only (bukan TextButton.icon berlabel "Diskon") supaya
              // baris ini tidak overflow di layar HP sempit (<360dp) —
              // masih >= 48dp (IconButton default) & tetap punya tooltip
              // teks Indonesia untuk aksesibilitas (plan.md Milestone 6
              // poin 2: review ukuran sentuh di HP kecil).
              IconButton(
                tooltip: 'Beri diskon item ini',
                onPressed: () => _editDiscount(context),
                icon: const Icon(Icons.percent),
              ),
              Expanded(
                child: Text(
                  CurrencyFormatter.format(item.lineTotal),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
