import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';

/// Hasil input dialog item bebas (plan.md Milestone 2 poin 1: "Item bebas
/// (nama + harga manual)").
class FreeItemInput {
  const FreeItemInput({
    required this.name,
    required this.price,
    required this.qty,
    required this.unit,
  });

  final String name;
  final int price;
  final double qty;
  final String unit;
}

/// Dialog tambah item bebas (barang tak terdaftar) ke keranjang: nama,
/// harga, qty, satuan — semua diketik manual, `productId` tetap null.
class FreeItemDialog {
  static Future<FreeItemInput?> show(BuildContext context) {
    return showDialog<FreeItemInput>(
      context: context,
      builder: (_) => const _FreeItemDialogContent(),
    );
  }
}

class _FreeItemDialogContent extends StatefulWidget {
  const _FreeItemDialogContent();

  @override
  State<_FreeItemDialogContent> createState() => _FreeItemDialogContentState();
}

class _FreeItemDialogContentState extends State<_FreeItemDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'pcs');

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final qty = double.tryParse(_qtyController.text.trim().replaceAll(',', '.')) ?? 1;
    Navigator.of(context).pop(
      FreeItemInput(
        name: _nameController.text.trim(),
        price: int.parse(_priceController.text.trim()),
        qty: qty <= 0 ? 1 : qty,
        unit: _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Item Bebas'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nama barang *'),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: AppSizes.spaceMd),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Harga (Rp) *', prefixText: 'Rp '),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) return 'Harga harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.spaceMd),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceMd),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Satuan'),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Tambah')),
      ],
    );
  }
}
