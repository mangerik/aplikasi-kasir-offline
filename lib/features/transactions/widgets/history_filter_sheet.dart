import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/history_providers.dart';
import 'status_badge.dart';

/// Sheet filter riwayat transaksi (plan.md Milestone 3 poin 2): rentang
/// tanggal, metode bayar, status (lunas/hutang/batal).
///
/// Desain: satu section per pertanyaan ("kapan", "dibayar pakai apa",
/// "keadaannya bagaimana"), pilihan cepat berupa chip, dan dua tombol aksi
/// di zona jempol. Semua nilai tersimpan lokal dulu — filter baru berlaku
/// saat "Terapkan" ditekan (perilaku lama, tidak berubah).
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

  bool get _hasSelection =>
      _startDate != null || _endDate != null || _paymentMethod != null || _status != null;

  bool get _hasDateRange => _startDate != null && _endDate != null;

  static DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  static DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// Rentang cepat: [daysBack] hari ke belakang TERMASUK hari ini.
  void _setQuickRange(int daysBack) {
    final now = DateTime.now();
    setState(() {
      _startDate = _startOfDay(now.subtract(Duration(days: daysBack)));
      _endDate = _endOfDay(now);
    });
  }

  bool _isQuickRange(int daysBack) {
    if (!_hasDateRange) return false;
    final now = DateTime.now();
    return _startDate == _startOfDay(now.subtract(Duration(days: daysBack))) &&
        _endDate == _endOfDay(now);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _hasDateRange
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = _startOfDay(picked.start);
        _endDate = _endOfDay(picked.end);
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
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            0,
            AppSizes.screenPadding,
            AppSizes.spaceMd,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Filter Riwayat',
                  subtitle: 'Persempit daftar transaksi yang tampil',
                  trailing: _hasSelection
                      ? TextButton(onPressed: _reset, child: const Text('Reset'))
                      : null,
                  padding: const EdgeInsets.only(bottom: AppSizes.spaceMd),
                ),

                // --- Kapan.
                Text('RENTANG TANGGAL', style: AppTextStyles.eyebrow),
                const SizedBox(height: AppSizes.spaceSm),
                Wrap(
                  spacing: AppSizes.spaceSm,
                  runSpacing: AppSizes.spaceSm,
                  children: [
                    _FilterChip(
                      label: 'Semua',
                      selected: !_hasDateRange,
                      onSelected: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
                    ),
                    _FilterChip(
                      label: 'Hari ini',
                      selected: _isQuickRange(0),
                      onSelected: () => _setQuickRange(0),
                    ),
                    _FilterChip(
                      label: '7 hari',
                      selected: _isQuickRange(6),
                      onSelected: () => _setQuickRange(6),
                    ),
                    _FilterChip(
                      label: '30 hari',
                      selected: _isQuickRange(29),
                      onSelected: () => _setQuickRange(29),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceSm),
                AppCard(
                  onTap: _pickDateRange,
                  color: AppColors.surfaceAlt,
                  radius: AppSizes.radiusMd,
                  padding: const EdgeInsets.all(AppSizes.spaceMs),
                  child: Row(
                    children: [
                      AppIconBadge(
                        icon: Icons.event_outlined,
                        tone: _hasDateRange ? AppTone.primary : AppTone.neutral,
                        size: AppIconBadgeSize.sm,
                      ),
                      const SizedBox(width: AppSizes.spaceMs),
                      Expanded(
                        child: Text(
                          _hasDateRange
                              ? '${DateFormatter.formatDateShort(_startDate!)} — '
                                    '${DateFormatter.formatDateShort(_endDate!)}'
                              : 'Pilih tanggal sendiri',
                          style: _hasDateRange
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkSecondary,
                                ),
                        ),
                      ),
                      if (_hasDateRange)
                        IconButton(
                          tooltip: 'Hapus filter tanggal',
                          icon: const Icon(Icons.close_rounded),
                          iconSize: AppSizes.iconSm,
                          onPressed: () => setState(() {
                            _startDate = null;
                            _endDate = null;
                          }),
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.inkSecondary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spaceLg),

                // --- Dibayar pakai apa.
                Text('METODE BAYAR', style: AppTextStyles.eyebrow),
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
                    for (final method in const ['cash', 'noncash', 'debt'])
                      _FilterChip(
                        label: paymentMethodLabel(method),
                        icon: paymentMethodIcon(method),
                        selected: _paymentMethod == method,
                        onSelected: () => setState(() => _paymentMethod = method),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceLg),

                // --- Keadaan transaksi.
                Text('STATUS', style: AppTextStyles.eyebrow),
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
                    for (final status in const ['completed', 'debt_unpaid', 'voided'])
                      _FilterChip(
                        label: SaleStatusStyle.of(status).label,
                        icon: SaleStatusStyle.of(status).icon,
                        selected: _status == status,
                        onSelected: () => setState(() => _status = status),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceXl),

                // --- Aksi (zona jempol).
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppSizes.buttonHeightLarge,
                        child: OutlinedButton(
                          onPressed: _hasSelection ? _reset : null,
                          child: const Text('Reset'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceMs),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: AppSizes.buttonHeightLarge,
                        child: FilledButton(
                          onPressed: _apply,
                          child: const Text('Terapkan'),
                        ),
                      ),
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
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: AppSizes.iconSm,
              color: selected ? AppColors.primary : AppColors.inkSecondary,
            ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMs,
        vertical: AppSizes.spaceSm + 2,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

/// Ringkasan filter aktif dalam satu kalimat pendek — dipakai banner
/// "Filter aktif" di layar Riwayat.
String historyFilterSummary(HistoryFilter filter) {
  final parts = <String>[];
  if (filter.startDate != null && filter.endDate != null) {
    parts.add(
      '${DateFormatter.formatDateShort(filter.startDate!)} — '
      '${DateFormatter.formatDateShort(filter.endDate!)}',
    );
  } else if (filter.startDate != null) {
    parts.add('Sejak ${DateFormatter.formatDateShort(filter.startDate!)}');
  } else if (filter.endDate != null) {
    parts.add('Sampai ${DateFormatter.formatDateShort(filter.endDate!)}');
  }
  if (filter.paymentMethod != null) parts.add(paymentMethodLabel(filter.paymentMethod!));
  if (filter.status != null) parts.add(SaleStatusStyle.of(filter.status!).label);
  return parts.isEmpty ? 'Semua transaksi' : parts.join(' · ');
}
