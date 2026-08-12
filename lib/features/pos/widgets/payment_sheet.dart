import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/sale_result.dart';
import '../providers/cart_provider.dart';
import '../providers/sale_providers.dart';

/// Jenis non-tunai yang bisa dipilih kasir (plan.md Milestone 3 poin 1:
/// "dicatat jenisnya, mis. QRIS/transfer — tanpa integrasi"). Disimpan ke
/// `sales.note` (tidak ada kolom terpisah di skema, lihat
/// docs/laporan-m3.md §3).
const List<String> _noncashTypes = ['QRIS', 'Transfer Bank', 'Kartu', 'Lainnya'];

/// Pecahan uang yang paling sering diterima warung — tombol tambah cepat.
const List<int> _quickAmounts = [10000, 20000, 50000, 100000];

/// Sheet pembayaran (plan.md Milestone 2 poin 5 & Milestone 3 poin 1):
/// pilih metode Tunai/Non-tunai/Hutang, lalu form sesuai metode:
/// - **Tunai:** input uang diterima, pecahan cepat, kembalian otomatis.
/// - **Non-tunai:** pilih jenis (QRIS/Transfer/Kartu/Lainnya) — TANPA
///   integrasi, hanya dicatat.
/// - **Hutang:** nama pelanggan WAJIB diisi, status tersimpan
///   `debt_unpaid`.
///
/// Desain (docs/ui-redesign-foundation.md): total belanja tampil sebagai
/// panel hero di atas, metode bayar berupa tiga kartu besar (target sentuh
/// jauh di atas 48dp), pecahan cepat sebagai tombol tonal, dan kembalian
/// diberi panel bernada (`success` cukup / `danger` kurang) dengan angka
/// `AppMoneySize.lg` supaya terbaca dari jarak satu lengan.
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
      if (mounted) setState(() => _errorMessage = AppErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = cart.total;
    final theme = Theme.of(context);
    final isValid = _isFormValid(total);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            0,
            AppSizes.screenPadding,
            AppSizes.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pembayaran', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSizes.spaceMd),
              AppCard(
                color: AppColors.primary50,
                borderColor: AppColors.primary100,
                padding: const EdgeInsets.all(AppSizes.spaceMl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL BELANJA', style: AppTextStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceXs),
                    AppMoneyText(
                      CurrencyFormatter.format(total),
                      size: AppMoneySize.lg,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    Text(
                      '${cart.lineCount} item di keranjang',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spaceLg),
              Text('Metode pembayaran', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSizes.spaceSm),
              _buildMethodSelector(),
              const SizedBox(height: AppSizes.spaceLg),
              switch (_paymentMethod) {
                'cash' => _buildCashForm(total),
                'noncash' => _buildNoncashForm(),
                'debt' => _buildDebtForm(),
                _ => const SizedBox.shrink(),
              },
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSizes.spaceMd),
                AppBanner(
                  tone: AppTone.danger,
                  icon: Icons.error_outline_rounded,
                  title: 'Pembayaran gagal disimpan',
                  message: _errorMessage!,
                ),
              ],
              const SizedBox(height: AppSizes.spaceLg),
              _ConfirmButton(
                enabled: !_saving && isValid,
                saving: _saving,
                onPressed: () => _confirm(total),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _MethodCard(
            label: 'Tunai',
            icon: Icons.payments_outlined,
            value: 'cash',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSm),
        Expanded(
          child: _MethodCard(
            label: 'Non-tunai',
            icon: Icons.qr_code_2_rounded,
            value: 'noncash',
            selected: _paymentMethod,
            onSelect: _selectMethod,
          ),
        ),
        const SizedBox(width: AppSizes.spaceSm),
        Expanded(
          child: _MethodCard(
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
    final tone = isEnough ? AppTone.success : AppTone.danger;
    final toneColors = tone.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _paidController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.moneyLarge,
          decoration: const InputDecoration(
            labelText: 'Uang diterima',
            prefixText: 'Rp ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSizes.spaceMs),
        // Dua kolom (bukan empat) supaya tiap pecahan punya lebar penuh
        // untuk jempol — kasir menekannya sambil melihat uang di tangan.
        for (var row = 0; row < _quickAmounts.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSizes.spaceSm),
          Row(
            children: [
              for (var i = row; i < row + 2 && i < _quickAmounts.length; i++) ...[
                if (i > row) const SizedBox(width: AppSizes.spaceSm),
                Expanded(
                  child: _QuickButton(
                    label: CurrencyFormatter.format(_quickAmounts[i]),
                    onTap: () => _addQuickAmount(_quickAmounts[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: AppSizes.spaceSm),
        _QuickButton(
          label: 'Uang Pas',
          tone: AppTone.accent,
          icon: Icons.done_all_rounded,
          onTap: () => _setExact(total),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        AppCard(
          color: toneColors.bg,
          borderColor: toneColors.border,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceMd,
            vertical: AppSizes.spaceMs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isEnough ? 'Kembalian' : 'Kurang bayar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: toneColors.fg,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              AppMoneyText(
                CurrencyFormatter.format(isEnough ? change : -change),
                size: AppMoneySize.lg,
                color: toneColors.fg,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoncashForm() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Jenis pembayaran', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSizes.spaceSm),
        Wrap(
          spacing: AppSizes.spaceSm,
          runSpacing: AppSizes.spaceSm,
          children: [
            for (final type in _noncashTypes)
              ChoiceChip(
                label: Text(type),
                selected: _noncashType == type,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spaceMs,
                  vertical: AppSizes.spaceSm,
                ),
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
        const SizedBox(height: AppSizes.spaceMd),
        const AppBanner(
          tone: AppTone.info,
          icon: Icons.info_outline_rounded,
          message: 'Pembayaran non-tunai HANYA dicatat jenisnya — tidak ada '
              'integrasi/pengecekan otomatis ke penyedia QRIS/bank.',
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
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: showError ? 'Nama pelanggan wajib diisi' : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            prefixIcon: Icon(Icons.sticky_note_2_outlined),
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        const AppBanner(
          tone: AppTone.accent,
          icon: Icons.schedule_rounded,
          message: 'Transaksi ini tersimpan sebagai HUTANG (belum lunas) — '
              'bisa ditandai lunas nanti dari layar Riwayat.',
        ),
      ],
    );
  }
}

/// Kartu pilihan metode bayar — target sentuh besar (>= 72dp) dengan ikon
/// yang berganti outlined→filled saat terpilih, konsisten dengan dock nav.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
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
    final fg = isSelected ? AppColors.primary : AppColors.inkSecondary;

    return AppCard(
      selected: isSelected,
      onTap: () => onSelect(value),
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: AppSizes.spaceMs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconLg, color: fg),
          const SizedBox(height: AppSizes.spaceSm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Tombol pecahan cepat / uang pas. Bernada brand (atau aksen untuk "Uang
/// Pas", satu-satunya pintasan yang menyelesaikan input sekali tap).
class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.label,
    required this.onTap,
    this.tone = AppTone.primary,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = tone.colors;
    return AppCard(
      onTap: onTap,
      radius: AppSizes.radiusMd,
      color: c.bg,
      borderColor: c.border,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceSm,
        vertical: AppSizes.spaceMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconSm, color: c.fg),
            const SizedBox(width: AppSizes.spaceSm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: AppSizes.buttonHeightLarge,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        child: saving
            ? const SizedBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.onDark,
                ),
              )
            : const Text('Selesaikan Pembayaran'),
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
