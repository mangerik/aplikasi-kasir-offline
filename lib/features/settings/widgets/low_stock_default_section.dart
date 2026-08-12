import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/settings_providers.dart';
import 'settings_card.dart';

/// Seksi threshold default stok menipis (plan.md Milestone 5 poin 2, key
/// `settings.low_stock_default`) — dipakai produk yang TIDAK punya
/// threshold sendiri (`Product.lowStockThreshold == null`).
class LowStockDefaultSection extends ConsumerWidget {
  const LowStockDefaultSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultAsync = ref.watch(lowStockDefaultProvider);
    return SettingsCard(
      icon: Icons.inventory_2_outlined,
      title: 'Stok Menipis',
      subtitle: 'Batas default bila produk tidak punya batas sendiri.',
      tone: AppTone.warning,
      children: [
        defaultAsync.when(
          data: (value) => _LowStockForm(initialValue: value),
          loading: () => const AppLoadingView(compact: true),
          error: (e, _) => AppErrorView(
            title: 'Batas stok gagal dimuat',
            message: AppErrorMessage.from(e),
            compact: true,
            onRetry: () => ref.invalidate(lowStockDefaultProvider),
          ),
        ),
      ],
    );
  }
}

class _LowStockForm extends ConsumerStatefulWidget {
  const _LowStockForm({required this.initialValue});

  final double initialValue;

  @override
  ConsumerState<_LowStockForm> createState() => _LowStockFormState();
}

class _LowStockFormState extends ConsumerState<_LowStockForm> {
  /// Nilai pintasan yang paling sering dipakai warung — memilih lebih
  /// cepat & lebih sedikit salah ketik daripada mengetik angka.
  static const List<double> _presets = [3, 5, 10, 20];

  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatNum(widget.initialValue));
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  static String _formatNum(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  double? get _currentValue => double.tryParse(_controller.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = _currentValue;
    if (parsed == null || parsed < 0) {
      setState(() => _error = 'Masukkan angka valid (>= 0).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(settingsRepoProvider).setValue('low_stock_default', parsed.toString());
    ref.invalidate(lowStockDefaultProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Threshold stok menipis disimpan.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _currentValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pilihan cepat', style: context.textStyles.eyebrow),
        const SizedBox(height: AppSizes.spaceSm),
        Wrap(
          spacing: AppSizes.spaceSm,
          runSpacing: AppSizes.spaceSm,
          children: [
            for (final preset in _presets)
              ChoiceChip(
                label: Text('${_formatNum(preset)} unit'),
                selected: selected == preset,
                onSelected: _saving
                    ? null
                    : (_) => setState(() {
                        _controller.text = _formatNum(preset);
                        _error = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMd),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Batas stok menipis',
            prefixIcon: const Icon(Icons.trending_down_rounded),
            errorText: _error,
            helperText: 'Produk dengan stok di bawah angka ini ditandai.',
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Menyimpan…' : 'Simpan Batas'),
          ),
        ),
        const SizedBox(height: AppSizes.spaceSm),
        Text(
          'Berlaku untuk semua produk yang belum diberi batas khusus.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
