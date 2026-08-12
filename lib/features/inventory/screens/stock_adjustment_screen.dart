import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
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
///
/// Susunan visual mengikuti cara orang berpikir saat menghitung barang:
/// **stok sekarang → mau diapakan → berapa → jadi berapa**. Kartu pratinjau
/// "sebelum → sesudah" adalah inti layar ini; warnanya mengikuti arah
/// pergerakan (masuk hijau, keluar merah, opname biru).
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

  /// Nada warna sesuai arah pergerakan — dipakai konsisten oleh chip jenis,
  /// kartu pratinjau, dan ikon.
  AppTone get _tone => switch (_type) {
        'adjust_in' => AppTone.success,
        'adjust_out' => AppTone.danger,
        _ => AppTone.info,
      };

  IconData get _typeIcon => switch (_type) {
        'adjust_in' => Icons.south_rounded,
        'adjust_out' => Icons.north_rounded,
        _ => Icons.fact_check_outlined,
      };

  String get _noteHint => switch (_type) {
        'adjust_in' => 'mis. Belanja stok dari agen',
        'adjust_out' => 'mis. Barang rusak / kedaluwarsa',
        _ => 'mis. Hasil hitung ulang rak depan',
      };

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
      _showError(AppErrorMessage.from(e));
    } on AlasanPenyesuaianWajibException catch (e) {
      _showError(AppErrorMessage.from(e));
    } on ProdukTidakDitemukanException catch (e) {
      _showError(AppErrorMessage.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    final unit = widget.product.unit;

    return Scaffold(
      appBar: AppBar(title: const Text('Sesuaikan Stok')),
      body: SafeArea(
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
              // 1. Duduk perkaranya: barang apa, stoknya berapa sekarang.
              AppCard(
                elevated: true,
                padding: const EdgeInsets.all(AppSizes.spaceMl),
                child: Row(
                  children: [
                    const AppIconBadge(
                      icon: Icons.inventory_2_outlined,
                      size: AppIconBadgeSize.lg,
                    ),
                    const SizedBox(width: AppSizes.spaceMs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.product.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSizes.spaceXs),
                          Text('STOK SEKARANG', style: context.textStyles.eyebrow),
                          const SizedBox(height: AppSizes.spaceXs),
                          Text(
                            '${_formatNum(widget.product.stock)} $unit',
                            style: context.textStyles.moneyLarge.copyWith(
                              fontSize: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spaceMs),

              // 2. Mau diapakan.
              AppCard(
                padding: const EdgeInsets.all(AppSizes.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Jenis penyesuaian',
                      subtitle: 'Opname dipakai kalau kamu menghitung ulang fisik barang.',
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 'adjust_in',
                          label: Text('Masuk'),
                          icon: Icon(Icons.south_rounded),
                        ),
                        ButtonSegment(
                          value: 'adjust_out',
                          label: Text('Keluar'),
                          icon: Icon(Icons.north_rounded),
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
                      decoration: InputDecoration(
                        labelText: _amountLabel(),
                        prefixIcon: Icon(_typeIcon),
                        suffixText: unit,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: _validateAmount,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: AppSizes.spaceMs),
                      _PreviewCard(
                        tone: _tone,
                        before: '${_formatNum(widget.product.stock)} $unit',
                        after: '${_formatNum(preview)} $unit',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spaceMs),

              // 3. Kenapa — wajib, jadi jangan disembunyikan di bawah.
              AppCard(
                padding: const EdgeInsets.all(AppSizes.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Alasan',
                      subtitle: 'Tercatat di riwayat stok supaya bisa ditelusuri nanti.',
                    ),
                    const SizedBox(height: AppSizes.spaceXs),
                    TextFormField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'Alasan / catatan *',
                        hintText: _noteHint,
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      validator: _validateNote,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: AppDecorations.floating(context, radius: AppSizes.radius2xl),
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
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.palette.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan Penyesuaian'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pratinjau "sebelum → sesudah": inti layar penyesuaian stok.
///
/// Nilai sesudah sengaja dibuat paling besar & paling tebal (§1 prinsip 1:
/// angka lebih penting dari labelnya).
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.tone,
    required this.before,
    required this.after,
  });

  final AppTone tone;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = tone.colorsOf(context);

    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      decoration: AppDecorations.tonal(context, tone, radius: AppSizes.radiusMd),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SEBELUM', style: context.textStyles.eyebrow),
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  before,
                  style: context.textStyles.numeric.copyWith(
                    color: context.palette.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: c.fg),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'STOK JADI',
                  style: context.textStyles.eyebrow.copyWith(color: c.fg),
                ),
                const SizedBox(height: AppSizes.spaceXs),
                Text(
                  after,
                  style: theme.textTheme.headlineSmall?.copyWith(color: c.fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
