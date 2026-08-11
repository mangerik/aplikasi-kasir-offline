/// Hasil penyimpanan penjualan — dikembalikan oleh [SaveSaleUsecase] /
/// `SaleRepository.saveSale` setelah transaksi tersimpan atomik.
///
/// Dipakai layar sukses transaksi (`checkout_success_screen.dart`) untuk
/// ringkasan & struk digital (plan.md Milestone 2 poin 7).
class SaleResult {
  const SaleResult({
    required this.saleId,
    required this.invoiceNumber,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.paidAmount,
    required this.changeAmount,
    this.customerName,
    this.note,
    required this.createdAt,
    required this.items,
  });

  final int saleId;

  /// Format `YYYYMMDD-XXXX`, dibangkitkan berurutan per hari (lihat
  /// architecture.md §4 poin 4).
  final String invoiceNumber;

  /// Jumlah `lineTotal` seluruh item (SUDAH bersih dari diskon per item).
  final int subtotal;

  /// Diskon level transaksi (nominal).
  final int discount;

  /// `subtotal - discount`, tidak pernah negatif.
  final int total;

  /// `'cash'` | `'noncash'` | `'debt'`.
  final String paymentMethod;
  final int paidAmount;
  final int changeAmount;

  /// Wajib terisi jika [paymentMethod] `'debt'`.
  final String? customerName;
  final String? note;
  final DateTime createdAt;
  final List<SaleResultItem> items;
}

/// Snapshot satu baris item penjualan (untuk struk & ringkasan) — nilainya
/// TIDAK berubah walau produk aslinya diedit/dihapus belakangan.
class SaleResultItem {
  const SaleResultItem({
    this.productId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.sellPrice,
    required this.discount,
    required this.lineTotal,
  });

  final int? productId;
  final String name;
  final String unit;
  final double qty;
  final int sellPrice;
  final int discount;
  final int lineTotal;
}
