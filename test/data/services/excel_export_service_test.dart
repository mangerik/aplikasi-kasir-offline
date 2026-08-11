import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/services/excel_export_service.dart';
import 'package:kasir_warung/domain/entities/product.dart';
import 'package:kasir_warung/domain/entities/sale_result.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Fake `path_provider` — [ExcelExportService] menyimpan file lewat
/// `getApplicationDocumentsDirectory()`, yang di lingkungan `flutter_test`
/// (bukan device sungguhan) tidak punya implementasi platform channel
/// bawaan. Arahkan ke folder temp sistem supaya test bisa membaca ulang
/// file hasil export (plan.md Milestone 5 poin 8: "export service
/// menghasilkan struktur xlsx benar — baca ulang file di test").
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('excel_export_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Product buildProduct({
    required int id,
    required String name,
    int? categoryId,
    double stock = 10,
    double? lowStockThreshold,
    int costPrice = 1000,
  }) {
    final now = DateTime(2026, 8, 1);
    return Product(
      id: id,
      name: name,
      categoryId: categoryId,
      sellPrice: 5000,
      costPrice: costPrice,
      stock: stock,
      unit: 'pcs',
      lowStockThreshold: lowStockThreshold,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  SaleResult buildSale({
    required int saleId,
    required String invoiceNumber,
    String paymentMethod = 'cash',
    String status = 'completed',
    int total = 10000,
  }) {
    return SaleResult(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      subtotal: total,
      discount: 0,
      total: total,
      paymentMethod: paymentMethod,
      paidAmount: total,
      changeAmount: 0,
      createdAt: DateTime(2026, 8, 5, 10, 30),
      status: status,
      items: [
        const SaleResultItem(
          productId: 1,
          name: 'Teh Botol',
          unit: 'pcs',
          qty: 2,
          sellPrice: 5000,
          discount: 0,
          lineTotal: 10000,
        ),
      ],
    );
  }

  group('ExcelExportService.exportProductsAndStock', () {
    test('menghasilkan file .xlsx dengan sheet & header kolom Bahasa Indonesia', () async {
      final products = [
        buildProduct(id: 1, name: 'Beras 5kg', categoryId: 1, stock: 20),
        buildProduct(id: 2, name: 'Teh Botol', categoryId: 2, stock: 1, lowStockThreshold: 5),
      ];

      final path = await ExcelExportService.exportProductsAndStock(
        products: products,
        categoryNames: {1: 'Sembako', 2: 'Minuman'},
        lowStockDefault: 5,
      );

      final file = File(path);
      expect(await file.exists(), isTrue);
      expect(path.endsWith('.xlsx'), isTrue);

      final excel = Excel.decodeBytes(await file.readAsBytes());
      final sheet = excel['Produk & Stok'];

      final header = sheet.row(0).map((c) => c?.value).toList();
      expect(header, [
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

      final row1 = sheet.row(1).map((c) => c?.value).toList();
      expect(row1[1], TextCellValue('Beras 5kg'));
      expect(row1[3], TextCellValue('Sembako'));
      expect(row1[4], const IntCellValue(5000)); // angka, bukan teks
      expect(row1[8], TextCellValue('Aman'));

      final row2 = sheet.row(2).map((c) => c?.value).toList();
      expect(row2[1], TextCellValue('Teh Botol'));
      expect(row2[8], TextCellValue('Menipis')); // stok 1 <= threshold 5
    });

    test('produk tanpa threshold sendiri memakai lowStockDefault dari Pengaturan', () async {
      final products = [buildProduct(id: 1, name: 'Gula 1kg', stock: 3)];

      final path = await ExcelExportService.exportProductsAndStock(
        products: products,
        categoryNames: const {},
        lowStockDefault: 10, // stok 3 <= default 10 -> menipis
      );

      final excel = Excel.decodeBytes(await File(path).readAsBytes());
      final row1 = excel['Produk & Stok'].row(1).map((c) => c?.value).toList();
      expect(row1[8], TextCellValue('Menipis'));
    });
  });

  group('ExcelExportService.exportTransactions', () {
    test('menghasilkan 2 sheet: Transaksi (header) & Detail Item, angka sebagai number', () async {
      final sales = [
        buildSale(saleId: 1, invoiceNumber: '20260805-0001'),
        buildSale(saleId: 2, invoiceNumber: '20260805-0002', paymentMethod: 'debt', status: 'debt_unpaid'),
      ];

      final path = await ExcelExportService.exportTransactions(
        sales: sales,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      final excel = Excel.decodeBytes(await File(path).readAsBytes());
      expect(excel.sheets.keys, containsAll(['Transaksi', 'Detail Item']));

      final headerSheet = excel['Transaksi'];
      expect(headerSheet.maxRows, 3); // 1 header + 2 transaksi
      final row1 = headerSheet.row(1).map((c) => c?.value).toList();
      expect(row1[1], TextCellValue('20260805-0001'));
      expect(row1[3], TextCellValue('Tunai'));
      expect(row1[4], TextCellValue('Lunas'));
      expect(row1[8], const IntCellValue(10000)); // total sebagai number

      final row2 = headerSheet.row(2).map((c) => c?.value).toList();
      expect(row2[3], TextCellValue('Hutang'));
      expect(row2[4], TextCellValue('Hutang'));

      final itemSheet = excel['Detail Item'];
      expect(itemSheet.maxRows, 3); // 1 header + 2 item (1 per transaksi)
      final itemRow1 = itemSheet.row(1).map((c) => c?.value).toList();
      expect(itemRow1[0], TextCellValue('20260805-0001'));
      expect(itemRow1[1], TextCellValue('Teh Botol'));
      expect(_asNum(itemRow1[2]), 2); // qty sebagai number (bulat -> IntCellValue saat encode/decode)
    });
  });

  group('ExcelExportService.exportSalesReport', () {
    test('sheet Ringkasan berisi total omzet & per metode bayar; transaksi voided TIDAK dihitung', () async {
      final sales = [
        buildSale(saleId: 1, invoiceNumber: '20260805-0001', total: 10000),
        buildSale(saleId: 2, invoiceNumber: '20260805-0002', total: 10000, status: 'voided'),
      ];

      final path = await ExcelExportService.exportSalesReport(
        sales: sales,
        productCostPriceById: {1: 3000},
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      final excel = Excel.decodeBytes(await File(path).readAsBytes());
      final summary = excel['Ringkasan'];
      final rows = summary.rows.map((r) => r.map((c) => c?.value).toList()).toList();

      final jumlahTransaksiRow = rows.firstWhere((r) => r[0] == TextCellValue('Jumlah Transaksi'));
      expect(jumlahTransaksiRow[1], const IntCellValue(1)); // yang voided tidak dihitung

      final omzetRow = rows.firstWhere((r) => r[0] == TextCellValue('Total Omzet'));
      expect(omzetRow[1], const IntCellValue(10000));

      expect(excel.sheets.keys, contains('Produk Terlaris'));
      final topProduct = excel['Produk Terlaris'];
      final topRow1 = topProduct.row(1).map((c) => c?.value).toList();
      expect(topRow1[0], TextCellValue('Teh Botol'));
      expect(_asNum(topRow1[1]), 2); // qty dari 1 transaksi aktif saja
    });
  });
}

/// Angka bulat ditulis lewat `IntCellValue`/`DoubleCellValue`, tapi format
/// `.xlsx` sendiri tidak membedakan int/double (keduanya sekadar "number")
/// — setelah encode+decode, nilai bulat (mis. qty 2.0) bisa terbaca ulang
/// sebagai `IntCellValue`. Helper ini membandingkan NILAI numeriknya saja,
/// bukan subtipe `CellValue`-nya, karena yang dipersyaratkan (plan.md
/// Milestone 5 poin 3) adalah "angka sebagai number bukan teks" — bukan
/// int vs double persis.
num? _asNum(CellValue? value) => switch (value) {
  IntCellValue(:final value) => value,
  DoubleCellValue(:final value) => value,
  _ => null,
};
