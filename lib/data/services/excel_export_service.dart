import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/sale_result.dart';

/// Export data ke file Excel (.xlsx) — plan.md Milestone 5 poin 3,
/// architecture.md §5.2.
///
/// Tiga jenis export: [exportProductsAndStock] (produk+stok),
/// [exportTransactions] (transaksi per rentang tanggal, 2 sheet: header +
/// detail item), [exportSalesReport] (ringkasan laporan penjualan per
/// rentang). Pembentukan workbook (CPU-bound untuk data besar) dijalankan
/// di ISOLATE terpisah lewat `compute` supaya UI tidak freeze —
/// pengambilan data dari repository (I/O) tetap terjadi di isolate utama
/// SEBELUM dipanggil ke sini; service ini hanya menerima entity domain
/// murni yang sudah siap ("sendable" antar isolate: hanya tipe primitif/
/// `DateTime`/`List`/`Map`, tanpa closure/koneksi native).
///
/// File disimpan ke `<Documents>/export/` lalu bisa dibagikan lewat
/// [share].
abstract final class ExcelExportService {
  static final CellStyle _headerStyle = CellStyle(bold: true);

  // ---------------------------------------------------------------------
  // (a) Produk + stok
  // ---------------------------------------------------------------------

  /// Export daftar produk & stok. [categoryNames] memetakan `categoryId`
  /// -> nama kategori (untuk kolom "Kategori" — entity [Product] hanya
  /// menyimpan id). [lowStockDefault] adalah threshold global dari
  /// Pengaturan (`settings.low_stock_default`), dipakai untuk kolom
  /// "Status Stok" bila produk tidak punya threshold sendiri.
  static Future<String> exportProductsAndStock({
    required List<Product> products,
    required Map<int, String> categoryNames,
    required double lowStockDefault,
  }) async {
    final bytes = await compute(
      _buildProductsWorkbook,
      _ProductsExportArgs(products, categoryNames, lowStockDefault),
    );
    return _saveFile(bytes, _fileName('produk_stok'));
  }

  static List<int> _buildProductsWorkbook(_ProductsExportArgs args) {
    final excel = Excel.createExcel();
    final sheet = excel['Produk & Stok'];

    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Nama Produk'),
      TextCellValue('Barcode'),
      TextCellValue('Kategori'),
      TextCellValue('Harga Jual'),
      TextCellValue('Harga Modal'),
      TextCellValue('Stok'),
      TextCellValue('Satuan'),
      TextCellValue('Status Stok'),
      TextCellValue('Aktif'),
    ]);
    _boldRow(sheet, 0, 10);

    var no = 1;
    for (final product in args.products) {
      final threshold = product.lowStockThreshold ?? args.lowStockDefault;
      final isLowStock = product.stock <= threshold;
      sheet.appendRow([
        IntCellValue(no),
        TextCellValue(product.name),
        TextCellValue(product.barcode ?? '-'),
        TextCellValue(
          product.categoryId == null ? '-' : (args.categoryNames[product.categoryId] ?? '-'),
        ),
        IntCellValue(product.sellPrice),
        if (product.costPrice != null) IntCellValue(product.costPrice!) else TextCellValue('-'),
        DoubleCellValue(product.stock),
        TextCellValue(product.unit),
        TextCellValue(isLowStock ? 'Menipis' : 'Aman'),
        TextCellValue(product.isActive ? 'Ya' : 'Tidak'),
      ]);
      no++;
    }

    _removeDefaultSheet(excel, keep: 'Produk & Stok');
    return excel.encode()!;
  }

  // ---------------------------------------------------------------------
  // (b) Transaksi per rentang tanggal (2 sheet)
  // ---------------------------------------------------------------------

  /// Export riwayat transaksi dalam rentang [startDate]..[endDate]
  /// (inklusif) menjadi 2 sheet: "Transaksi" (header) & "Detail Item".
  /// [sales] adalah hasil `SaleRepository.getDetail` untuk setiap
  /// transaksi pada rentang tsb (header + item lengkap).
  static Future<String> exportTransactions({
    required List<SaleResult> sales,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bytes = await compute(
      _buildTransactionsWorkbook,
      _TransactionsExportArgs(sales, startDate, endDate),
    );
    return _saveFile(bytes, _fileName('transaksi_${_rangeSuffix(startDate, endDate)}'));
  }

  static List<int> _buildTransactionsWorkbook(_TransactionsExportArgs args) {
    final excel = Excel.createExcel();
    final headerSheet = excel['Transaksi'];
    final itemSheet = excel['Detail Item'];

    headerSheet.appendRow([
      TextCellValue('No'),
      TextCellValue('No. Struk'),
      TextCellValue('Tanggal'),
      TextCellValue('Metode Bayar'),
      TextCellValue('Status'),
      TextCellValue('Pelanggan'),
      TextCellValue('Subtotal'),
      TextCellValue('Diskon'),
      TextCellValue('Total'),
      TextCellValue('Dibayar'),
      TextCellValue('Kembalian'),
    ]);
    _boldRow(headerSheet, 0, 11);

    itemSheet.appendRow([
      TextCellValue('No. Struk'),
      TextCellValue('Nama Barang'),
      TextCellValue('Qty'),
      TextCellValue('Satuan'),
      TextCellValue('Harga Satuan'),
      TextCellValue('Diskon'),
      TextCellValue('Subtotal Item'),
    ]);
    _boldRow(itemSheet, 0, 7);

    var no = 1;
    for (final sale in args.sales) {
      headerSheet.appendRow([
        IntCellValue(no),
        TextCellValue(sale.invoiceNumber),
        DateTimeCellValue.fromDateTime(sale.createdAt),
        TextCellValue(_paymentMethodLabel(sale.paymentMethod)),
        TextCellValue(_statusLabel(sale.status)),
        TextCellValue(sale.customerName ?? '-'),
        IntCellValue(sale.subtotal),
        IntCellValue(sale.discount),
        IntCellValue(sale.total),
        IntCellValue(sale.paidAmount),
        IntCellValue(sale.changeAmount),
      ]);
      no++;

      for (final item in sale.items) {
        itemSheet.appendRow([
          TextCellValue(sale.invoiceNumber),
          TextCellValue(item.name),
          DoubleCellValue(item.qty),
          TextCellValue(item.unit),
          IntCellValue(item.sellPrice),
          IntCellValue(item.discount),
          IntCellValue(item.lineTotal),
        ]);
      }
    }

    _removeDefaultSheet(excel, keep: 'Transaksi');
    return excel.encode()!;
  }

  // ---------------------------------------------------------------------
  // (c) Laporan penjualan per rentang tanggal (ringkasan + produk terlaris)
  // ---------------------------------------------------------------------

  /// Export ringkasan laporan penjualan dalam rentang [startDate]..
  /// [endDate] (inklusif): total omzet, jumlah transaksi, estimasi laba
  /// kotor, breakdown per metode bayar, hutang belum lunas (sheet
  /// "Ringkasan"), dan produk terlaris (sheet "Produk Terlaris").
  ///
  /// Laba kotor dihitung dari `SaleResultItem.costPrice` — snapshot harga
  /// modal SAAT TRANSAKSI terjadi (`sale_items.cost_price`), BUKAN harga
  /// modal produk saat ini — SAMA PERSIS logikanya dengan dashboard laporan
  /// (`ReportRepositoryImpl.getSummary`): item tanpa snapshot harga modal
  /// (`costPrice == null`, termasuk seluruh item bebas) tidak diikutkan
  /// dalam estimasi laba (bukan dianggap modal Rp0).
  static Future<String> exportSalesReport({
    required List<SaleResult> sales,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bytes = await compute(
      _buildReportWorkbook,
      _ReportExportArgs(sales, startDate, endDate),
    );
    return _saveFile(bytes, _fileName('laporan_${_rangeSuffix(startDate, endDate)}'));
  }

  static List<int> _buildReportWorkbook(_ReportExportArgs args) {
    final excel = Excel.createExcel();
    final summarySheet = excel['Ringkasan'];
    final topProductSheet = excel['Produk Terlaris'];

    // Hanya transaksi TIDAK batal yang dihitung sebagai omzet.
    final activeSales = args.sales.where((s) => s.status != 'voided').toList();

    var totalOmzet = 0;
    var totalDiskon = 0;
    var estimasiLaba = 0;
    final perMetode = <String, ({int jumlah, int nilai})>{};
    var jumlahHutang = 0;
    var nilaiHutang = 0;
    final qtyByProduct = <String, double>{};
    final valueByProduct = <String, int>{};

    for (final sale in activeSales) {
      totalOmzet += sale.total;
      totalDiskon += sale.discount;

      final current = perMetode[sale.paymentMethod] ?? (jumlah: 0, nilai: 0);
      perMetode[sale.paymentMethod] = (jumlah: current.jumlah + 1, nilai: current.nilai + sale.total);

      if (sale.status == 'debt_unpaid') {
        jumlahHutang++;
        nilaiHutang += sale.total;
      }

      for (final item in sale.items) {
        qtyByProduct[item.name] = (qtyByProduct[item.name] ?? 0) + item.qty;
        valueByProduct[item.name] = (valueByProduct[item.name] ?? 0) + item.lineTotal;

        if (item.costPrice != null) {
          estimasiLaba += item.lineTotal - (item.costPrice! * item.qty).round();
        }
      }
    }

    summarySheet.appendRow([
      TextCellValue('Rentang Tanggal'),
      TextCellValue('${_formatDateLabel(args.startDate)} - ${_formatDateLabel(args.endDate)}'),
    ]);
    summarySheet.appendRow([TextCellValue('Jumlah Transaksi'), IntCellValue(activeSales.length)]);
    summarySheet.appendRow([TextCellValue('Total Omzet'), IntCellValue(totalOmzet)]);
    summarySheet.appendRow([TextCellValue('Total Diskon'), IntCellValue(totalDiskon)]);
    summarySheet.appendRow([
      TextCellValue('Estimasi Laba Kotor'),
      IntCellValue(estimasiLaba),
    ]);
    summarySheet.appendRow([TextCellValue(''), TextCellValue('')]);
    summarySheet.appendRow([
      TextCellValue('Metode Bayar'),
      TextCellValue('Jumlah Transaksi'),
      TextCellValue('Nilai'),
    ]);
    _boldRow(summarySheet, 6, 3);
    for (final entry in perMetode.entries) {
      summarySheet.appendRow([
        TextCellValue(_paymentMethodLabel(entry.key)),
        IntCellValue(entry.value.jumlah),
        IntCellValue(entry.value.nilai),
      ]);
    }
    summarySheet.appendRow([TextCellValue(''), TextCellValue('')]);
    summarySheet.appendRow([TextCellValue('Hutang Belum Lunas (jumlah)'), IntCellValue(jumlahHutang)]);
    summarySheet.appendRow([TextCellValue('Hutang Belum Lunas (nilai)'), IntCellValue(nilaiHutang)]);

    topProductSheet.appendRow([
      TextCellValue('Nama Produk'),
      TextCellValue('Qty Terjual'),
      TextCellValue('Nilai Penjualan'),
    ]);
    _boldRow(topProductSheet, 0, 3);
    final sortedNames = valueByProduct.keys.toList()
      ..sort((a, b) => valueByProduct[b]!.compareTo(valueByProduct[a]!));
    for (final name in sortedNames) {
      topProductSheet.appendRow([
        TextCellValue(name),
        DoubleCellValue(qtyByProduct[name] ?? 0),
        IntCellValue(valueByProduct[name] ?? 0),
      ]);
    }

    _removeDefaultSheet(excel, keep: 'Ringkasan');
    return excel.encode()!;
  }

  // ---------------------------------------------------------------------
  // Helper bersama
  // ---------------------------------------------------------------------

  static void _boldRow(Sheet sheet, int rowIndex, int columnCount) {
    for (var col = 0; col < columnCount; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex))
          .cellStyle = _headerStyle;
    }
  }

  /// `Excel.createExcel()` selalu membuat sheet default `'Sheet1'` — hapus
  /// supaya tidak muncul sebagai sheet kosong ekstra di file hasil export,
  /// KECUALI bila sheet pertama kita kebetulan bernama `'Sheet1'` juga.
  static void _removeDefaultSheet(Excel excel, {required String keep}) {
    if (excel.sheets.containsKey('Sheet1') && keep != 'Sheet1') {
      excel.delete('Sheet1');
    }
  }

  static String _paymentMethodLabel(String method) {
    return switch (method) {
      'cash' => 'Tunai',
      'noncash' => 'Non-tunai',
      'debt' => 'Hutang',
      _ => method,
    };
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'completed' => 'Lunas',
      'debt_unpaid' => 'Hutang',
      'voided' => 'Batal',
      _ => status,
    };
  }

  /// Format tanggal Indonesia sederhana TANPA bergantung pada `intl`
  /// (`DateFormatter` butuh `initializeDateFormatting` yang dipanggil di
  /// `main()` isolate utama — TIDAK ikut terbawa ke isolate baru yang
  /// dipakai `compute` di sini, jadi wajib mandiri).
  static const List<String> _bulanIndonesia = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static String _formatDateLabel(DateTime date) =>
      '${date.day} ${_bulanIndonesia[date.month - 1]} ${date.year}';

  static String _rangeSuffix(DateTime start, DateTime end) {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return '${ymd(start)}_${ymd(end)}';
  }

  static String _fileName(String prefix) {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '${prefix}_$stamp.xlsx';
  }

  static Future<String> _saveFile(List<int> bytes, String fileName) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${docsDir.path}/export');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Bagikan file hasil export lewat `share_plus`.
  static Future<void> share(String filePath, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], subject: subject ?? 'Export Kasir Warung'),
    );
  }
}

class _ProductsExportArgs {
  const _ProductsExportArgs(this.products, this.categoryNames, this.lowStockDefault);

  final List<Product> products;
  final Map<int, String> categoryNames;
  final double lowStockDefault;
}

class _TransactionsExportArgs {
  const _TransactionsExportArgs(this.sales, this.startDate, this.endDate);

  final List<SaleResult> sales;
  final DateTime startDate;
  final DateTime endDate;
}

class _ReportExportArgs {
  const _ReportExportArgs(this.sales, this.startDate, this.endDate);

  final List<SaleResult> sales;
  final DateTime startDate;
  final DateTime endDate;
}
