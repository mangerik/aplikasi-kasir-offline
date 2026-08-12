import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/product_import.dart';
import '../../domain/repositories/import_exceptions.dart';

/// Impor produk dari file Excel `.xlsx` (PRD v1.1 §4, plan-v1.1.md M9).
///
/// Tiga tugas:
/// 1. [saveTemplate] — membuat `template_produk.xlsx` (sheet `Produk` +
///    `Petunjuk`) memakai package `excel` yang SUDAH ada di proyek; tidak
///    ada dependency baru untuk fitur ini (K-4.1).
/// 2. [parseFile] — membaca & memvalidasi file pengguna. Pekerjaan berat
///    (dekompresi zip + parsing XML + normalisasi ribuan sel) dijalankan
///    di ISOLATE lewat `compute`, pola persis [ExcelExportService]: hanya
///    tipe "sendable" yang menyeberang isolate, tanpa closure/koneksi
///    native (K-4.2). Penulisan database TETAP di isolate utama.
/// 3. [buildPlan] & [saveIssueReport] — menyusun pratinjau (dibandingkan
///    dengan isi database) dan laporan baris bermasalah.
///
/// Service ini TIDAK PERNAH menyentuh database. Penulisan dilakukan
/// `ProductRepository.importProducts` dalam satu transaksi (K-4.5).
abstract final class ProductImportService {
  /// Batas baris produk per file (K-4.4, AC-4.13). Melindungi memori
  /// isolate & durasi transaksi di HP kelas bawah.
  static const int maxRows = 5000;

  /// Batas panjang nama produk (PRD §4.3.A).
  static const int maxNameLength = 100;

  /// Batas panjang satuan; lebih dari ini dipotong + peringatan.
  static const int maxUnitLength = 10;

  /// Penanda baris contoh di template. Baris yang namanya diawali penanda
  /// ini DILEWATI parser, sehingga pengguna yang lupa menghapus contohnya
  /// tidak ikut mengimpor produk palsu (lihat laporan-m9.md §3).
  static const String exampleMarker = 'CONTOH (hapus baris ini)';

  static final CellStyle _headerStyle = CellStyle(bold: true);

  // =====================================================================
  // 1. TEMPLATE
  // =====================================================================

  /// Membuat `template_produk.xlsx` di `<Documents>/export/` dan
  /// mengembalikan path-nya.
  static Future<String> saveTemplate() async {
    final bytes = buildTemplateBytes();
    return _saveFile(bytes, 'template_produk.xlsx');
  }

  /// Isi workbook template — dipisah supaya bisa diuji tanpa file system.
  ///
  /// Tidak dijalankan di isolate: hanya 2 sheet berisi belasan baris,
  /// jauh di bawah ambang yang bisa membuat frame drop (bandingkan
  /// [parseFile] yang memproses ribuan sel milik pengguna).
  static List<int> buildTemplateBytes() {
    final excel = Excel.createExcel();
    final sheet = excel['Produk'];

    sheet.appendRow([
      for (final column in ProductImportColumn.values) TextCellValue(column.header),
    ]);
    for (var col = 0; col < ProductImportColumn.values.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle =
          _headerStyle;
    }

    sheet.appendRow([
      TextCellValue('$exampleMarker — Beras Ramos 5kg'),
      TextCellValue('8991234567890'),
      TextCellValue('Sembako'),
      IntCellValue(68000),
      IntCellValue(62000),
      DoubleCellValue(12),
      TextCellValue('sak'),
      DoubleCellValue(3),
      TextCellValue('Ya'),
    ]);
    sheet.appendRow([
      TextCellValue('$exampleMarker — Gula Pasir'),
      TextCellValue(''),
      TextCellValue('Sembako'),
      IntCellValue(16500),
      IntCellValue(15000),
      DoubleCellValue(4.5),
      TextCellValue('kg'),
      DoubleCellValue(2),
      TextCellValue('Ya'),
    ]);

    final guide = excel['Petunjuk'];
    for (final line in _templateGuideLines) {
      guide.appendRow([TextCellValue(line)]);
    }
    guide.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
        _headerStyle;

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    return excel.encode()!;
  }

  static const List<String> _templateGuideLines = [
    'CARA MENGISI TEMPLATE IMPOR PRODUK',
    '',
    '1. Isi data mulai baris ke-2 pada sheet "Produk".',
    '2. Hapus dua baris contoh yang diawali "$exampleMarker" '
        '(kalau lupa dihapus pun aman: baris itu otomatis dilewati saat impor).',
    '3. Jangan mengubah judul kolom di baris pertama. Urutan kolom boleh '
        'ditukar, huruf besar-kecil bebas, kolom tambahan buatan sendiri '
        'akan diabaikan.',
    '4. Simpan sebagai .xlsx (Excel/WPS: "Simpan sebagai" > "Excel Workbook").',
    '',
    'KOLOM WAJIB',
    'Nama Produk — 1 sampai 100 karakter.',
    'Harga Jual — angka rupiah bulat, 0 atau lebih.',
    '',
    'KOLOM PILIHAN',
    'Barcode — angka/teks. Kosongkan kalau barang tidak punya barcode.',
    'Kategori — nama kategori; dibuat otomatis kalau belum ada.',
    'Harga Modal — angka rupiah bulat.',
    'Stok — boleh desimal untuk kg/liter. Kosong berarti 0.',
    'Satuan — maksimal 10 huruf. Kosong berarti "pcs".',
    'Batas Stok Menipis — kosong berarti ikut pengaturan global.',
    'Aktif — Ya/Tidak (boleh juga 1/0, Y/T). Kosong berarti Ya.',
    '',
    'CARA MENULIS ANGKA',
    'Harga: "Rp 12.000", "12.000", "12000", dan "12 000" sama-sama dibaca '
        '12000. Titik selalu dianggap pemisah ribuan.',
    'Stok: "1,5" dan "1.5" sama-sama dibaca 1,5. "1.500" dibaca 1500.',
    'Harga berkoma akan dibulatkan ke rupiah penuh dan ditandai peringatan.',
    '',
    'BARCODE GANDA',
    'Barcode yang muncul dua kali di dalam file ini akan ditolak SEMUA '
        'barisnya — aplikasi tidak menebak mana yang benar. Perbaiki dulu di '
        'laptop, lalu impor ulang.',
    'Barcode yang sudah ada di aplikasi akan memperbarui produk lama '
        '(atau dilewati, sesuai pilihan di layar pratinjau).',
    '',
    'STOK TIDAK DITIMPA',
    'Secara default impor TIDAK mengubah stok produk yang sudah ada, karena '
        'file Excel biasanya lebih tua daripada stok berjalan di aplikasi. '
        'Nyalakan "Timpa stok dari file" di layar pratinjau kalau memang ingin '
        'menimpanya — perubahannya tercatat di riwayat stok.',
  ];

  // =====================================================================
  // 2. PARSING & VALIDASI
  // =====================================================================

  /// Membaca file [path] menjadi [ProductImportParseResult].
  ///
  /// Melempar turunan [ImporProdukException] berbahasa Indonesia untuk
  /// setiap kegagalan yang bisa dipahami pengguna (AC-4.4, AC-4.13,
  /// AC-4.14) — pemanggil cukup menampilkan `e.toString()`.
  static Future<ProductImportParseResult> parseFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileImporTidakValidException('File tidak ditemukan.');
    }
    final fileName = path.split(Platform.pathSeparator).last.split('/').last;
    if (!fileName.toLowerCase().endsWith('.xlsx')) {
      throw const FileImporTidakValidException(
        'Hanya file .xlsx yang didukung. Buka file di Excel/WPS lalu simpan '
        'ulang sebagai "Excel Workbook (.xlsx)".',
      );
    }
    if (await file.length() == 0) {
      throw const FileImporTidakValidException('File kosong.');
    }

    final bytes = await file.readAsBytes();
    return compute(parseBytes, ProductImportParseArgs(bytes, fileName));
  }

  /// Parser murni (tanpa file system) — inilah yang dijalankan di isolate
  /// oleh [parseFile], dan dipanggil langsung oleh unit test.
  static ProductImportParseResult parseBytes(ProductImportParseArgs args) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(args.bytes);
    } catch (_) {
      throw const FileImporTidakValidException(
        'Pastikan file benar-benar .xlsx (bukan .xls lama atau CSV yang '
        'diganti namanya) dan tidak terkunci password.',
      );
    }

    final sheetName = _pickSheetName(excel);
    if (sheetName == null) {
      throw const FileImporTidakValidException('File tidak punya sheet yang bisa dibaca.');
    }
    final sheet = excel.tables[sheetName]!;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      throw const FileImporKosongException();
    }

    final headers = [for (final cell in rows.first) _cellText(cell?.value).trim()];
    final columnIndex = <ProductImportColumn, int>{};
    for (var i = 0; i < headers.length; i++) {
      final column = _headerAliases[_normalizeHeader(headers[i])];
      if (column != null && !columnIndex.containsKey(column)) {
        columnIndex[column] = i;
      }
    }

    final missing = [
      for (final column in ProductImportColumn.required)
        if (!columnIndex.containsKey(column)) column.header,
    ];
    if (missing.isNotEmpty) {
      throw KolomWajibHilangException(missing);
    }

    // Kumpulkan dulu baris yang benar-benar berisi data — baris kosong di
    // ekor file (sangat umum setelah pengguna menghapus isi sel) tidak
    // boleh ikut terhitung sebagai baris produk maupun batas 5.000.
    final dataRows = <({int excelRow, List<Data?> cells})>[];
    final nameIndex = columnIndex[ProductImportColumn.name]!;
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      if (cells.every((c) => _cellText(c?.value).trim().isEmpty)) continue;
      final rawName = _valueAt(cells, nameIndex).trim().toLowerCase();
      if (rawName.startsWith(exampleMarker.toLowerCase())) continue;
      dataRows.add((excelRow: i + 1, cells: cells));
    }

    if (dataRows.isEmpty) {
      throw const FileImporKosongException();
    }
    if (dataRows.length > maxRows) {
      throw FileImporTerlaluBesarException(dataRows.length, maxRows);
    }

    final parsed = [
      for (final entry in dataRows)
        _parseRow(
          excelRow: entry.excelRow,
          cells: entry.cells,
          columnIndex: columnIndex,
          columnCount: headers.length,
        ),
    ];

    return ProductImportParseResult(
      fileName: args.fileName,
      sheetName: sheetName,
      headers: headers,
      columns: columnIndex.keys.toSet(),
      rows: _flagDuplicateBarcodes(parsed),
    );
  }

  /// Sheet yang dibaca: bernama `Produk` bila ada; kalau tidak, sheet
  /// pertama (PRD §4.3.B).
  ///
  /// Pencocokan "diawali produk" ikut dipakai supaya file hasil export
  /// v1.0 yang sheet-nya bernama **`Produk & Stok`** tetap terbaca walau
  /// posisinya bukan yang pertama (AC-4.2).
  static String? _pickSheetName(Excel excel) {
    final names = excel.tables.keys.toList();
    if (names.isEmpty) return null;
    for (final name in names) {
      if (name.trim().toLowerCase() == 'produk') return name;
    }
    for (final name in names) {
      if (name.trim().toLowerCase().startsWith('produk')) return name;
    }
    return names.first;
  }

  /// Pencocokan header: huruf besar-kecil diabaikan, spasi berlebih
  /// dirapikan, urutan kolom bebas (AC-4.3). Alias ditambahkan untuk
  /// istilah yang lazim dipakai pengguna di file buatan sendiri.
  static const Map<String, ProductImportColumn> _headerAliases = {
    'nama produk': ProductImportColumn.name,
    'nama barang': ProductImportColumn.name,
    'nama': ProductImportColumn.name,
    'barcode': ProductImportColumn.barcode,
    'kode barcode': ProductImportColumn.barcode,
    'kategori': ProductImportColumn.category,
    'harga jual': ProductImportColumn.sellPrice,
    'harga': ProductImportColumn.sellPrice,
    'harga modal': ProductImportColumn.costPrice,
    'harga beli': ProductImportColumn.costPrice,
    'modal': ProductImportColumn.costPrice,
    'stok': ProductImportColumn.stock,
    'stock': ProductImportColumn.stock,
    'jumlah stok': ProductImportColumn.stock,
    'satuan': ProductImportColumn.unit,
    'unit': ProductImportColumn.unit,
    'batas stok menipis': ProductImportColumn.lowStockThreshold,
    'batas stok': ProductImportColumn.lowStockThreshold,
    'stok minimum': ProductImportColumn.lowStockThreshold,
    'minimal stok': ProductImportColumn.lowStockThreshold,
    'aktif': ProductImportColumn.isActive,
    'status aktif': ProductImportColumn.isActive,
  };

  static String _normalizeHeader(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static ProductImportRow _parseRow({
    required int excelRow,
    required List<Data?> cells,
    required Map<ProductImportColumn, int> columnIndex,
    required int columnCount,
  }) {
    final issues = <ProductImportIssue>[];
    final width = columnCount > cells.length ? columnCount : cells.length;
    final rawCells = [for (var i = 0; i < width; i++) _valueAt(cells, i)];

    CellValue? cellOf(ProductImportColumn column) {
      final index = columnIndex[column];
      if (index == null || index >= cells.length) return null;
      return cells[index]?.value;
    }

    String textOf(ProductImportColumn column) => _cellText(cellOf(column)).trim();

    // --- Nama produk (wajib) ---------------------------------------
    final name = textOf(ProductImportColumn.name);
    if (name.isEmpty) {
      issues.add(const ProductImportIssue.error('Nama produk kosong.'));
    } else if (name.length > maxNameLength) {
      issues.add(
        ProductImportIssue.error(
          'Nama produk terlalu panjang (${name.length} karakter, maksimal '
          '$maxNameLength).',
        ),
      );
    }

    // --- Barcode ----------------------------------------------------
    final barcode = _blankToNull(textOf(ProductImportColumn.barcode));

    // --- Kategori ---------------------------------------------------
    final categoryName = _blankToNull(textOf(ProductImportColumn.category));

    // --- Harga jual (wajib) -----------------------------------------
    var sellPrice = 0;
    final sellParsed = parsePriceCell(cellOf(ProductImportColumn.sellPrice));
    if (sellParsed.isBlank) {
      issues.add(const ProductImportIssue.error('Harga jual kosong.'));
    } else if (sellParsed.invalid) {
      issues.add(
        ProductImportIssue.error(
          'Harga jual "${textOf(ProductImportColumn.sellPrice)}" tidak terbaca '
          'sebagai angka.',
        ),
      );
    } else if (sellParsed.value! < 0) {
      issues.add(const ProductImportIssue.error('Harga jual tidak boleh negatif.'));
    } else {
      sellPrice = sellParsed.value!.round();
      if (sellParsed.value! != sellPrice) {
        issues.add(
          ProductImportIssue.warning(
            'Harga jual "${textOf(ProductImportColumn.sellPrice)}" dibulatkan '
            'menjadi $sellPrice.',
          ),
        );
      }
    }

    // --- Harga modal ------------------------------------------------
    int? costPrice;
    final costParsed = parsePriceCell(cellOf(ProductImportColumn.costPrice));
    if (costParsed.invalid) {
      issues.add(
        ProductImportIssue.warning(
          'Harga modal "${textOf(ProductImportColumn.costPrice)}" tidak terbaca '
          'sebagai angka — dikosongkan.',
        ),
      );
    } else if (costParsed.value != null) {
      if (costParsed.value! < 0) {
        issues.add(
          const ProductImportIssue.warning('Harga modal negatif — dikosongkan.'),
        );
      } else {
        costPrice = costParsed.value!.round();
        if (costParsed.value! != costPrice) {
          issues.add(
            ProductImportIssue.warning('Harga modal dibulatkan menjadi $costPrice.'),
          );
        }
        if (costPrice > sellPrice && !issues.any((i) => i.isError)) {
          issues.add(
            const ProductImportIssue.warning(
              'Harga modal lebih besar daripada harga jual — cek lagi kalau ini '
              'bukan disengaja.',
            ),
          );
        }
      }
    }

    // --- Stok -------------------------------------------------------
    final stock = _quantity(
      cellOf(ProductImportColumn.stock),
      label: 'Stok',
      rawText: textOf(ProductImportColumn.stock),
      issues: issues,
    );

    // --- Satuan -----------------------------------------------------
    String? unit = _blankToNull(textOf(ProductImportColumn.unit));
    if (unit != null && unit.length > maxUnitLength) {
      unit = unit.substring(0, maxUnitLength);
      issues.add(
        ProductImportIssue.warning(
          'Satuan lebih dari $maxUnitLength karakter — dipotong menjadi "$unit".',
        ),
      );
    }

    // --- Batas stok menipis -----------------------------------------
    final threshold = _quantity(
      cellOf(ProductImportColumn.lowStockThreshold),
      label: 'Batas stok menipis',
      rawText: textOf(ProductImportColumn.lowStockThreshold),
      issues: issues,
    );

    // --- Aktif ------------------------------------------------------
    bool? isActive;
    final activeRaw = textOf(ProductImportColumn.isActive);
    if (_blankToNull(activeRaw) != null) {
      isActive = parseBoolean(activeRaw);
      if (isActive == null) {
        issues.add(
          ProductImportIssue.warning(
            'Kolom Aktif berisi "$activeRaw" yang tidak dikenal — dianggap "Ya".',
          ),
        );
        isActive = true;
      }
    }

    return ProductImportRow(
      excelRow: excelRow,
      rawCells: rawCells,
      name: name,
      barcode: barcode,
      categoryName: categoryName,
      sellPrice: sellPrice,
      costPrice: costPrice,
      stock: stock,
      unit: unit,
      lowStockThreshold: threshold,
      isActive: isActive,
      issues: issues,
    );
  }

  /// Angka non-uang (stok & batas stok): masalah di sini TIDAK PERNAH
  /// membuang seluruh baris (PRD §4.3.D hanya menyebut nama & harga jual
  /// sebagai error) — nilainya dikosongkan dan pengguna diberi peringatan.
  static double? _quantity(
    CellValue? cell, {
    required String label,
    required String rawText,
    required List<ProductImportIssue> issues,
  }) {
    final parsed = parseQuantityCell(cell);
    if (parsed.invalid) {
      issues.add(
        ProductImportIssue.warning(
          '$label "$rawText" tidak terbaca sebagai angka — dikosongkan.',
        ),
      );
      return null;
    }
    if (parsed.value != null && parsed.value! < 0) {
      issues.add(ProductImportIssue.warning('$label negatif — dikosongkan.'));
      return null;
    }
    return parsed.value;
  }

  /// Barcode ganda DI DALAM file: **semua** baris pemakainya ditandai
  /// error, dan pesannya menyebut seluruh nomor baris (AC-4.5). Tidak ada
  /// penebakan mana yang benar (PRD §4.3.E).
  static List<ProductImportRow> _flagDuplicateBarcodes(List<ProductImportRow> rows) {
    final rowsByBarcode = <String, List<int>>{};
    for (final row in rows) {
      final barcode = row.barcode;
      if (barcode == null) continue;
      rowsByBarcode.putIfAbsent(barcode, () => []).add(row.excelRow);
    }
    final duplicates = {
      for (final entry in rowsByBarcode.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    if (duplicates.isEmpty) return rows;

    return [
      for (final row in rows)
        if (row.barcode != null && duplicates.containsKey(row.barcode))
          row.copyWith(
            issues: [
              ...row.issues,
              ProductImportIssue.error(
                'Barcode ${row.barcode} muncul di ${_joinRowNumbers(duplicates[row.barcode]!)}. '
                'Perbaiki dulu di file, semua barisnya dilewati.',
              ),
            ],
          )
        else
          row,
    ];
  }

  static String _joinRowNumbers(List<int> rowNumbers) {
    if (rowNumbers.length == 1) return 'baris ${rowNumbers.first}';
    final head = rowNumbers.take(rowNumbers.length - 1).join(', ');
    return 'baris $head dan ${rowNumbers.last}';
  }

  // ---------------------------------------------------------------------
  // Normalisasi nilai (PRD §4.3.C) — statis & murni supaya bisa diuji
  // sebagai tabel kasus, bukan lewat file (AC-4.10, AC-4.11).
  // ---------------------------------------------------------------------

  /// Harga dari sel Excel. Sel bertipe angka dipakai apa adanya; sel teks
  /// dinormalisasi lewat [parsePrice].
  static ImportNumber parsePriceCell(CellValue? cell) => switch (cell) {
        null => const ImportNumber.blank(),
        IntCellValue(:final value) => ImportNumber(value.toDouble()),
        DoubleCellValue(:final value) => ImportNumber(value),
        _ => parsePrice(_cellText(cell)),
      };

  /// Stok/batas stok dari sel Excel.
  static ImportNumber parseQuantityCell(CellValue? cell) => switch (cell) {
        null => const ImportNumber.blank(),
        IntCellValue(:final value) => ImportNumber(value.toDouble()),
        DoubleCellValue(:final value) => ImportNumber(value),
        _ => parseQuantity(_cellText(cell)),
      };

  /// Normalisasi **harga**: titik SELALU pemisah ribuan, koma desimal.
  ///
  /// `Rp 12.000` / `12.000` / `12000` / `12 000` → 12000 (AC-4.10).
  static ImportNumber parsePrice(String raw) {
    final cleaned = _stripNumberDecoration(raw);
    if (cleaned.isEmpty) return const ImportNumber.blank();
    final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
    return _toNumber(normalized);
  }

  /// Normalisasi **kuantitas** (stok, batas stok).
  ///
  /// Aturan tambahan dibanding harga: bila hanya ada SATU tanda pemisah
  /// dan diikuti paling banyak 2 digit, tanda itu dianggap desimal —
  /// sehingga `1,5` dan `1.5` sama-sama 1,5 sedangkan `1.500` tetap 1500
  /// (PRD §4.3.C, AC-4.11).
  static ImportNumber parseQuantity(String raw) {
    final cleaned = _stripNumberDecoration(raw);
    if (cleaned.isEmpty) return const ImportNumber.blank();

    final separators = RegExp(r'[.,]').allMatches(cleaned).toList();
    if (separators.length == 1) {
      final position = separators.first.start;
      final digitsAfter = cleaned.length - position - 1;
      final tailIsDigits = RegExp(r'^\d*$').hasMatch(cleaned.substring(position + 1));
      if (tailIsDigits && digitsAfter > 0 && digitsAfter <= 2) {
        return _toNumber(
          '${cleaned.substring(0, position)}.${cleaned.substring(position + 1)}',
        );
      }
      return _toNumber(cleaned.replaceAll(RegExp(r'[.,]'), ''));
    }
    return _toNumber(cleaned.replaceAll('.', '').replaceAll(',', '.'));
  }

  /// `Ya`/`ya`/`YA`/`1`/`Y`/`true` → aktif; `Tidak`/`0`/`T`/`false` →
  /// nonaktif; `null` bila tidak dikenal.
  static bool? parseBoolean(String raw) {
    final value = raw.trim().toLowerCase();
    if (const {'ya', 'y', '1', 'true', 'aktif', 'yes', 'benar'}.contains(value)) {
      return true;
    }
    if (const {'tidak', 't', 'n', '0', 'false', 'no', 'nonaktif', 'tdk', 'non aktif'}
        .contains(value)) {
      return false;
    }
    return null;
  }

  /// Membuang hiasan yang lazim diketik pengguna: prefix `Rp`, spasi
  /// (termasuk NBSP `U+00A0` yang dihasilkan `intl`), dan tanda mata uang.
  static String _stripNumberDecoration(String raw) {
    var value = raw.trim();
    if (value.isEmpty || value == '-') return '';
    // `\s` di Dart mengikuti ECMAScript: sudah mencakup NBSP (U+00A0) &
    // narrow NBSP (U+202F) yang dihasilkan `intl` pada format Rupiah,
    // sehingga "Rp 12.000" hasil salin-tempel dari aplikasi lain ikut
    // terbaca.
    value = value.replaceAll(RegExp(r'\s'), '');
    // Prefix mata uang dibuang setelah spasi hilang, dengan tanda minus
    // (kalau ada) dipertahankan supaya nilai negatif tetap ketahuan dan
    // ditolak, bukan diam-diam jadi positif.
    value = value.replaceFirstMapped(
      RegExp(r'^(-?)rp\.?', caseSensitive: false),
      (match) => match[1] ?? '',
    );
    return value.trim();
  }

  static ImportNumber _toNumber(String normalized) {
    if (normalized.isEmpty) return const ImportNumber.blank();
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) return const ImportNumber.invalid();
    return ImportNumber(parsed);
  }

  /// String kosong / placeholder `-` (dipakai `ExcelExportService` untuk
  /// kolom kosong) dianggap tidak diisi — kunci agar file export v1.0 bisa
  /// diimpor bulat-balik tanpa diedit (AC-4.2).
  static String? _blankToNull(String raw) {
    final value = raw.trim();
    return (value.isEmpty || value == '-') ? null : value;
  }

  static String _valueAt(List<Data?> cells, int index) =>
      index < cells.length ? _cellText(cells[index]?.value) : '';

  /// Teks apa adanya dari sebuah sel, untuk laporan & pesan masalah.
  ///
  /// Sel angka bulat sengaja TIDAK ditulis `899123.0` — barcode yang
  /// diketik sebagai angka di Excel akan kembali sebagai `DoubleCellValue`
  /// dan harus tetap terbaca sebagai `899123`.
  static String _cellText(CellValue? value) => switch (value) {
        null => '',
        TextCellValue(value: final span) => span.toString(),
        IntCellValue(value: final v) => v.toString(),
        DoubleCellValue(value: final v) =>
          v == v.roundToDouble() && v.abs() < 1e15 ? v.toInt().toString() : v.toString(),
        BoolCellValue(value: final v) => v ? 'Ya' : 'Tidak',
        FormulaCellValue(formula: final f) => f,
        _ => value.toString(),
      };

  // =====================================================================
  // 3. PRATINJAU (dibandingkan dengan isi database)
  // =====================================================================

  /// Menyusun pratinjau: menentukan tiap baris akan **dibuat**,
  /// **diperbarui**, **dilewati**, atau **bermasalah**, plus peringatan
  /// yang hanya bisa diketahui setelah melihat database.
  ///
  /// Fungsi MURNI (tanpa I/O) supaya seluruh aturan PRD §4.3.E bisa diuji
  /// tanpa database sungguhan. Pencocokan produk lama HANYA lewat barcode
  /// (K-4.3).
  static ProductImportPlan buildPlan({
    required ProductImportParseResult parse,
    required ProductImportOptions options,
    required ProductImportLookup lookup,
  }) {
    final planRows = <ProductImportPlanRow>[];
    final newCategories = <String>[];
    final newCategoryKeys = <String>{};

    for (final row in parse.rows) {
      final issues = [...row.issues];

      if (row.hasError) {
        planRows.add(
          ProductImportPlanRow(
            row: row,
            action: ProductImportAction.error,
            issues: issues,
          ),
        );
        continue;
      }

      // Kategori: hanya relevan bila kolomnya memang ada di file.
      final categoryName = row.categoryName;
      if (categoryName != null) {
        final key = categoryName.toLowerCase();
        if (!lookup.categoryNames.contains(key)) {
          if (options.autoCreateCategory) {
            if (newCategoryKeys.add(key)) newCategories.add(categoryName);
          } else {
            issues.add(
              ProductImportIssue.warning(
                'Kategori "$categoryName" belum ada dan opsi "Buat kategori baru '
                'otomatis" sedang mati — produk diimpor tanpa kategori.',
              ),
            );
          }
        }
      }

      final existingId =
          row.barcode == null ? null : lookup.productIdByBarcode[row.barcode];

      if (existingId != null) {
        if (options.duplicateMode == ProductImportDuplicateMode.skip) {
          planRows.add(
            ProductImportPlanRow(
              row: row,
              action: ProductImportAction.skip,
              issues: issues,
              existingProductId: existingId,
            ),
          );
        } else {
          planRows.add(
            ProductImportPlanRow(
              row: row,
              action: ProductImportAction.update,
              issues: issues,
              existingProductId: existingId,
            ),
          );
        }
        continue;
      }

      // Baris TANPA barcode tidak pernah dicocokkan ke produk lama; nama
      // yang sama hanya memicu peringatan (PRD §4.3.E, K-4.3).
      if (row.barcode == null && lookup.activeProductNames.contains(row.name.toLowerCase())) {
        issues.add(
          ProductImportIssue.warning(
            'Sudah ada produk aktif bernama "${row.name}". Karena baris ini tidak '
            'punya barcode, produk BARU tetap dibuat.',
          ),
        );
      }

      planRows.add(
        ProductImportPlanRow(
          row: row,
          action: ProductImportAction.create,
          issues: issues,
        ),
      );
    }

    return ProductImportPlan(
      parse: parse,
      options: options,
      rows: planRows,
      newCategoryNames: newCategories,
    );
  }

  // =====================================================================
  // 4. LAPORAN BARIS BERMASALAH
  // =====================================================================

  /// Menyimpan laporan baris bermasalah `.xlsx` berisi nomor baris Excel,
  /// isi baris ASLI, dan alasan Bahasa Indonesia (AC-4.17).
  static Future<String> saveIssueReport(ProductImportPlan plan) async {
    final bytes = await compute(
      buildIssueReportBytes,
      ProductImportReportArgs(headers: plan.parse.headers, rows: plan.problemRows),
    );
    final stamp = _timestamp();
    return _saveFile(bytes, 'laporan_impor_$stamp.xlsx');
  }

  /// Isi workbook laporan — dipisah supaya bisa diuji tanpa file system.
  static List<int> buildIssueReportBytes(ProductImportReportArgs args) {
    final excel = Excel.createExcel();
    final sheet = excel['Baris Bermasalah'];

    sheet.appendRow([
      TextCellValue('Baris'),
      TextCellValue('Tingkat'),
      for (final header in args.headers) TextCellValue(header),
      TextCellValue('Alasan'),
    ]);
    for (var col = 0; col < args.headers.length + 3; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle =
          _headerStyle;
    }

    for (final planRow in args.rows) {
      sheet.appendRow([
        IntCellValue(planRow.row.excelRow),
        TextCellValue(planRow.hasError ? 'Dilewati' : 'Peringatan'),
        for (var i = 0; i < args.headers.length; i++)
          TextCellValue(i < planRow.row.rawCells.length ? planRow.row.rawCells[i] : ''),
        TextCellValue(planRow.issues.map((i) => i.message).join(' ')),
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    return excel.encode()!;
  }

  // =====================================================================
  // Helper file
  // =====================================================================

  static String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
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
}

/// Argumen parsing yang menyeberang ke isolate — hanya byte & nama file
/// (K-4.2: tanpa closure, tanpa koneksi native).
class ProductImportParseArgs {
  const ProductImportParseArgs(this.bytes, this.fileName);

  final List<int> bytes;
  final String fileName;
}

/// Argumen pembuatan laporan baris bermasalah (menyeberang isolate).
class ProductImportReportArgs {
  const ProductImportReportArgs({required this.headers, required this.rows});

  final List<String> headers;
  final List<ProductImportPlanRow> rows;
}

/// Hasil normalisasi satu sel angka.
///
/// Tiga keadaan yang WAJIB dibedakan: kosong (pengguna tidak mengisi),
/// tidak valid (ada isinya tapi bukan angka), dan terbaca. Menggabungkan
/// "kosong" dengan "tidak valid" akan membuat harga jual yang salah ketik
/// diam-diam menjadi 0.
class ImportNumber {
  const ImportNumber(double this.value) : invalid = false;

  const ImportNumber.blank()
      : value = null,
        invalid = false;

  const ImportNumber.invalid()
      : value = null,
        invalid = true;

  final double? value;
  final bool invalid;

  bool get isBlank => value == null && !invalid;

  @override
  String toString() => invalid ? 'ImportNumber.invalid' : 'ImportNumber($value)';
}
