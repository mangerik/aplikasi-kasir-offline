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
    this.customerId,
    this.note,
    required this.createdAt,
    required this.items,
    this.status = 'completed',
    this.voidedAt,
    this.debtPaidAt,
    this.pointsRedeemed = 0,
    this.pointsRedeemedValue = 0,
    this.pointsEarned = 0,
    this.pointsBalanceAfter = 0,
    this.userName,
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

  /// Wajib terisi jika [paymentMethod] `'debt'`. **Snapshot historis**
  /// (K-7.1) — tidak ikut berubah saat pelanggan di-*rename*.
  final String? customerName;

  /// Tautan ke pelanggan (`customers.id`), sejak `schemaVersion` 2 —
  /// `null` untuk transaksi tanpa pelanggan (PRD v1.1 §7.5).
  final int? customerId;

  /// Nama kasir yang melayani (snapshot, K-8.6) — dicetak sebagai baris
  /// `Kasir: <nama>` di struk (§8.3.D). `null` saat multi-user mati, dan
  /// barisnya memang tidak dicetak dalam mode itu (AC-8.1).
  final String? userName;

  /// Jumlah poin yang DITUKAR pada transaksi ini (K-7.6) — 0 bila program
  /// poin mati atau pelanggan tidak menukar poin. Dipakai struk untuk
  /// mencetak baris "Tukar poin" (AC-7.9).
  final int pointsRedeemed;

  /// Nilai rupiah penukaran poin, sudah termasuk di dalam [discount].
  final int pointsRedeemedValue;

  /// Poin yang DIDAPAT dari transaksi ini (AC-7.7) — 0 bila program poin
  /// mati atau transaksi tanpa pelanggan.
  final int pointsEarned;

  /// Saldo poin pelanggan SETELAH transaksi ini tersimpan.
  final int pointsBalanceAfter;
  final String? note;
  final DateTime createdAt;
  final List<SaleResultItem> items;

  /// `'completed'` | `'debt_unpaid'` | `'voided'`. Default `'completed'`
  /// supaya konstruktor lama (`SaveSaleUsecase`/`SaleRepositoryImpl.saveSale`
  /// untuk metode tunai/non-tunai) tidak perlu berubah — layar Riwayat/
  /// Detail (Milestone 3) yang membaca transaksi lama lewat
  /// `SaleRepository.getDetail` mengisi field ini sesuai `sales.status`
  /// sungguhan.
  final String status;

  /// Terisi jika transaksi ini pernah di-void (plan.md Milestone 3 poin 5).
  final DateTime? voidedAt;

  /// Terisi jika hutang ini sudah dilunasi (plan.md Milestone 3 poin 4).
  final DateTime? debtPaidAt;
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
    this.costPrice,
  });

  final int? productId;
  final String name;
  final String unit;
  final double qty;
  final int sellPrice;
  final int discount;
  final int lineTotal;

  /// Snapshot harga modal (Rp) SAAT TRANSAKSI terjadi — dibaca langsung dari
  /// `sale_items.cost_price` (kolom ini SUDAH ADA & SUDAH diisi sejak M0/M2,
  /// lihat `sale_items_table.dart`), bukan harga modal produk saat ini.
  /// `null` bila produk tidak punya harga modal saat item ini terjual, atau
  /// item bebas (`productId == null`). Dipakai untuk menghitung laba kotor
  /// secara konsisten dengan dashboard laporan (`ReportRepositoryImpl.
  /// getSummary`) — lihat `ExcelExportService.exportSalesReport`.
  final int? costPrice;
}
