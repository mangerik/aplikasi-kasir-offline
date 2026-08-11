import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/repository_exceptions.dart';
import '../providers/stock_providers.dart';

/// Layar penyesuaian stok manual (plan.md Milestone 4 poin 1): stok masuk,
/// stok keluar, atau opname (hasil hitung fisik) — WAJIB disertai alasan,
/// tersimpan sebagai `stock_movements` + update `products.stock` dalam
/// satu `db.transaction()` (`AdjustStockUsecase`/`StockRepository`).
///
/// Mengembalikan `true` lewat `Navigator.pop` bila penyesuaian berhasil
/// disimpan, supaya layar pemanggil (mis. `ProductFormScreen`) tahu perlu
/// memuat ulang data produk.
class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'adjust_in';
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    final trimmed = _amountController.text.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  String? _amountLabel() => switch (_type) {
        'adjust_in' => 'Jumlah masuk (${widget.product.unit}) *',
        'adjust_out' => 'Jumlah keluar (${widget.product.unit}) *',
        _ => 'Stok akhir hasil hitung fisik (${widget.product.unit}) *',
      };

  String? _validateAmount(String? value) {
    final parsed = _parseAmount();
    if (parsed == null) return 'Jumlah wajib diisi berupa angka';
    if (_type == 'opname') {
      if (parsed < 0) return 'Stok akhir tidak boleh negatif';
    } else {
      if (parsed <= 0) return 'Jumlah harus lebih dari 0';
    }
    return null;
  }

  String? _validateNote(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Alasan/catatan wajib diisi';
    }
    return null;
  }

  double? get _preview {
    final amount = _parseAmount();
    if (amount == null) return null;
    return switch (_type) {
      'adjust_in' => widget.product.stock + amount,
      'adjust_out' => widget.product.stock - amount,
      _ => amount,
    };
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(adjustStockUsecaseProvider)(
        productId: widget.product.id,
        type: _type,
        amount: _parseAmount()!,
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Penyesuaian stok berhasil disimpan.')));
      Navigator.of(context).pop(true);
    } on JumlahPenyesuaianTidakValidException catch (e) {
      _showError(e.toString());
    } on AlasanPenyesuaianWajibException catch (e) {
      _showError(e.toString());
    } on ProdukTidakDitemukanException catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Sesuaikan Stok')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            children: [
              Text(widget.product.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Stok sekarang: ${_formatNum(widget.product.stock)} ${widget.product.unit}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.spaceMd),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'adjust_in', label: Text('Stok Masuk'), icon: Icon(Icons.add)),
                  ButtonSegment(
                    value: 'adjust_out',
                    label: Text('Stok Keluar'),
                    icon: Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: 'opname',
                    label: Text('Opname'),
                    icon: Icon(Icons.fact_check_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() => _type = selection.first);
                  _formKey.currentState?.validate();
                },
              ),
              const SizedBox(height: AppSizes.spaceMd),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: _amountLabel()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: _validateAmount,
                onChanged: (_) => setState(() {}),
              ),
              if (preview != null) ...[
                const SizedBox(height: AppSizes.spaceSm),
                Text(
                  'Stok setelah penyesuaian: ${_formatNum(preview)} ${widget.product.unit}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: AppSizes.spaceMd),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Alasan / catatan *',
                  hintText: 'mis. Belanja stok baru, barang rusak, hasil hitung ulang',
                ),
                maxLines: 2,
                textInputAction: TextInputAction.done,
                validator: _validateNote,
              ),
              const SizedBox(height: AppSizes.spaceLg),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan Penyesuaian'),
              ),
              const SizedBox(height: AppSizes.spaceLg),
            ],
          ),
        ),
      ),
    );
  }
}
