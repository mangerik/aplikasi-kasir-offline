import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_widgets.dart';

/// Dialog input diskon — dipakai untuk diskon PER ITEM (`CartItemTile`) dan
/// diskon TOTAL transaksi (`CartPanel`).
///
/// Mendukung dua mode input: **nominal (Rp)** atau **persen (%)** — namun
/// hasil yang dikembalikan SELALU nominal (Rp), sudah dibulatkan & dibatasi
/// `0..baseAmount` (plan.md Milestone 2 poin 1: "diskon per item
/// (nominal/%→disimpan nominal)").
///
/// Mengembalikan `null` bila dibatalkan.
class DiscountDialog {
  static Future<int?> show(
    BuildContext context, {
    required String title,
    required int baseAmount,
    required int initialDiscount,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => _DiscountDialogContent(
        title: title,
        baseAmount: baseAmount,
        initialDiscount: initialDiscount,
      ),
    );
  }
}

enum _DiscountMode { nominal, percent }

class _DiscountDialogContent extends StatefulWidget {
  const _DiscountDialogContent({
    required this.title,
    required this.baseAmount,
    required this.initialDiscount,
  });

  final String title;
  final int baseAmount;
  final int initialDiscount;

  @override
  State<_DiscountDialogContent> createState() => _DiscountDialogContentState();
}

class _DiscountDialogContentState extends State<_DiscountDialogContent> {
  late _DiscountMode _mode;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _mode = _DiscountMode.nominal;
    final initialText = widget.initialDiscount > 0 ? widget.initialDiscount.toString() : '';
    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _baseAmount => widget.baseAmount;

  int _nominalFromInput() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return 0;
    final value = num.tryParse(raw.replaceAll(',', '.')) ?? 0;
    if (_mode == _DiscountMode.percent) {
      final percent = value.clamp(0, 100);
      return ((_baseAmount * percent) / 100).round().clamp(0, _baseAmount).toInt();
    }
    return value.round().clamp(0, _baseAmount).toInt();
  }

  void _switchMode(_DiscountMode mode) {
    if (mode == _mode) return;
    // Konversi nilai yang sedang diketik supaya tidak hilang saat ganti mode.
    final currentNominal = _nominalFromInput();
    setState(() {
      _mode = mode;
      if (currentNominal <= 0) {
        _controller.text = '';
      } else if (mode == _DiscountMode.percent) {
        final percent = _baseAmount == 0 ? 0 : (currentNominal / _baseAmount) * 100;
        _controller.text = percent == percent.roundToDouble()
            ? percent.toStringAsFixed(0)
            : percent.toStringAsFixed(1);
      } else {
        _controller.text = currentNominal.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewNominal = _nominalFromInput();
    final afterDiscount = (_baseAmount - previewNominal).clamp(0, _baseAmount);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              color: AppColors.surfaceAlt,
              radius: AppSizes.radiusMd,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceMd,
                vertical: AppSizes.spaceSm,
              ),
              child: AppKeyValueRow(
                label: 'Harga sebelum diskon',
                value: CurrencyFormatter.format(_baseAmount),
              ),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            SegmentedButton<_DiscountMode>(
              segments: const [
                ButtonSegment(value: _DiscountMode.nominal, label: Text('Nominal')),
                ButtonSegment(value: _DiscountMode.percent, label: Text('Persen')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => _switchMode(selection.first),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: AppTextStyles.moneyLarge,
              decoration: InputDecoration(
                labelText: _mode == _DiscountMode.nominal ? 'Diskon (Rp)' : 'Diskon (%)',
                prefixText: _mode == _DiscountMode.nominal ? 'Rp ' : null,
                suffixText: _mode == _DiscountMode.percent ? '%' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSizes.spaceMd),
            AppCard(
              color: AppColors.primary50,
              borderColor: AppColors.primary100,
              radius: AppSizes.radiusMd,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spaceMd,
                vertical: AppSizes.spaceSm,
              ),
              child: Column(
                children: [
                  AppKeyValueRow(
                    label: 'Potongan',
                    value: previewNominal > 0
                        ? '-${CurrencyFormatter.format(previewNominal)}'
                        : CurrencyFormatter.format(0),
                    valueColor: previewNominal > 0
                        ? AppColors.dangerText
                        : AppColors.inkSecondary,
                  ),
                  AppKeyValueRow(
                    label: 'Jadi bayar',
                    value: CurrencyFormatter.format(afterDiscount),
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            if (_mode == _DiscountMode.percent && _baseAmount > 0) ...[
              const SizedBox(height: AppSizes.spaceSm),
              Text(
                'Persen dihitung dari harga sebelum diskon dan disimpan '
                'sebagai nominal.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        if (widget.initialDiscount > 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('Hapus diskon'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(previewNominal),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
