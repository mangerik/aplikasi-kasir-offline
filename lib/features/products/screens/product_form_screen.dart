import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/repository_exceptions.dart';
import '../../inventory/providers/stock_providers.dart';
import '../../inventory/screens/stock_adjustment_screen.dart';
import '../../inventory/screens/stock_movement_history_screen.dart';
import '../providers/category_providers.dart';
import '../providers/product_providers.dart';
import '../utils/product_form_validator.dart';
import '../widgets/barcode_scanner_page.dart';
import '../widgets/quick_add_category_dialog.dart';

/// Sentinel dropdown untuk entri "+ Tambah kategori baru" (aman karena id
/// kategori asli dari Drift `autoIncrement()` selalu >= 1).
const int _addCategorySentinel = -1;

/// Form tambah/edit produk (plan.md Milestone 1 poin 4): nama (wajib),
/// barcode (ketik atau scan kamera), kategori (dropdown + tambah cepat),
/// harga jual (wajib), harga modal (opsional), stok, satuan, threshold
/// stok menipis, dan status aktif (mode ubah).
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  bool get isEdit => productId != null;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _unitController = TextEditingController(text: 'pcs');
  final _thresholdController = TextEditingController();

  int? _categoryId;
  bool _isActive = true;
  bool _loading = false;
  bool _saving = false;
  Product? _existing;
  double _defaultThreshold = Product.defaultLowStockThreshold;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _loading = true;
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _sellPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final product = await ref.read(productRepoProvider).getById(widget.productId!);
    if (!mounted) return;
    if (product == null) {
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Produk tidak ditemukan.')));
        context.pop();
      });
      return;
    }
    setState(() {
      _existing = product;
      _nameController.text = product.name;
      _barcodeController.text = product.barcode ?? '';
      _sellPriceController.text = product.sellPrice.toString();
      _costPriceController.text = product.costPrice?.toString() ?? '';
      _stockController.text = _formatNum(product.stock);
      _unitController.text = product.unit;
      _thresholdController.text =
          product.lowStockThreshold == null ? '' : _formatNum(product.lowStockThreshold!);
      _categoryId = product.categoryId;
      _isActive = product.isActive;
      _loading = false;
    });
  }

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  double? _parseDouble(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  /// Penyesuaian stok manual (plan.md Milestone 4 poin 1) — dipicu dari
  /// layar detail/edit produk. Setelah berhasil, muat ulang produk supaya
  /// angka stok yang tampil di form ini ikut ter-update.
  Future<void> _openStockAdjustment() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: _existing!)),
    );
    if (saved == true && mounted) {
      setState(() => _loading = true);
      await _loadExisting();
    }
  }

  Future<void> _openStockHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StockMovementHistoryScreen(product: _existing!)),
    );
    // Riwayat stok punya tombol penyesuaian sendiri juga — muat ulang untuk
    // berjaga-jaga angka stok berubah lewat jalur itu.
    if (mounted) {
      setState(() => _loading = true);
      await _loadExisting();
    }
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scanned != null && mounted) {
      setState(() => _barcodeController.text = scanned);
    }
  }

  Future<void> _pickCategory(int? value) async {
    if (value == _addCategorySentinel) {
      final name = await QuickAddCategoryDialog.show(context);
      if (name == null || !mounted) return;
      try {
        final newId = await ref.read(categoryRepoProvider).create(name);
        setState(() => _categoryId = newId);
      } on NamaKategoriSudahAdaException catch (e) {
        if (mounted) _showError(e.toString());
      }
      return;
    }
    setState(() => _categoryId = value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(productRepoProvider);
    final name = _nameController.text;
    final barcode = _barcodeController.text;
    final sellPrice = int.parse(_sellPriceController.text.trim());
    final costPriceRaw = _costPriceController.text.trim();
    final costPrice = costPriceRaw.isEmpty ? null : int.parse(costPriceRaw);
    final stock = _parseDouble(_stockController.text) ?? 0;
    final unit = _unitController.text.trim();
    final threshold = _parseDouble(_thresholdController.text);

    try {
      if (widget.isEdit) {
        await repo.updateProduct(
          id: widget.productId!,
          name: name,
          barcode: barcode,
          categoryId: _categoryId,
          sellPrice: sellPrice,
          costPrice: costPrice,
          stock: stock,
          unit: unit,
          lowStockThreshold: threshold,
        );
        if (_existing != null && _isActive != _existing!.isActive) {
          await repo.setActive(widget.productId!, _isActive);
        }
      } else {
        await repo.createProduct(
          name: name,
          barcode: barcode,
          categoryId: _categoryId,
          sellPrice: sellPrice,
          costPrice: costPrice,
          stock: stock,
          unit: unit,
          lowStockThreshold: threshold,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Produk berhasil diperbarui.' : 'Produk berhasil ditambahkan.'),
        ),
      );
      context.pop();
    } on BarcodeSudahDipakaiException catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    _defaultThreshold =
        ref.watch(lowStockDefaultThresholdProvider).value ?? Product.defaultLowStockThreshold;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Ubah Produk' : 'Tambah Produk')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.spaceMd),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nama produk *'),
                      textInputAction: TextInputAction.next,
                      validator: ProductFormValidator.name,
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: const InputDecoration(
                              labelText: 'Barcode (opsional)',
                              hintText: 'Ketik atau scan',
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: AppSizes.spaceSm),
                        IconButton.filledTonal(
                          tooltip: 'Scan barcode',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanBarcode,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    categoriesAsync.when(
                      data: (categories) {
                        final validId =
                            _categoryId != null && categories.any((c) => c.id == _categoryId);
                        return DropdownButtonFormField<int?>(
                          initialValue: validId ? _categoryId : null,
                          decoration: const InputDecoration(labelText: 'Kategori (opsional)'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Tanpa kategori'),
                            ),
                            for (final category in categories)
                              DropdownMenuItem<int?>(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            const DropdownMenuItem<int?>(
                              value: _addCategorySentinel,
                              child: Text('+ Tambah kategori baru'),
                            ),
                          ],
                          onChanged: _pickCategory,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stack) => Text('Gagal memuat kategori: $error'),
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    TextFormField(
                      controller: _sellPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Harga jual (Rp) *',
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      validator: ProductFormValidator.sellPrice,
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    TextFormField(
                      controller: _costPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Harga modal (Rp, opsional)',
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      validator: ProductFormValidator.costPrice,
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            decoration: InputDecoration(
                              labelText: widget.isEdit ? 'Stok' : 'Stok awal',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            validator: ProductFormValidator.stock,
                          ),
                        ),
                        const SizedBox(width: AppSizes.spaceMd),
                        Expanded(
                          child: TextFormField(
                            controller: _unitController,
                            decoration: const InputDecoration(
                              labelText: 'Satuan *',
                              hintText: 'pcs, kg, liter, ...',
                            ),
                            textInputAction: TextInputAction.next,
                            validator: ProductFormValidator.unit,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceMd),
                    TextFormField(
                      controller: _thresholdController,
                      decoration: InputDecoration(
                        labelText: 'Threshold stok menipis (opsional)',
                        hintText: 'Kosongkan untuk pakai default (${_defaultThreshold.toInt()})',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      validator: ProductFormValidator.lowStockThreshold,
                    ),
                    if (widget.isEdit && _existing != null) ...[
                      const SizedBox(height: AppSizes.spaceMd),
                      Text('Manajemen Stok', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSizes.spaceSm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openStockAdjustment,
                              icon: const Icon(Icons.tune),
                              label: const Text('Sesuaikan Stok'),
                            ),
                          ),
                          const SizedBox(width: AppSizes.spaceSm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openStockHistory,
                              icon: const Icon(Icons.history),
                              label: const Text('Riwayat Stok'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSizes.spaceMd),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.spaceMd),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                          const SizedBox(width: AppSizes.spaceSm),
                          Expanded(
                            child: Text(
                              'Foto produk belum didukung di versi ini.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isEdit) ...[
                      const SizedBox(height: AppSizes.spaceMd),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Produk aktif'),
                        subtitle: const Text(
                          'Nonaktifkan untuk menyembunyikan dari Kasir tanpa menghapus data.',
                        ),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                    const SizedBox(height: AppSizes.spaceLg),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Simpan'),
                    ),
                    const SizedBox(height: AppSizes.spaceLg),
                  ],
                ),
              ),
            ),
    );
  }
}
