import 'package:flutter/material.dart';

import '../utils/product_form_validator.dart';

/// Dialog ringkas untuk mengetik nama kategori baru, dipakai dari dropdown
/// kategori di form produk ("+ Tambah kategori baru", plan.md Milestone 1
/// poin 4).
///
/// Hanya mengembalikan nama yang diketik lewat `Navigator.pop` — pembuatan
/// kategori sesungguhnya (lewat `CategoryRepository`) dilakukan oleh
/// pemanggil, supaya dialog ini tidak perlu bergantung pada Riverpod/Drift.
class QuickAddCategoryDialog extends StatefulWidget {
  const QuickAddCategoryDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const QuickAddCategoryDialog(),
    );
  }

  @override
  State<QuickAddCategoryDialog> createState() => _QuickAddCategoryDialogState();
}

class _QuickAddCategoryDialogState extends State<QuickAddCategoryDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Kategori Baru'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
          validator: ProductFormValidator.categoryName,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Tambah'),
        ),
      ],
    );
  }
}
