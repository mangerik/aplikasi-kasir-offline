/// Header transaksi penjualan (SATU baris riwayat) — TANPA daftar item.
///
/// Dipakai layar Riwayat (plan.md Milestone 3 poin 2) yang menampilkan
/// banyak baris sekaligus lewat pagination — memuat item tiap baris di
/// layar daftar akan boros query. Untuk detail LENGKAP (header + item),
/// lihat `SaleResult` via `SaleRepository.getDetail`.
class Sale {
  const Sale({
    required this.id,
    required this.invoiceNumber,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.paidAmount,
    required this.changeAmount,
    this.customerName,
    required this.status,
    this.note,
    required this.createdAt,
    this.voidedAt,
    this.debtPaidAt,
  });

  final int id;

  /// Format `YYYYMMDD-XXXX`.
  final String invoiceNumber;

  final int subtotal;
  final int discount;
  final int total;

  /// `'cash'` | `'noncash'` | `'debt'`.
  final String paymentMethod;
  final int paidAmount;
  final int changeAmount;

  /// Terisi jika [paymentMethod] `'debt'`.
  final String? customerName;

  /// `'completed'` | `'debt_unpaid'` | `'voided'`.
  final String status;

  final String? note;
  final DateTime createdAt;

  /// Terisi jika transaksi ini pernah di-void (plan.md Milestone 3 poin 5).
  final DateTime? voidedAt;

  /// Terisi jika hutang ini sudah dilunasi (plan.md Milestone 3 poin 4).
  final DateTime? debtPaidAt;
}
