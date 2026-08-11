import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/category.dart';
import '../../../domain/repositories/repository_exceptions.dart';
import '../providers/category_providers.dart';
import '../utils/product_form_validator.dart';

/// Dialog CRUD kategori sederhana: tambah, ubah nama, hapus — dengan
/// validasi "kategori masih dipakai produk" (plan.md Milestone 1 poin 5).
class CategoryManageDialog extends ConsumerWidget {
  const CategoryManageDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const CategoryManageDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);
    return AlertDialog(
      title: const Text('Kelola Kategori'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Belum ada kategori.'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return ListTile(
                        title: Text(category.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ubah nama',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _rename(context, ref, category),
                            ),
                            IconButton(
                              tooltip: 'Hapus',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(context, ref, category),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Text('Gagal memuat kategori: $error'),
              ),
            ),
            const Divider(),
            _AddCategoryField(onSubmit: (name) => _add(context, ref, name)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String name) async {
    try {
      await ref.read(categoryRepoProvider).create(name);
    } on NamaKategoriSudahAdaException catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Category category) async {
    final controller = TextEditingController(text: category.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah Nama Kategori'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == category.name) return;
    try {
      await ref.read(categoryRepoProvider).rename(category.id, newName);
    } on NamaKategoriSudahAdaException catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Hapus kategori "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(categoryRepoProvider).delete(category.id);
    } on KategoriMasihDipakaiException catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddCategoryField extends StatefulWidget {
  const _AddCategoryField({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_AddCategoryField> createState() => _AddCategoryFieldState();
}

class _AddCategoryFieldState extends State<_AddCategoryField> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(_controller.text.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Kategori baru'),
              validator: ProductFormValidator.categoryName,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            tooltip: 'Tambah',
            icon: const Icon(Icons.add_circle),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
