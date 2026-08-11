/// Satu baris "produk terlaris" untuk suatu rentang tanggal (plan.md
/// Milestone 4 poin 6) — hasil agregasi SQL `GROUP BY` atas `sale_items`
/// (transaksi voided dikecualikan).
class TopProduct {
  const TopProduct({
    this.productId,
    required this.productName,
    required this.unit,
    required this.qtySold,
    required this.totalValue,
  });

  /// `null` bila baris ini menggabungkan item bebas (barang tak terdaftar)
  /// dengan nama yang sama.
  final int? productId;
  final String productName;
  final String unit;

  /// Total qty terjual dalam rentang tanggal.
  final double qtySold;

  /// Total nilai penjualan (`SUM(line_total)`) dalam rentang tanggal.
  final int totalValue;
}
