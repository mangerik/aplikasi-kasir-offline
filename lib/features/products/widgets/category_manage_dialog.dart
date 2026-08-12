import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/repositories/repository_exceptions.dart';
import '../providers/category_providers.dart';
import '../utils/product_form_validator.dart';

/// Dialog CRUD kategori sederhana: tambah, ubah nama, hapus — dengan
/// validasi "kategori masih dipakai produk" (plan.md Milestone 1 poin 5).
///
/// Tata letak: daftar kategori sebagai kartu kecil (ikon label + nama +
/// dua aksi ikon), lalu panel "tambah cepat" yang menempel di bawah supaya
/// menambah kategori berturut-turut tidak perlu menutup dialog.
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
      contentPadding: const EdgeInsets.fromLTRB(
        AppSizes.spaceMl,
        AppSizes.spaceSm,
        AppSizes.spaceMl,
        AppSizes.spaceSm,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const EmptyState(
                      icon: Icons.sell_outlined,
                      title: 'Belum ada kategori',
                      message:
                          'Kelompokkan barang (mis. Minuman, Rokok, Sembako) '
                          'supaya lebih cepat dicari di layar Kasir.',
                      compact: true,
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.spaceXs,
                    ),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.spaceSm),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _CategoryRow(
                        category: category,
                        onRename: () => _rename(context, ref, category),
                        onDelete: () => _delete(context, ref, category),
                      );
                    },
                  );
                },
                loading: () => const AppLoadingView(compact: true),
                error: (error, stack) => AppErrorView(
                  title: 'Gagal memuat kategori',
                  message: AppErrorMessage.from(error),
                  compact: true,
                  onRetry: () => ref.invalidate(categoryListProvider),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spaceMs),
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
      if (context.mounted) _showError(context, AppErrorMessage.from(e));
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
          textCapitalization: TextCapitalization.words,
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
      if (context.mounted) _showError(context, AppErrorMessage.from(e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const AppIconBadge(
          icon: Icons.delete_outline_rounded,
          tone: AppTone.danger,
          size: AppIconBadgeSize.lg,
        ),
        title: const Text('Hapus kategori?'),
        content: Text(
          'Kategori "${category.name}" akan dihapus. Produk yang masih '
          'memakainya tidak bisa dihapus kategorinya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          // Satu-satunya override warna tombol yang diizinkan fondasi §7.3:
          // konfirmasi aksi merusak.
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
      if (context.mounted) _showError(context, AppErrorMessage.from(e));
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Satu baris kategori di dalam dialog.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onRename,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.palette.surfaceAlt,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spaceMs,
        AppSizes.spaceXs,
        AppSizes.spaceXs,
        AppSizes.spaceXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Ubah nama',
            iconSize: AppSizes.iconSm,
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Hapus',
            iconSize: AppSizes.iconSm,
            style: IconButton.styleFrom(foregroundColor: context.palette.dangerText),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

/// Tinggi field input bertema — dipakai supaya tombol tambah rata tinggi
/// dengan field di sebelahnya.
const double _fieldHeight = AppSizes.minTouchTarget + AppSizes.spaceSm;

/// Panel tambah kategori cepat yang menempel di bawah daftar.
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Kategori baru',
                hintText: 'mis. Minuman',
              ),
              validator: ProductFormValidator.categoryName,
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          SizedBox(
            width: _fieldHeight,
            height: _fieldHeight,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(_fieldHeight),
              ),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
