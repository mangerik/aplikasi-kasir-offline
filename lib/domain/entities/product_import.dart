/// Model data impor produk dari Excel (PRD v1.1 §4).
///
/// Seluruh tipe di berkas ini WAJIB "sendable" antar isolate (hanya
/// primitif, `List`, `Map`, `Set`, dan objek biasa tanpa closure/koneksi
/// native) karena hasil parsing menyeberang dari isolate `compute` ke
/// isolate utama — pola yang sama dengan `ExcelExportService` (K-4.2).
library;

/// Kolom yang dikenali parser. Kolom lain di file (`No`, `Status Stok`,
/// kolom buatan pengguna) diabaikan diam-diam (PRD §4.3.B).
enum ProductImportColumn {
  name('Nama Produk'),
  barcode('Barcode'),
  category('Kategori'),
  sellPrice('Harga Jual'),
  costPrice('Harga Modal'),
  stock('Stok'),
  unit('Satuan'),
  lowStockThreshold('Batas Stok Menipis'),
  isActive('Aktif');

  const ProductImportColumn(this.header);

  /// Judul kolom sesuai template (PRD §4.3.A).
  final String header;

  /// Kolom yang wajib ada, kalau tidak impor ditolak sebelum apa pun
  /// diproses (AC-4.4).
  static const List<ProductImportColumn> required = [name, sellPrice];
}

/// Tingkat masalah satu baris (PRD §4.3.D).
///
/// - [warning] — baris TETAP diimpor, ditandai kuning di pratinjau.
/// - [error] — baris dilewati, tidak pernah masuk transaksi database.
enum ProductImportIssueLevel { warning, error }

/// Satu catatan masalah pada satu baris. [message] sudah berbahasa
/// Indonesia dan siap ditampilkan apa adanya (AC-4.17).
class ProductImportIssue {
  const ProductImportIssue(this.level, this.message);

  const ProductImportIssue.error(this.message) : level = ProductImportIssueLevel.error;

  const ProductImportIssue.warning(this.message) : level = ProductImportIssueLevel.warning;

  final ProductImportIssueLevel level;
  final String message;

  bool get isError => level == ProductImportIssueLevel.error;

  @override
  String toString() => message;
}

/// Satu baris produk hasil parsing & normalisasi.
///
/// Nilai `null` berarti **sel kosong** — berbeda dengan "kolomnya tidak ada
/// di file" yang dicatat di [ProductImportParseResult.columns]. Perbedaan
/// ini penting saat memperbarui produk lama: kolom yang tidak ada di file
/// tidak pernah menimpa nilai lama, sedangkan kolom ada tapi selnya kosong
/// berarti pengguna memang mengosongkan nilainya.
class ProductImportRow {
  const ProductImportRow({
    required this.excelRow,
    required this.rawCells,
    required this.name,
    this.barcode,
    this.categoryName,
    required this.sellPrice,
    this.costPrice,
    this.stock,
    this.unit,
    this.lowStockThreshold,
    this.isActive,
    this.issues = const [],
  });

  /// Nomor baris SEPERTI TERLIHAT DI EXCEL (baris 1 = header), supaya
  /// pesan masalah bisa langsung ditelusuri pengguna di laptopnya.
  final int excelRow;

  /// Isi asli seluruh sel baris ini (untuk laporan baris bermasalah).
  final List<String> rawCells;

  final String name;
  final String? barcode;
  final String? categoryName;
  final int sellPrice;
  final int? costPrice;
  final double? stock;
  final String? unit;
  final double? lowStockThreshold;
  final bool? isActive;
  final List<ProductImportIssue> issues;

  bool get hasError => issues.any((i) => i.isError);

  bool get hasWarning => issues.any((i) => !i.isError);

  ProductImportRow copyWith({List<ProductImportIssue>? issues}) => ProductImportRow(
        excelRow: excelRow,
        rawCells: rawCells,
        name: name,
        barcode: barcode,
        categoryName: categoryName,
        sellPrice: sellPrice,
        costPrice: costPrice,
        stock: stock,
        unit: unit,
        lowStockThreshold: lowStockThreshold,
        isActive: isActive,
        issues: issues ?? this.issues,
      );

  @override
  String toString() => 'ProductImportRow(baris $excelRow, $name, $sellPrice)';
}

/// Hasil parsing satu file — murni isi file, BELUM dibandingkan dengan
/// database (perbandingan itu tugas [ProductImportPlan]).
class ProductImportParseResult {
  const ProductImportParseResult({
    required this.fileName,
    required this.sheetName,
    required this.headers,
    required this.columns,
    required this.rows,
  });

  final String fileName;
  final String sheetName;

  /// Judul kolom ASLI seperti tertulis di file (untuk laporan masalah).
  final List<String> headers;

  /// Kolom yang dikenali. Dipakai untuk membedakan "kolom tidak ada" vs
  /// "sel kosong" saat memperbarui produk lama.
  final Set<ProductImportColumn> columns;

  final List<ProductImportRow> rows;
}

/// Perlakuan untuk barcode yang sudah ada di database (PRD §4.3.E).
enum ProductImportDuplicateMode {
  /// Default: produk lama dicocokkan lewat barcode lalu diperbarui.
  update,

  /// Baris dilewati, produk lama tidak disentuh sama sekali.
  skip,
}

/// Pilihan pengguna di langkah pratinjau (PRD §4.4).
class ProductImportOptions {
  const ProductImportOptions({
    this.duplicateMode = ProductImportDuplicateMode.update,
    this.overwriteStock = false,
    this.autoCreateCategory = true,
  });

  final ProductImportDuplicateMode duplicateMode;

  /// **Default MATI.** File Excel pengguna hampir selalu lebih tua daripada
  /// stok berjalan; menimpanya diam-diam menghapus penjualan yang terjadi
  /// sejak file dibuat (PRD §4.3.F).
  final bool overwriteStock;

  final bool autoCreateCategory;

  ProductImportOptions copyWith({
    ProductImportDuplicateMode? duplicateMode,
    bool? overwriteStock,
    bool? autoCreateCategory,
  }) =>
      ProductImportOptions(
        duplicateMode: duplicateMode ?? this.duplicateMode,
        overwriteStock: overwriteStock ?? this.overwriteStock,
        autoCreateCategory: autoCreateCategory ?? this.autoCreateCategory,
      );
}

/// Tindakan yang akan dilakukan pada satu baris saat impor dijalankan.
enum ProductImportAction {
  /// Produk baru akan dibuat.
  create,

  /// Produk lama (cocok lewat barcode) akan diperbarui.
  update,

  /// Produk lama ada tapi mode duplikat "Lewati" dipilih.
  skip,

  /// Baris bermasalah — tidak pernah ikut ke transaksi database.
  error,
}

/// Satu baris pratinjau: baris file + keputusan + seluruh catatan masalah
/// (dari parser maupun dari perbandingan dengan database).
class ProductImportPlanRow {
  const ProductImportPlanRow({
    required this.row,
    required this.action,
    required this.issues,
    this.existingProductId,
  });

  final ProductImportRow row;
  final ProductImportAction action;
  final List<ProductImportIssue> issues;
  final int? existingProductId;

  bool get hasError => action == ProductImportAction.error;

  bool get hasWarning =>
      !hasError && issues.any((i) => i.level == ProductImportIssueLevel.warning);
}

/// Pratinjau lengkap satu impor — inti fitur (PRD §4.4 langkah 3).
class ProductImportPlan {
  const ProductImportPlan({
    required this.parse,
    required this.options,
    required this.rows,
    required this.newCategoryNames,
  });

  final ProductImportParseResult parse;
  final ProductImportOptions options;
  final List<ProductImportPlanRow> rows;

  /// Kategori yang belum ada di database dan akan dibuat otomatis.
  final List<String> newCategoryNames;

  String get fileName => parse.fileName;

  int get totalCount => rows.length;

  int get createCount => _count(ProductImportAction.create);

  int get updateCount => _count(ProductImportAction.update);

  int get skipCount => _count(ProductImportAction.skip);

  int get errorCount => _count(ProductImportAction.error);

  int get warningCount => rows.where((r) => r.hasWarning).length;

  /// Jumlah baris yang benar-benar akan ditulis ke database.
  int get importableCount => createCount + updateCount;

  /// Baris yang akan ikut ke transaksi database (bukan error, bukan
  /// dilewati).
  List<ProductImportRow> get importableRows => [
        for (final r in rows)
          if (r.action == ProductImportAction.create || r.action == ProductImportAction.update)
            r.row,
      ];

  List<ProductImportPlanRow> get problemRows => [
        for (final r in rows)
          if (r.hasError || r.hasWarning) r,
      ];

  int _count(ProductImportAction action) => rows.where((r) => r.action == action).length;
}

/// Cuplikan isi database yang dibutuhkan untuk menyusun pratinjau —
/// dimuat SEKALI sebelum perencanaan, bukan per baris (menghindari N+1).
class ProductImportLookup {
  const ProductImportLookup({
    required this.productIdByBarcode,
    required this.activeProductNames,
    required this.categoryNames,
  });

  const ProductImportLookup.empty()
      : productIdByBarcode = const {},
        activeProductNames = const {},
        categoryNames = const {};

  /// Barcode -> id produk. Berisi produk AKTIF maupun NONAKTIF: partial
  /// unique index barcode berlaku tanpa memandang `is_active`, jadi impor
  /// tidak boleh "menabrak" barcode milik produk yang dinonaktifkan
  /// (K-4.7).
  final Map<String, int> productIdByBarcode;

  /// Nama produk aktif dalam huruf kecil — untuk peringatan duplikat nama
  /// pada baris TANPA barcode (PRD §4.3.E). Tidak pernah dipakai untuk
  /// mencocokkan produk (K-4.3).
  final Set<String> activeProductNames;

  /// Nama kategori yang sudah ada, dalam huruf kecil.
  final Set<String> categoryNames;
}

/// Ringkasan hasil impor yang sudah ter-commit (PRD §4.4 langkah 5).
class ProductImportSummary {
  const ProductImportSummary({
    this.createdCount = 0,
    this.updatedCount = 0,
    this.skippedCount = 0,
    this.categoriesCreatedCount = 0,
    this.stockMovementCount = 0,
  });

  final int createdCount;
  final int updatedCount;
  final int skippedCount;
  final int categoriesCreatedCount;
  final int stockMovementCount;

  int get totalWritten => createdCount + updatedCount;

  @override
  String toString() =>
      'ProductImportSummary(baru: $createdCount, diperbarui: $updatedCount, '
      'dilewati: $skippedCount, kategori baru: $categoriesCreatedCount, '
      'pergerakan stok: $stockMovementCount)';
}
