import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
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
      ).showSnackBar(SnackBar(content: Text('Gagal export "$label": $e')));
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
      title: 'Export Excel',
      subtitle: 'File .xlsx tersimpan lalu langsung bisa dibagikan.',
      children: [
        if (_busy) ...[
          LinearProgressIndicator(minHeight: 4),
          const SizedBox(height: AppSizes.spaceSm),
          Text('Membuat file "$_busyLabel"…', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSizes.spaceSm),
        ],
        _ExportButton(
          icon: Icons.inventory_2_outlined,
          label: 'Produk & Stok',
          onPressed: _busy ? null : _exportProducts,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        _ExportButton(
          icon: Icons.receipt_long_outlined,
          label: 'Transaksi per Rentang Tanggal',
          onPressed: _busy ? null : _exportTransactions,
        ),
        const SizedBox(height: AppSizes.spaceSm),
        _ExportButton(
          icon: Icons.bar_chart_outlined,
          label: 'Laporan Penjualan per Rentang Tanggal',
          onPressed: _busy ? null : _exportReport,
        ),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.minTouchTarget,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}
