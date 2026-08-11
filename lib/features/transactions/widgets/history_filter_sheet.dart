import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/history_providers.dart';

/// Sheet filter riwayat transaksi (plan.md Milestone 3 poin 2): rentang
/// tanggal, metode bayar, status (lunas/hutang/batal).
class HistoryFilterSheet extends ConsumerStatefulWidget {
  const HistoryFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const HistoryFilterSheet(),
    );
  }

  @override
  ConsumerState<HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends ConsumerState<HistoryFilterSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _paymentMethod;
  String? _status;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(historyFilterProvider);
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _paymentMethod = filter.paymentMethod;
    _status = filter.status;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _apply() {
    ref
        .read(historyFilterProvider.notifier)
        .apply(
          startDate: _startDate,
          endDate: _endDate,
          paymentMethod: _paymentMethod,
          status: _status,
        );
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _paymentMethod = null;
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceMd),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filter Riwayat', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSizes.spaceMd),
                Text('Rentang tanggal', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSizes.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          (_startDate != null && _endDate != null)
                              ? '${DateFormatter.formatDateShort(_startDate!)} - '
                                    '${DateFormatter.formatDateShort(_endDate!)}'
                              : 'Semua tanggal',
                        ),
                      ),
                    ),
                    if (_startDate != null || _endDate != null)
                      IconButton(
                        tooltip: 'Hapus filter tanggal',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _startDate = null;
                          _endDate = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceMd),
                Text('Metode bayar', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSizes.spaceSm),
                Wrap(
                  spacing: AppSizes.spaceSm,
                  runSpacing: AppSizes.spaceSm,
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      selected: _paymentMethod == null,
                      onSelected: () => setState(() => _paymentMethod = null),
                    ),
                    _FilterChip(
                      label: 'Tunai',
                      selected: _paymentMethod == 'cash',
                      onSelected: () => setState(() => _paymentMethod = 'cash'),
                    ),
                    _FilterChip(
                      label: 'Non-tunai',
                      selected: _paymentMethod == 'noncash',
                      onSelected: () => setState(() => _paymentMethod = 'noncash'),
                    ),
                    _FilterChip(
                      label: 'Hutang',
                      selected: _paymentMethod == 'debt',
                      onSelected: () => setState(() => _paymentMethod = 'debt'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceMd),
                Text('Status', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSizes.spaceSm),
                Wrap(
                  spacing: AppSizes.spaceSm,
                  runSpacing: AppSizes.spaceSm,
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      selected: _status == null,
                      onSelected: () => setState(() => _status = null),
                    ),
                    _FilterChip(
                      label: 'Lunas',
                      selected: _status == 'completed',
                      onSelected: () => setState(() => _status = 'completed'),
                    ),
                    _FilterChip(
                      label: 'Hutang',
                      selected: _status == 'debt_unpaid',
                      onSelected: () => setState(() => _status = 'debt_unpaid'),
                    ),
                    _FilterChip(
                      label: 'Batal',
                      selected: _status == 'voided',
                      onSelected: () => setState(() => _status = 'voided'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      flex: 2,
                      child: FilledButton(onPressed: _apply, child: const Text('Terapkan')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onSelected: (_) => onSelected(),
    );
  }
}
