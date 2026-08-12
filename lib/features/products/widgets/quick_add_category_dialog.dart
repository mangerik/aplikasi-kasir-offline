import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';
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
      icon: const AppIconBadge(
        icon: Icons.sell_outlined,
        size: AppIconBadgeSize.lg,
      ),
      title: const Text('Kategori Baru'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nama kategori',
                hintText: 'mis. Minuman',
              ),
              validator: ProductFormValidator.categoryName,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSizes.spaceSm),
            Text(
              'Kategori langsung dipakai untuk produk yang sedang kamu isi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
