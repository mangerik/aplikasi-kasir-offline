import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
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
      title: 'Stok Menipis',
      subtitle: 'Threshold default bila produk tidak punya batas sendiri.',
      children: [
        defaultAsync.when(
          data: (value) => _LowStockForm(initialValue: value),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.spaceMd),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Gagal memuat threshold: $e'),
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
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatNum(widget.initialValue));
  }

  static String _formatNum(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Batas stok menipis',
              errorText: _error,
              helperText: 'Berlaku untuk produk tanpa threshold sendiri.',
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spaceSm),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
