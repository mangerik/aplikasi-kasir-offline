/// Satu baris pergerakan stok (audit trail) — entity domain murni.
///
/// Dipakai layar Riwayat Pergerakan Stok per produk (plan.md Milestone 4
/// poin 2). Selalu diminta untuk SATU produk tertentu, jadi tidak membawa
/// nama produk (beda dari `TopProduct`, yang dipakai lintas produk).
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.qtyChange,
    required this.stockAfter,
    this.referenceSaleId,
    this.referenceInvoiceNumber,
    this.note,
    required this.createdAt,
  });

  final int id;
  final int productId;

  /// `'sale'` | `'void_return'` | `'adjust_in'` | `'adjust_out'` | `'opname'`.
  final String type;

  /// +masuk / -keluar.
  final double qtyChange;
  final double stockAfter;

  /// Terisi bila pergerakan berasal dari transaksi penjualan/void
  /// (`type` `'sale'`/`'void_return'`).
  final int? referenceSaleId;

  /// Nomor invoice transaksi terkait (join `sales.invoice_number`), untuk
  /// ditampilkan langsung di layar riwayat tanpa query terpisah per baris.
  final String? referenceInvoiceNumber;

  /// Alasan/catatan — WAJIB diisi untuk penyesuaian manual (`adjust_in`/
  /// `adjust_out`/`opname`, lihat `AdjustStockUsecase`), kosong untuk
  /// pergerakan otomatis (`sale`/`void_return`).
  final String? note;

  final DateTime createdAt;

  /// Label Bahasa Indonesia untuk [type], siap tampil di UI.
  String get typeLabel => switch (type) {
        'sale' => 'Penjualan',
        'void_return' => 'Pengembalian (Void)',
        'adjust_in' => 'Stok Masuk',
        'adjust_out' => 'Stok Keluar',
        'opname' => 'Opname',
        _ => type,
      };

  /// `true` bila pergerakan manual (dibuat dari layar penyesuaian stok),
  /// beda dari pergerakan otomatis akibat penjualan/void.
  bool get isManualAdjustment =>
      type == 'adjust_in' || type == 'adjust_out' || type == 'opname';
}
