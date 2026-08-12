import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/services/excel_export_service.dart';
import '../../../domain/entities/sale_result.dart';
import '../../pos/providers/sale_providers.dart';
import '../../products/providers/category_providers.dart';
import '../../products/providers/product_providers.dart';
import '../providers/settings_providers.dart';
import 'settings_card.dart';

/// Seksi Export Excel (plan.md Milestone 5 poin 3, architecture.md §5.2):
/// produk+stok, transaksi per rentang tanggal (2 sheet), dan laporan
/// penjualan per rentang. Pengambilan data lewat repository (I/O) terjadi
/// di sini (isolate UI); pembentukan file `.xlsx` dijalankan di ISOLATE
/// terpisah oleh [ExcelExportService] lewat `compute`.
///
/// Visual: tiap pilihan export jadi baris kartu (ikon bernada + judul +
/// penjelasan singkat + chevron), bukan tiga tombol outline seragam —
/// pengguna bisa membedakan isinya tanpa membaca ulang tiap kali.
class ExportSection extends ConsumerStatefulWidget {
  const ExportSection({super.key});

  @override
  ConsumerState<ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends ConsumerState<ExportSection> {
  bool _busy = false;
  String? _busyLabel;

  Future<void> _run(String label, Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      final path = await action();
      await ExcelExportService.share(path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export "$label" berhasil.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal export "$label": ${AppErrorMessage.from(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportProducts() async {
    await _run('Produk & Stok', () async {
      final products = await ref.read(productRepoProvider).watchAll().first;
      final categories = await ref.read(categoryRepoProvider).watchAll().first;
      final lowStockDefault = await ref.read(lowStockDefaultProvider.future);
      return ExcelExportService.exportProductsAndStock(
        products: products,
        categoryNames: {for (final c in categories) c.id: c.name},
        lowStockDefault: lowStockDefault,
      );
    });
  }

  Future<DateTimeRange?> _pickRange() {
    final now = DateTime.now();
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
        end: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  Future<List<SaleResult>> _loadSalesInRange(DateTime start, DateTime end) async {
    final saleRepo = ref.read(saleRepoProvider);
    final headers = await saleRepo.getHistory(
      startDate: start,
      endDate: end,
      limit: 100000,
      offset: 0,
    );
    final results = <SaleResult>[];
    for (final header in headers) {
      results.add(await saleRepo.getDetail(header.id));
    }
    return results;
  }

  Future<void> _exportTransactions() async {
    final range = await _pickRange();
    if (range == null || !mounted) return;
    final start = range.start;
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

    await _run('Transaksi', () async {
      final sales = await _loadSalesInRange(start, end);
      return ExcelExportService.exportTransactions(sales: sales, startDate: start, endDate: end);
    });
  }

  Future<void> _exportReport() async {
    final range = await _pickRange();
    if (range == null || !mounted) return;
    final start = range.start;
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

    await _run('Laporan Penjualan', () async {
      final sales = await _loadSalesInRange(start, end);
      return ExcelExportService.exportSalesReport(sales: sales, startDate: start, endDate: end);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: Icons.table_view_outlined,
      title: 'Export Excel',
      subtitle: 'File .xlsx tersimpan lalu langsung bisa dibagikan.',
      tone: AppTone.info,
      children: [
        if (_busy) ...[
          _ExportProgress(label: _busyLabel),
          const SizedBox(height: AppSizes.spaceMs),
        ],
        _ExportTile(
          icon: Icons.inventory_2_outlined,
          tone: AppTone.warning,
          title: 'Produk & Stok',
          description: 'Daftar barang, harga, dan sisa stok saat ini.',
          onTap: _busy ? null : _exportProducts,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        _ExportTile(
          icon: Icons.receipt_long_outlined,
          tone: AppTone.primary,
          title: 'Transaksi',
          description: 'Semua struk pada rentang tanggal pilihanmu.',
          onTap: _busy ? null : _exportTransactions,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        _ExportTile(
          icon: Icons.bar_chart_outlined,
          tone: AppTone.success,
          title: 'Laporan Penjualan',
          description: 'Ringkasan omzet & laba per rentang tanggal.',
          onTap: _busy ? null : _exportReport,
        ),
      ],
    );
  }
}

/// Baris status saat file sedang dibentuk di isolate.
class _ExportProgress extends StatelessWidget {
  const _ExportProgress({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.palette.primary50,
      borderColor: context.palette.primary100,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          const SizedBox(
            width: AppSizes.iconSm,
            height: AppSizes.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Text('Menyiapkan file "$label"…', style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Satu pilihan export sebagai baris kartu yang bisa ditekan.
class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final AppTone tone;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return AppCard(
      onTap: onTap,
      color: context.palette.surfaceAlt,
      radius: AppSizes.radiusMd,
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            tone: enabled ? tone : AppTone.neutral,
            size: AppIconBadgeSize.sm,
          ),
          const SizedBox(width: AppSizes.spaceMs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: enabled ? context.palette.ink : context.palette.inkSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          Icon(
            Icons.chevron_right_rounded,
            size: AppSizes.iconMd,
            color: context.palette.inkTertiary,
          ),
        ],
      ),
    );
  }
}
