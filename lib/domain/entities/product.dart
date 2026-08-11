/// Entity domain Produk — representasi murni tanpa dependency Drift.
///
/// Layer `features/` hanya boleh bergantung pada entity ini (dan kontrak
/// repository di `domain/repositories`), tidak pernah langsung ke Drift.
/// Lihat architecture.md §3.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    required this.sellPrice,
    this.costPrice,
    required this.stock,
    required this.unit,
    this.lowStockThreshold,
    this.imagePath,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Threshold stok menipis default global sementara di-hardcode di sini
  /// (dipakai bila [lowStockThreshold] per-produk kosong/null).
  ///
  /// PRD §3.1.F menyebut nilai ini seharusnya bisa diubah pengguna lewat
  /// layar Pengaturan, tapi layar itu baru dikerjakan di Milestone 5
  /// (plan.md). Lihat docs/laporan-m1.md bagian keputusan teknis.
  static const double defaultLowStockThreshold = 5;

  final int id;
  final String name;
  final String? barcode;
  final int? categoryId;

  /// Harga jual (Rp, integer penuh — lihat architecture.md §4).
  final int sellPrice;

  /// Harga modal (Rp), opsional.
  final int? costPrice;

  /// REAL agar mendukung satuan desimal (kg/liter).
  final double stock;
  final String unit;

  /// null = pakai [defaultLowStockThreshold].
  final double? lowStockThreshold;
  final String? imagePath;

  /// false = dinonaktifkan (tersembunyi dari Kasir, tetap tampil di daftar
  /// Produk dengan penanda). Lihat plan.md Milestone 1 poin 6.
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Stok dianggap menipis bila kurang dari atau sama dengan threshold.
  ///
  /// Memakai [defaultLowStockThreshold] hardcode — dipertahankan untuk
  /// kompatibilitas test/kode lama. UI produksi (tab Produk & Kasir)
  /// sebaiknya memakai [isLowStockWith] dengan threshold global dari
  /// `settings.low_stock_default` (lihat `lowStockDefaultThresholdProvider`),
  /// supaya konsisten dengan nilai yang bisa diubah pengguna di Pengaturan.
  bool get isLowStock => stock <= (lowStockThreshold ?? defaultLowStockThreshold);

  /// Sama seperti [isLowStock], tapi memakai [defaultThreshold] (mis. dari
  /// `settings.low_stock_default`) sebagai fallback bila produk ini tidak
  /// punya [lowStockThreshold] sendiri — dipakai UI produksi sejak
  /// Milestone 6 agar konsisten dengan threshold global yang bisa diubah
  /// pengguna, BUKAN nilai hardcode [defaultLowStockThreshold].
  bool isLowStockWith(double defaultThreshold) =>
      stock <= (lowStockThreshold ?? defaultThreshold);

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    int? sellPrice,
    int? costPrice,
    double? stock,
    String? unit,
    double? lowStockThreshold,
    String? imagePath,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      sellPrice: sellPrice ?? this.sellPrice,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Product &&
            other.id == id &&
            other.name == name &&
            other.barcode == barcode &&
            other.categoryId == categoryId &&
            other.sellPrice == sellPrice &&
            other.costPrice == costPrice &&
            other.stock == stock &&
            other.unit == unit &&
            other.lowStockThreshold == lowStockThreshold &&
            other.imagePath == imagePath &&
            other.isActive == isActive &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        barcode,
        categoryId,
        sellPrice,
        costPrice,
        stock,
        unit,
        lowStockThreshold,
        imagePath,
        isActive,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'Product(id: $id, name: $name, sellPrice: $sellPrice)';
}
