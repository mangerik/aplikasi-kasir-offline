import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/sale_result.dart';
import '../providers/cart_provider.dart';
import '../providers/sale_providers.dart';

/// Jenis non-tunai yang bisa dipilih kasir (plan.md Milestone 3 poin 1:
/// "dicatat jenisnya, mis. QRIS/transfer — tanpa integrasi"). Disimpan ke
/// `sales.note` (tidak ada kolom terpisah di skema, lihat
/// docs/laporan-m3.md §3).
const List<String> _noncashTypes = ['QRIS', 'Transfer Bank', 'Kartu', 'Lainnya'];

/// Sheet pembayaran (plan.md Milestone 2 poin 5 & Milestone 3 poin 1):
/// pilih metode Tunai/Non-tunai/Hutang, lalu form sesuai metode:
/// - **Tunai:** input uang diterima, pecahan cepat, kembalian otomatis.
/// - **Non-tunai:** pilih jenis (QRIS/Transfer/Kartu/Lainnya) — TANPA
///   integrasi, hanya dicatat.
/// - **Hutang:** nama pelanggan WAJIB diisi, status tersimpan
///   `debt_unpaid`.
///
/// Mengembalikan `SaleResult` lewat `Navigator.pop` bila pembayaran
/// berhasil disimpan, atau `null` bila dibatalkan.
class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  String _paymentMethod = 'cash';
  String _noncashType = _noncashTypes.first;

  final _paidController = TextEditingController();
  final _noncashOtherController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _noteController = TextEditingController();

  bool _saving = false;
  bool _customerNameTouched = false;
  String? _errorMessage;

  @override
  void dispose() {
    _paidController.dispose();
    _noncashOtherController.dispose();
    _customerNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _paidAmount => CurrencyFormatter.parse(_paidController.text);

  void _addQuickAmount(int amount) {
    setState(() => _paidController.text = (_paidAmount + amount).toString());
  }

  void _setExact(int total) {
    setState(() => _paidController.text = total.toString());
  }

  void _selectMethod(String method) {
    setState(() {
      _paymentMethod = method;
      _errorMessage = null;
    });
  }

  bool _isFormValid(int total) {
    switch (_paymentMethod) {
      case 'cash':
        return _paidAmount >= total;
      case 'debt':
        return _customerNameController.text.trim().isNotEmpty;
      case 'noncash':
      default:
        return true;
    }
  }

  Future<void> _confirm(int total) async {
    if (_paymentMethod == 'debt' && _customerNameController.text.trim().isEmpty) {
      setState(() => _customerNameTouched = true);
      return;
    }
    if (!_isFormValid(total)) return;

    final cart = ref.read(cartProvider);
    int paidAmount;
    String? customerName;
    String? note;
    switch (_paymentMethod) {
      case 'cash':
        paidAmount = _paidAmount;
      case 'debt':
        paidAmount = 0;
        customerName = _customerNameController.text.trim();
        note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
      case 'noncash':
      default:
        paidAmount = total;
        note = _noncashType == 'Lainnya'
            ? (_noncashOtherController.text.trim().isEmpty
                  ? 'Lainnya'
                  : 'Lainnya: ${_noncashOtherController.text.trim()}')
            : _noncashType;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final usecase = ref.read(saveSaleUsecaseProvider);
      final SaleResult result = await usecase(
        items: cart.items,
        transactionDiscount: cart.transactionDiscount,
        paymentMethod: _paymentMethod,
        paidAmount: paidAmount,
        customerName: customerName,
        note: note,
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
    final theme = Theme.of(context);
    final isEnough = _isFormValid(total);

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
                Text('Pembayaran', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSizes.spaceMd),
                _buildMethodSelector(),
                const SizedBox(height: AppSizes.spaceMd),
                _SummaryRow(label: 'Total belanja', value: CurrencyFormatter.format(total)),
                const SizedBox(height: AppSizes.spaceMd),
                switch (_paymentMethod) {
                  'cash' => _buildCashForm(total),
                  'noncash' => _buildNoncashForm(),
                  'debt' => _buildDebtForm(),
                  _ => const SizedBox.shrink(),
                },
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

  Widget _buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _MethodButton(
            label: 'Tunai',
            icon: Icons.payments_outlined,
            value: 'cash',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSm),
        Expanded(
          child: _MethodButton(
            label: 'Non-tunai',
            icon: Icons.qr_code_outlined,
            value: 'noncash',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSm),
        Expanded(
          child: _MethodButton(
            label: 'Hutang',
            icon: Icons.receipt_long_outlined,
            value: 'debt',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
      ],
    );
  }

  Widget _buildCashForm(int total) {
    final paid = _paidAmount;
    final change = paid - total;
    final isEnough = paid >= total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  Widget _buildNoncashForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jenis pembayaran', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSizes.spaceSm),
        Wrap(
          spacing: AppSizes.spaceSm,
          runSpacing: AppSizes.spaceSm,
          children: [
            for (final type in _noncashTypes)
              ChoiceChip(
                label: Text(type),
                selected: _noncashType == type,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onSelected: (_) => setState(() => _noncashType = type),
              ),
          ],
        ),
        if (_noncashType == 'Lainnya') ...[
          const SizedBox(height: AppSizes.spaceMd),
          TextField(
            controller: _noncashOtherController,
            decoration: const InputDecoration(labelText: 'Sebutkan jenisnya'),
          ),
        ],
        const SizedBox(height: AppSizes.spaceSm),
        Text(
          'Pembayaran non-tunai HANYA dicatat jenisnya — tidak ada '
          'integrasi/pengecekan otomatis ke penyedia QRIS/bank.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDebtForm() {
    final showError = _customerNameTouched && _customerNameController.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customerNameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nama pelanggan *',
            errorText: showError ? 'Nama pelanggan wajib diisi' : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        Text(
          'Transaksi ini tersimpan sebagai HUTANG (belum lunas) — bisa '
          'ditandai lunas nanti dari layar Riwayat.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    if (isSelected) {
      return FilledButton.icon(
        onPressed: () => onSelect(value),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => onSelect(value),
      icon: Icon(icon, size: 18),
      label: Text(label),
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
