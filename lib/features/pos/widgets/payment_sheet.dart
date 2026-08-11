import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/sale_result.dart';
import '../providers/cart_provider.dart';
import '../providers/sale_providers.dart';

/// Sheet pembayaran tunai (plan.md Milestone 2 poin 5): input uang
/// diterima, tombol pecahan cepat (10rb/20rb/50rb/100rb/uang pas),
/// kembalian otomatis, validasi uang cukup sebelum tombol aktif.
///
/// Mengembalikan `SaleResult` lewat `Navigator.pop` bila pembayaran
/// berhasil disimpan, atau `null` bila dibatalkan.
class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _paidController = TextEditingController();
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  int get _paidAmount => CurrencyFormatter.parse(_paidController.text);

  void _addQuickAmount(int amount) {
    setState(() => _paidController.text = (_paidAmount + amount).toString());
  }

  void _setExact(int total) {
    setState(() => _paidController.text = total.toString());
  }

  Future<void> _confirm(int total) async {
    final cart = ref.read(cartProvider);
    final paid = _paidAmount;
    if (paid < total) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final usecase = ref.read(saveSaleUsecaseProvider);
      final SaleResult result = await usecase(
        items: cart.items,
        transactionDiscount: cart.transactionDiscount,
        paymentMethod: 'cash',
        paidAmount: paid,
      );
      ref.read(cartProvider.notifier).clear();
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = cart.total;
    final paid = _paidAmount;
    final change = paid - total;
    final isEnough = paid >= total;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSizes.spaceMd),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Pembayaran Tunai', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSizes.spaceMd),
                _SummaryRow(label: 'Total belanja', value: CurrencyFormatter.format(total)),
                const SizedBox(height: AppSizes.spaceMd),
                TextField(
                  controller: _paidController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Uang diterima',
                    prefixText: 'Rp ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSizes.spaceSm),
                Wrap(
                  spacing: AppSizes.spaceSm,
                  runSpacing: AppSizes.spaceSm,
                  children: [
                    _QuickButton(label: 'Rp10.000', onTap: () => _addQuickAmount(10000)),
                    _QuickButton(label: 'Rp20.000', onTap: () => _addQuickAmount(20000)),
                    _QuickButton(label: 'Rp50.000', onTap: () => _addQuickAmount(50000)),
                    _QuickButton(label: 'Rp100.000', onTap: () => _addQuickAmount(100000)),
                    _QuickButton(label: 'Uang Pas', onTap: () => _setExact(total)),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceMd),
                _SummaryRow(
                  label: 'Kembalian',
                  value: isEnough
                      ? CurrencyFormatter.format(change)
                      : 'Kurang ${CurrencyFormatter.format(-change)}',
                  color: isEnough ? AppColors.success : AppColors.danger,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSizes.spaceSm),
                  Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: AppSizes.spaceLg),
                FilledButton(
                  onPressed: (_saving || !isEnough) ? null : () => _confirm(total),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Selesaikan Pembayaran'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }
}
