/// Jenis entri buku besar poin (PRD v1.1 §7.5, K-7.2) — pola sama dengan
/// `stock_movements.type`.
abstract final class PointEntryType {
  /// Poin dari transaksi tersimpan (+).
  static const String earn = 'earn';

  /// Poin ditukar menjadi diskon transaksi (−).
  static const String redeem = 'redeem';

  /// Pembatalan transaksi: penarikan poin earn (−) & pengembalian poin
  /// yang sempat ditukar (+) — dua entri terpisah.
  static const String voidReturn = 'void_return';

  /// Koreksi manual / hasil "hitung ulang saldo dari ledger".
  static const String adjust = 'adjust';

  /// Penanda penggabungan pelanggan (selalu `points = 0`).
  static const String merge = 'merge';
}

/// Satu baris buku besar poin pelanggan.
class CustomerPointEntry {
  const CustomerPointEntry({
    required this.id,
    required this.customerId,
    this.saleId,
    required this.type,
    required this.points,
    required this.balanceAfter,
    this.note,
    required this.createdAt,
    this.invoiceNumber,
  });

  final int id;
  final int customerId;

  /// Transaksi yang memicu entri ini (`null` untuk `adjust`/`merge`).
  final int? saleId;

  /// Lihat [PointEntryType].
  final String type;

  /// `+dapat` / `−pakai` (bilangan bulat, K-7.3).
  final int points;

  /// Saldo pelanggan SETELAH entri ini diterapkan.
  final int balanceAfter;

  final String? note;
  final DateTime createdAt;

  /// Nomor struk transaksi terkait — ikut di-`JOIN` supaya riwayat poin
  /// bisa menyebut "dari struk 20260812-0003" tanpa query tambahan.
  final String? invoiceNumber;

  bool get isPositive => points >= 0;

  /// Label Bahasa Indonesia untuk jenis entri.
  String get typeLabel => switch (type) {
        PointEntryType.earn => 'Dapat poin',
        PointEntryType.redeem => 'Tukar poin',
        PointEntryType.voidReturn => 'Pembatalan transaksi',
        PointEntryType.adjust => 'Koreksi saldo',
        PointEntryType.merge => 'Penggabungan pelanggan',
        _ => type,
      };
}
