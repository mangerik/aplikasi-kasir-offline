import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
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

/// Satuan yang paling sering dipakai warung — ditawarkan sebagai chip supaya
/// pengguna memilih daripada mengetik (lebih cepat & lebih konsisten ejaannya).
const List<String> _commonUnits = <String>[
  'pcs',
  'bungkus',
  'botol',
  'sachet',
  'kg',
  'liter',
];

/// Form tambah/edit produk (plan.md Milestone 1 poin 4): nama (wajib),
/// barcode (ketik atau scan kamera), kategori (dropdown + tambah cepat),
/// harga jual (wajib), harga modal (opsional), stok, satuan, threshold
/// stok menipis, dan status aktif (mode ubah).
///
/// Tata letak dibagi jadi empat kartu bertema — Identitas, Harga, Stok,
/// Status — supaya form panjang ini terbaca sebagai beberapa langkah pendek,
/// bukan satu tumpukan field. Tombol simpan duduk di bar mengambang bawah
/// (zona jempol, §7.1 poin 7).
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
        if (mounted) _showError(AppErrorMessage.from(e));
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
      if (mounted) _showError(AppErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Selisih harga jual − harga modal, hanya untuk ditampilkan sebagai
  /// pratinjau di kartu Harga (tidak disimpan ke mana pun).
  int? get _profitPreview {
    final sell = int.tryParse(_sellPriceController.text.trim());
    final cost = int.tryParse(_costPriceController.text.trim());
    if (sell == null || cost == null) return null;
    return sell - cost;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    _defaultThreshold =
        ref.watch(lowStockDefaultThresholdProvider).value ?? Product.defaultLowStockThreshold;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Ubah Produk' : 'Tambah Produk')),
      body: _loading
          ? const AppLoadingView(message: 'Memuat data produk…')
          : SafeArea(
              bottom: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    AppSizes.spaceMs,
                    AppSizes.screenPadding,
                    AppSizes.spaceLg,
                  ),
                  children: [
                    _FormSection(
                      icon: Icons.label_outline_rounded,
                      title: 'Identitas Produk',
                      subtitle: 'Nama yang muncul di layar Kasir.',
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama produk *',
                            hintText: 'mis. Indomie Goreng',
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: ProductFormValidator.name,
                        ),
                        const SizedBox(height: AppSizes.spaceMs),
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
                            _ScanButton(onPressed: _scanBarcode),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spaceMs),
                        categoriesAsync.when(
                          data: (categories) {
                            final validId =
                                _categoryId != null && categories.any((c) => c.id == _categoryId);
                            return DropdownButtonFormField<int?>(
                              initialValue: validId ? _categoryId : null,
                              decoration: const InputDecoration(
                                labelText: 'Kategori (opsional)',
                                prefixIcon: Icon(Icons.sell_outlined),
                              ),
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                              // Tanpa ini, entri panjang ("+ Tambah kategori
                              // baru") meluber di HP 360dp.
                              isExpanded: true,
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
                          loading: () => const AppLoadingView(compact: true),
                          error: (error, stack) => AppBanner(
                            tone: AppTone.danger,
                            icon: Icons.error_outline_rounded,
                            message: 'Gagal memuat kategori: ${AppErrorMessage.from(error)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceMs),
                    _FormSection(
                      icon: Icons.payments_outlined,
                      title: 'Harga',
                      subtitle: 'Harga modal dipakai untuk menghitung laba.',
                      children: [
                        TextFormField(
                          controller: _sellPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Harga jual *',
                            prefixText: 'Rp ',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textInputAction: TextInputAction.next,
                          validator: ProductFormValidator.sellPrice,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSizes.spaceMs),
                        TextFormField(
                          controller: _costPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Harga modal (opsional)',
                            prefixText: 'Rp ',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textInputAction: TextInputAction.next,
                          validator: ProductFormValidator.costPrice,
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_profitPreview != null) ...[
                          const SizedBox(height: AppSizes.spaceMs),
                          AppCard(
                            color: AppColors.surfaceAlt,
                            radius: AppSizes.radiusMd,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.spaceMs,
                              vertical: AppSizes.spaceXs,
                            ),
                            child: AppKeyValueRow(
                              icon: Icons.trending_up_rounded,
                              label: 'Untung per ${_unitLabel()}',
                              value: CurrencyFormatter.format(_profitPreview!),
                              valueColor: _profitPreview! < 0
                                  ? AppColors.dangerText
                                  : AppColors.successText,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceMs),
                    _FormSection(
                      icon: Icons.inventory_2_outlined,
                      title: 'Stok & Satuan',
                      subtitle: 'Batas stok menipis menentukan kapan kamu diingatkan.',
                      children: [
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
                            const SizedBox(width: AppSizes.spaceMs),
                            Expanded(
                              child: TextFormField(
                                controller: _unitController,
                                decoration: const InputDecoration(labelText: 'Satuan *'),
                                textInputAction: TextInputAction.next,
                                validator: ProductFormValidator.unit,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.spaceSm),
                        _UnitChips(
                          selected: _unitController.text.trim().toLowerCase(),
                          onSelect: (unit) => setState(() {
                            _unitController.text = unit;
                          }),
                        ),
                        const SizedBox(height: AppSizes.spaceMs),
                        TextFormField(
                          controller: _thresholdController,
                          decoration: InputDecoration(
                            labelText: 'Batas stok menipis (opsional)',
                            hintText: 'Kosong = ikut default (${_defaultThreshold.toInt()})',
                            prefixIcon: const Icon(Icons.warning_amber_rounded),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          validator: ProductFormValidator.lowStockThreshold,
                        ),
                        if (widget.isEdit && _existing != null) ...[
                          const SizedBox(height: AppSizes.spaceMs),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openStockAdjustment,
                                  icon: const Icon(Icons.tune_rounded, size: AppSizes.iconSm),
                                  label: const Text('Sesuaikan'),
                                ),
                              ),
                              const SizedBox(width: AppSizes.spaceSm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openStockHistory,
                                  icon: const Icon(Icons.history_rounded, size: AppSizes.iconSm),
                                  label: const Text('Riwayat'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceMs),
                    _FormSection(
                      icon: Icons.toggle_on_outlined,
                      title: 'Status & Lainnya',
                      children: [
                        if (widget.isEdit)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Produk aktif'),
                            subtitle: const Text(
                              'Nonaktifkan untuk menyembunyikan dari Kasir tanpa menghapus data.',
                            ),
                            value: _isActive,
                            onChanged: (value) => setState(() => _isActive = value),
                          ),
                        if (widget.isEdit) const SizedBox(height: AppSizes.spaceSm),
                        const AppBanner(
                          tone: AppTone.neutral,
                          icon: Icons.image_outlined,
                          message: 'Foto produk belum didukung di versi ini.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : _SaveBar(
              label: widget.isEdit ? 'Simpan Perubahan' : 'Simpan Produk',
              saving: _saving,
              onPressed: _saving ? null : _submit,
            ),
    );
  }

  String _unitLabel() {
    final unit = _unitController.text.trim();
    return unit.isEmpty ? 'satuan' : unit;
  }
}

/// Satu kartu section di form: ikon bernada + judul + isi.
///
/// Memberi ritme yang sama untuk semua bagian form dan memutus "dinding
/// field" jadi kelompok yang bisa dipindai sekali lihat.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(icon: icon, size: AppIconBadgeSize.sm),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: SectionHeader(
                  title: title,
                  subtitle: subtitle,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMd),
          ...children,
        ],
      ),
    );
  }
}

/// Tinggi field input bertema (padding 16 atas/bawah + tinggi baris teks),
/// dipakai agar tombol di sebelah field rata tinggi dengannya.
const double _fieldHeight = AppSizes.minTouchTarget + AppSizes.spaceSm;

/// Tombol scan barcode setinggi field di sebelahnya, supaya baris barcode
/// terbaca sebagai satu kesatuan (bukan ikon yang melayang).
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scan barcode',
      child: SizedBox(
        width: _fieldHeight,
        height: _fieldHeight,
        child: Material(
          color: AppColors.primary50,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              size: AppSizes.iconLg,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilihan satuan cepat — memilih lebih cepat daripada mengetik.
class _UnitChips extends StatelessWidget {
  const _UnitChips({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.spaceSm,
      runSpacing: AppSizes.spaceSm,
      children: [
        for (final unit in _commonUnits)
          ChoiceChip(
            label: Text(unit),
            selected: selected == unit,
            onSelected: (_) => onSelect(unit),
          ),
      ],
    );
  }
}

/// Bar aksi bawah (§7.3): permukaan mengambang + satu tombol lebar setinggi
/// [AppSizes.buttonHeightLarge] di zona jempol.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  final String label;
  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.floating(radius: AppSizes.radius2xl),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spaceMd,
        AppSizes.spaceMs,
        AppSizes.spaceMd,
        AppSizes.spaceMs,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.buttonHeightLarge,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: saving
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onDark,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(saving ? 'Menyimpan…' : label),
          ),
        ),
      ),
    );
  }
}
