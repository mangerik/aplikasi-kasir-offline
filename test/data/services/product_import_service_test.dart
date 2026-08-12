import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/services/excel_export_service.dart';
import 'package:kasir_warung/data/services/product_import_service.dart';
import 'package:kasir_warung/domain/entities/product.dart';
import 'package:kasir_warung/domain/entities/product_import.dart';
import 'package:kasir_warung/domain/repositories/import_exceptions.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Uji parser & normalisasi impor Excel (PRD v1.1 §4, Milestone 9).
///
/// Bentuknya sengaja **tabel kasus** untuk normalisasi angka: itulah kelas
/// bug yang paling mahal di fitur ini — "1.500" yang terbaca 1,5 berarti
/// harga rokok salah 1.000 kali lipat dan baru ketahuan di depan pembeli
/// (mitigasi risiko PRD §4.8).
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  // -------------------------------------------------------------------
  // Helper pembuat workbook
  // -------------------------------------------------------------------

  Uint8List workbookBytes({
    required String sheetName,
    required List<List<CellValue?>> rows,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];
    for (final row in rows) {
      sheet.appendRow(row);
    }
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }
    return Uint8List.fromList(excel.encode()!);
  }

  ProductImportParseResult parse(
    Uint8List bytes, {
    String fileName = 'produk.xlsx',
  }) {
    return ProductImportService.parseBytes(
      ProductImportParseArgs(bytes, fileName),
    );
  }

  List<CellValue?> textRow(List<String> values) => [
    for (final value in values) TextCellValue(value),
  ];

  // ===================================================================
  // Normalisasi angka (AC-4.10, AC-4.11)
  // ===================================================================

  group('normalisasi harga (AC-4.10) — titik SELALU pemisah ribuan', () {
    const cases = <String, double>{
      'Rp 12.000': 12000,
      'rp12.000': 12000,
      'Rp. 12.000': 12000,
      '12.000': 12000,
      '12000': 12000,
      '12 000': 12000,
      '1.500': 1500,
      '1.234.567': 1234567,
      '12.500,5': 12500.5,
      '0': 0,
    };

    cases.forEach((input, expected) {
      test('"$input" -> $expected', () {
        expect(ProductImportService.parsePrice(input).value, expected);
      });
    });

    test('spasi non-breaking (U+00A0) hasil format intl ikut terbaca', () {
      expect(ProductImportService.parsePrice('Rp 12.000').value, 12000);
    });

    test('sel kosong dibedakan dari sel tidak terbaca', () {
      expect(ProductImportService.parsePrice('').isBlank, isTrue);
      expect(ProductImportService.parsePrice('-').isBlank, isTrue);
      expect(ProductImportService.parsePrice('dua belas ribu').invalid, isTrue);
      expect(ProductImportService.parsePrice('12rb').invalid, isTrue);
    });

    test('nilai negatif tetap terbaca negatif (tidak diam-diam jadi positif)', () {
      expect(ProductImportService.parsePrice('-5000').value, -5000);
      expect(ProductImportService.parsePrice('-Rp5.000').value, -5000);
    });
  });

  group('normalisasi stok (AC-4.11) — koma & titik sama-sama desimal', () {
    const cases = <String, double>{
      '1,5': 1.5,
      '1.5': 1.5,
      '1,50': 1.5,
      '12.500,5': 12500.5,
      '1.500': 1500,
      '1.234.567': 1234567,
      '10': 10,
    };

    cases.forEach((input, expected) {
      test('"$input" -> $expected', () {
        expect(ProductImportService.parseQuantity(input).value, expected);
      });
    });
  });

  group('normalisasi kolom Aktif', () {
    test('bentuk yang berarti AKTIF', () {
      for (final raw in ['Ya', 'ya', 'YA', 'Y', '1', 'true', 'aktif']) {
        expect(ProductImportService.parseBoolean(raw), isTrue, reason: raw);
      }
    });

    test('bentuk yang berarti NONAKTIF', () {
      for (final raw in ['Tidak', 'tidak', 'T', 'N', '0', 'false']) {
        expect(ProductImportService.parseBoolean(raw), isFalse, reason: raw);
      }
    });

    test('bentuk asing tidak ditebak', () {
      expect(ProductImportService.parseBoolean('mungkin'), isNull);
    });
  });

  // ===================================================================
  // Header (AC-4.3, AC-4.4)
  // ===================================================================

  group('pencocokan header', () {
    test('urutan kolom diacak & huruf besar-kecil berbeda tetap terbaca '
        '(AC-4.3)', () {
      final bytes = workbookBytes(
        sheetName: 'Produk',
        rows: [
          textRow(['AKTIF', 'harga JUAL', 'Barcode', '  nama produk  ', 'Stok']),
          [
            TextCellValue('Tidak'),
            TextCellValue('Rp 12.000'),
            TextCellValue('899123'),
            TextCellValue('Kopi Sachet'),
            TextCellValue('7'),
          ],
        ],
      );

      final result = parse(bytes);
      expect(result.rows, hasLength(1));
      final row = result.rows.single;
      expect(row.name, 'Kopi Sachet');
      expect(row.sellPrice, 12000);
      expect(row.barcode, '899123');
      expect(row.stock, 7);
      expect(row.isActive, isFalse);
      expect(row.issues, isEmpty);
    });

    test('kolom tak dikenal diabaikan diam-diam', () {
      final bytes = workbookBytes(
        sheetName: 'Produk',
        rows: [
          textRow(['No', 'Nama Produk', 'Catatan Pribadi', 'Harga Jual', 'Status Stok']),
          textRow(['1', 'Teh Kotak', 'stok di gudang belakang', '5000', 'Aman']),
        ],
      );

      final result = parse(bytes);
      expect(result.rows.single.name, 'Teh Kotak');
      expect(result.rows.single.sellPrice, 5000);
      expect(result.columns, isNot(contains(ProductImportColumn.stock)));
    });

    test('kolom wajib hilang -> impor ditolak sebelum apa pun diproses, '
        'pesan menyebut kolomnya (AC-4.4)', () {
      final bytes = workbookBytes(
        sheetName: 'Produk',
        rows: [
          textRow(['Nama Produk', 'Barcode']),
          textRow(['Kopi Sachet', '899123']),
        ],
      );

      expect(
        () => parse(bytes),
        throwsA(
          isA<KolomWajibHilangException>().having(
            (e) => e.toString(),
            'pesan',
            contains('Harga Jual'),
          ),
        ),
      );
    });

    test('sheet bernama Produk dipakai walau bukan sheet pertama', () {
      final excel = Excel.createExcel();
      final lain = excel['Catatan'];
      lain.appendRow(textRow(['ini bukan data produk']));
      final produk = excel['Produk'];
      produk.appendRow(textRow(['Nama Produk', 'Harga Jual']));
      produk.appendRow(textRow(['Gula Pasir', '15.500']));
      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      final result = parse(Uint8List.fromList(excel.encode()!));
      expect(result.sheetName, 'Produk');
      expect(result.rows.single.sellPrice, 15500);
    });
  });

  // ===================================================================
  // Masalah per baris (PRD §4.3.D, AC-4.5)
  // ===================================================================

  group('masalah per baris', () {
    ProductImportParseResult parseRows(List<List<CellValue?>> dataRows) {
      return parse(
        workbookBytes(
          sheetName: 'Produk',
          rows: [
            textRow([
              'Nama Produk',
              'Barcode',
              'Kategori',
              'Harga Jual',
              'Harga Modal',
              'Stok',
              'Satuan',
              'Batas Stok Menipis',
              'Aktif',
            ]),
            ...dataRows,
          ],
        ),
      );
    }

    test('nama kosong & harga jual kosong = ERROR (baris dilewati)', () {
      final result = parseRows([
        textRow(['', '', '', '5000', '', '', '', '', '']),
        textRow(['Gula Pasir', '', '', '', '', '', '', '', '']),
      ]);

      expect(result.rows[0].hasError, isTrue);
      expect(result.rows[0].issues.first.message, contains('Nama produk'));
      expect(result.rows[1].hasError, isTrue);
      expect(result.rows[1].issues.first.message, contains('Harga jual'));
    });

    test('harga berpecahan = PERINGATAN + dibulatkan, bukan error', () {
      final result = parseRows([
        textRow(['Beras', '', '', '12.500,5', '', '', '', '', '']),
      ]);

      final row = result.rows.single;
      expect(row.hasError, isFalse);
      expect(row.sellPrice, 12501);
      expect(row.hasWarning, isTrue);
      expect(row.issues.single.message, contains('dibulatkan'));
    });

    test('harga modal > harga jual = PERINGATAN, baris tetap masuk', () {
      final result = parseRows([
        textRow(['Minyak', '', '', '18000', '20000', '', '', '', '']),
      ]);

      final row = result.rows.single;
      expect(row.hasError, isFalse);
      expect(row.hasWarning, isTrue);
      expect(
        row.issues.map((i) => i.message).join(),
        contains('lebih besar daripada harga jual'),
      );
    });

    test('satuan lebih dari 10 karakter dipotong + peringatan', () {
      final result = parseRows([
        textRow(['Sabun', '', '', '3000', '', '', 'bungkus besar', '', '']),
      ]);

      final row = result.rows.single;
      expect(row.unit, 'bungkus be');
      expect(row.unit!.length, lessThanOrEqualTo(10));
      expect(row.hasWarning, isTrue);
    });

    test('nama lebih dari 100 karakter = ERROR', () {
      final result = parseRows([
        textRow([List.filled(101, 'a').join(), '', '', '5000', '', '', '', '', '']),
      ]);
      expect(result.rows.single.hasError, isTrue);
    });

    test('stok tidak terbaca hanya jadi peringatan — baris tetap diimpor', () {
      final result = parseRows([
        textRow(['Sabun', '', '', '3000', '', 'banyak', '', '', '']),
      ]);

      final row = result.rows.single;
      expect(row.hasError, isFalse);
      expect(row.stock, isNull);
      expect(row.hasWarning, isTrue);
    });

    test('barcode ganda di dalam file: KEDUA baris error & pesan menyebut '
        'kedua nomor barisnya (AC-4.5)', () {
      final result = parseRows([
        textRow(['Kopi A', '899123', '', '2000', '', '', '', '', '']),
        textRow(['Teh B', '888', '', '3000', '', '', '', '', '']),
        textRow(['Kopi A duplikat', '899123', '', '2500', '', '', '', '', '']),
      ]);

      final duplicates = result.rows.where((r) => r.barcode == '899123').toList();
      expect(duplicates, hasLength(2));
      for (final row in duplicates) {
        expect(row.hasError, isTrue);
        final message = row.issues.map((i) => i.message).join();
        expect(message, contains('899123'));
        expect(message, contains('baris 2'));
        expect(message, contains('4'));
      }
      // Baris lain tidak ikut terseret.
      expect(result.rows[1].hasError, isFalse);
    });

    test('baris kosong di ekor file diabaikan, tidak jadi baris bermasalah', () {
      final result = parseRows([
        textRow(['Gula', '', '', '15000', '', '', '', '', '']),
        textRow(['', '', '', '', '', '', '', '', '']),
        textRow(['', '', '', '', '', '', '', '', '']),
      ]);
      expect(result.rows, hasLength(1));
    });
  });

  // ===================================================================
  // Batas & file rusak (AC-4.13, AC-4.14)
  // ===================================================================

  group('penolakan file', () {
    test('file > 5.000 baris ditolak dengan saran memecah file (AC-4.13)', () {
      final rows = <List<CellValue?>>[
        textRow(['Nama Produk', 'Harga Jual']),
        for (var i = 0; i < ProductImportService.maxRows + 1; i++)
          [TextCellValue('Produk $i'), IntCellValue(1000 + i)],
      ];

      expect(
        () => parse(workbookBytes(sheetName: 'Produk', rows: rows)),
        throwsA(
          isA<FileImporTerlaluBesarException>().having(
            (e) => e.toString(),
            'pesan',
            allOf(contains('5000'), contains('Pecah file')),
          ),
        ),
      );
    });

    test('tepat 5.000 baris masih diterima', () {
      final rows = <List<CellValue?>>[
        textRow(['Nama Produk', 'Harga Jual']),
        for (var i = 0; i < ProductImportService.maxRows; i++)
          [TextCellValue('Produk $i'), IntCellValue(1000)],
      ];
      expect(
        parse(workbookBytes(sheetName: 'Produk', rows: rows)).rows,
        hasLength(ProductImportService.maxRows),
      );
    });

    test('file rusak / bukan xlsx -> pesan Bahasa Indonesia, tanpa crash '
        '(AC-4.14)', () {
      final bukanXlsx = Uint8List.fromList('nama,harga\nkopi,2000\n'.codeUnits);
      expect(
        () => parse(bukanXlsx),
        throwsA(
          isA<FileImporTidakValidException>().having(
            (e) => e.toString(),
            'pesan',
            allOf(contains('tidak bisa dibaca'), contains('password')),
          ),
        ),
      );
    });

    test('file tanpa satu pun baris data ditolak dengan pesan yang jelas', () {
      final bytes = workbookBytes(
        sheetName: 'Produk',
        rows: [textRow(['Nama Produk', 'Harga Jual'])],
      );
      expect(() => parse(bytes), throwsA(isA<FileImporKosongException>()));
    });

    test('parseFile menolak ekstensi selain .xlsx sebelum membaca isinya', () async {
      final dir = await Directory.systemTemp.createTemp('impor_ext_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/produk.csv');
      await file.writeAsString('nama,harga');

      expect(
        () => ProductImportService.parseFile(file.path),
        throwsA(isA<FileImporTidakValidException>()),
      );
    });
  });

  // ===================================================================
  // Template (AC-4.1) & kompatibilitas file export (AC-4.2)
  // ===================================================================

  group('template', () {
    late Uint8List templateBytes;

    setUp(() {
      templateBytes = Uint8List.fromList(ProductImportService.buildTemplateBytes());
    });

    test('berisi dua sheet: Produk (9 kolom PRD §4.3.A) & Petunjuk', () {
      final excel = Excel.decodeBytes(templateBytes);
      expect(excel.tables.keys, containsAll(<String>['Produk', 'Petunjuk']));
      expect(excel.tables.keys, isNot(contains('Sheet1')));

      final headers = [
        for (final cell in excel.tables['Produk']!.rows.first)
          cell?.value.toString(),
      ];
      expect(headers, [
        for (final column in ProductImportColumn.values) column.header,
      ]);
      expect(excel.tables['Petunjuk']!.rows.length, greaterThan(10));
    });

    test('baris contoh template dilewati parser — template polos tidak '
        'menghasilkan produk palsu', () {
      expect(
        () => parse(templateBytes),
        throwsA(isA<FileImporKosongException>()),
      );
    });

    test('template yang diisi 3 baris valid menghasilkan 3 baris siap impor '
        '(AC-4.1)', () {
      final excel = Excel.decodeBytes(templateBytes);
      final sheet = excel['Produk'];
      sheet.appendRow([
        TextCellValue('Indomie Goreng'),
        TextCellValue('8998866200011'),
        TextCellValue('Mie Instan'),
        TextCellValue('Rp 3.500'),
        TextCellValue('3.000'),
        TextCellValue('24'),
        TextCellValue('pcs'),
        TextCellValue('5'),
        TextCellValue('Ya'),
      ]);
      sheet.appendRow([
        TextCellValue('Beras Ramos'),
        TextCellValue(''),
        TextCellValue('Sembako'),
        TextCellValue('68.000'),
        TextCellValue(''),
        TextCellValue('1,5'),
        TextCellValue('sak'),
        TextCellValue(''),
        TextCellValue(''),
      ]);
      sheet.appendRow([
        TextCellValue('Gula Pasir'),
        TextCellValue('899777'),
        TextCellValue('Sembako'),
        TextCellValue('15500'),
        TextCellValue('14000'),
        TextCellValue('2.5'),
        TextCellValue('kg'),
        TextCellValue('3'),
        TextCellValue('Tidak'),
      ]);

      final result = parse(Uint8List.fromList(excel.encode()!));
      expect(result.rows, hasLength(3));
      expect(result.rows.every((r) => !r.hasError), isTrue);
      expect(result.rows[0].sellPrice, 3500);
      expect(result.rows[0].costPrice, 3000);
      expect(result.rows[1].stock, 1.5);
      expect(result.rows[1].isActive, isNull);
      expect(result.rows[2].stock, 2.5);
      expect(result.rows[2].isActive, isFalse);
      expect(result.rows[2].lowStockThreshold, 3);
    });
  });

  group('kompatibilitas file hasil export v1.0 (AC-4.2)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('impor_export_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('produk_stok.xlsx hasil ExcelExportService bisa diimpor apa adanya '
        '— kolom No & Status Stok diabaikan', () async {
      final now = DateTime(2026, 8, 1);
      final products = [
        Product(
          id: 1,
          name: 'Kopi Kapal Api',
          barcode: '8991002101234',
          categoryId: 7,
          sellPrice: 2500,
          costPrice: 2000,
          stock: 40,
          unit: 'sachet',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        // Produk tanpa barcode, tanpa kategori, tanpa harga modal -> export
        // menuliskannya sebagai "-" yang WAJIB dibaca ulang sebagai kosong.
        Product(
          id: 2,
          name: 'Gorengan',
          sellPrice: 1000,
          stock: 12.5,
          unit: 'pcs',
          isActive: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final path = await ExcelExportService.exportProductsAndStock(
        products: products,
        categoryNames: {7: 'Minuman'},
        lowStockDefault: 5,
      );
      final bytes = Uint8List.fromList(await File(path).readAsBytes());

      final result = parse(bytes, fileName: 'produk_stok.xlsx');
      expect(result.sheetName, 'Produk & Stok');
      expect(result.rows, hasLength(2));

      final kopi = result.rows[0];
      expect(kopi.name, 'Kopi Kapal Api');
      expect(kopi.barcode, '8991002101234');
      expect(kopi.categoryName, 'Minuman');
      expect(kopi.sellPrice, 2500);
      expect(kopi.costPrice, 2000);
      expect(kopi.stock, 40);
      expect(kopi.unit, 'sachet');
      expect(kopi.isActive, isTrue);
      expect(kopi.hasError, isFalse);

      final gorengan = result.rows[1];
      expect(gorengan.barcode, isNull, reason: '"-" berarti tidak diisi');
      expect(gorengan.categoryName, isNull);
      expect(gorengan.costPrice, isNull);
      expect(gorengan.stock, 12.5);
      expect(gorengan.isActive, isFalse);

      // Kolom yang memang tidak ada di file export tidak boleh dianggap ada
      // (kalau dianggap ada, impor ulang akan menghapus threshold produk).
      expect(
        result.columns,
        isNot(contains(ProductImportColumn.lowStockThreshold)),
      );
    });
  });

  // ===================================================================
  // Pratinjau (buildPlan) — PRD §4.3.E, AC-4.6, AC-4.7, AC-4.9
  // ===================================================================

  group('buildPlan', () {
    ProductImportParseResult parseCatalog() => parse(
      workbookBytes(
        sheetName: 'Produk',
        rows: [
          textRow(['Nama Produk', 'Barcode', 'Kategori', 'Harga Jual']),
          textRow(['Kopi Kapal Api', '899123', 'Minuman', '2500']),
          textRow(['Produk Baru', '777999', 'Snack', '5000']),
          textRow(['Tanpa Barcode', '', 'Snack', '1000']),
          textRow(['', '', '', '']),
        ],
      ),
    );

    const lookup = ProductImportLookup(
      productIdByBarcode: {'899123': 11},
      activeProductNames: {'tanpa barcode'},
      categoryNames: {'minuman'},
    );

    test('mode Perbarui (default): barcode yang sudah ada -> diperbarui '
        '(AC-4.6)', () {
      final plan = ProductImportService.buildPlan(
        parse: parseCatalog(),
        options: const ProductImportOptions(),
        lookup: lookup,
      );

      expect(plan.updateCount, 1);
      expect(plan.createCount, 2);
      expect(plan.skipCount, 0);
      expect(plan.importableCount, 3);
      expect(plan.rows.first.existingProductId, 11);
    });

    test('mode Lewati: barcode yang sudah ada tidak ikut ditulis (AC-4.7)', () {
      final plan = ProductImportService.buildPlan(
        parse: parseCatalog(),
        options: const ProductImportOptions(
          duplicateMode: ProductImportDuplicateMode.skip,
        ),
        lookup: lookup,
      );

      expect(plan.skipCount, 1);
      expect(plan.updateCount, 0);
      expect(plan.importableCount, 2);
      expect(
        plan.importableRows.map((r) => r.barcode),
        isNot(contains('899123')),
      );
    });

    test('kategori baru dikumpulkan sekali saja (AC-4.9)', () {
      final plan = ProductImportService.buildPlan(
        parse: parseCatalog(),
        options: const ProductImportOptions(),
        lookup: lookup,
      );
      // "Snack" muncul di dua baris, "Minuman" sudah ada di database.
      expect(plan.newCategoryNames, ['Snack']);
    });

    test('opsi kategori otomatis MATI -> peringatan, produk tetap masuk '
        'tanpa kategori (AC-4.9)', () {
      final plan = ProductImportService.buildPlan(
        parse: parseCatalog(),
        options: const ProductImportOptions(autoCreateCategory: false),
        lookup: lookup,
      );

      expect(plan.newCategoryNames, isEmpty);
      expect(plan.importableCount, 3);
      final snackRow = plan.rows.firstWhere((r) => r.row.name == 'Produk Baru');
      expect(snackRow.hasWarning, isTrue);
      expect(
        snackRow.issues.map((i) => i.message).join(),
        contains('Buat kategori baru otomatis'),
      );
    });

    test('baris tanpa barcode bernama sama dengan produk aktif = peringatan, '
        'tetap dibuat sebagai produk BARU (K-4.3)', () {
      final plan = ProductImportService.buildPlan(
        parse: parseCatalog(),
        options: const ProductImportOptions(),
        lookup: lookup,
      );

      final row = plan.rows.firstWhere((r) => r.row.name == 'Tanpa Barcode');
      expect(row.action, ProductImportAction.create);
      expect(row.hasWarning, isTrue);
      expect(
        row.issues.map((i) => i.message).join(),
        contains('Sudah ada produk aktif'),
      );
    });

    test('baris bermasalah tidak pernah masuk daftar yang akan ditulis', () {
      final parseResult = parse(
        workbookBytes(
          sheetName: 'Produk',
          rows: [
            textRow(['Nama Produk', 'Harga Jual']),
            textRow(['Produk Sehat', '1000']),
            textRow(['Tanpa Harga', '']),
          ],
        ),
      );
      final plan = ProductImportService.buildPlan(
        parse: parseResult,
        options: const ProductImportOptions(),
        lookup: const ProductImportLookup.empty(),
      );

      expect(plan.errorCount, 1);
      expect(plan.importableRows, hasLength(1));
      expect(plan.importableRows.single.name, 'Produk Sehat');
      expect(plan.problemRows, hasLength(1));
    });
  });

  // ===================================================================
  // Laporan baris bermasalah (AC-4.17)
  // ===================================================================

  group('laporan baris bermasalah (AC-4.17)', () {
    test('berisi nomor baris Excel, isi baris asli, dan alasan Bahasa '
        'Indonesia', () {
      final parseResult = parse(
        workbookBytes(
          sheetName: 'Produk',
          rows: [
            textRow(['Nama Produk', 'Barcode', 'Harga Jual']),
            textRow(['Kopi Sachet', '899123', 'dua ribu']),
          ],
        ),
      );
      final plan = ProductImportService.buildPlan(
        parse: parseResult,
        options: const ProductImportOptions(),
        lookup: const ProductImportLookup.empty(),
      );

      final bytes = ProductImportService.buildIssueReportBytes(
        ProductImportReportArgs(headers: parseResult.headers, rows: plan.problemRows),
      );
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['Baris Bermasalah']!;

      expect(sheet.rows, hasLength(2));
      final laporan = sheet.rows[1].map((c) => c?.value.toString() ?? '').toList();
      expect(laporan[0], '2', reason: 'nomor baris seperti di Excel');
      expect(laporan[1], 'Dilewati');
      expect(laporan, contains('Kopi Sachet'));
      expect(laporan, contains('dua ribu'), reason: 'isi baris ASLI');
      expect(laporan.last, contains('tidak terbaca'));
    });
  });
}
