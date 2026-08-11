/// Total transaksi & omzet untuk satu metode pembayaran, dalam suatu
/// rentang tanggal (baris hasil `GROUP BY payment_method`).
class PaymentMethodTotal {
  const PaymentMethodTotal({
    required this.method,
    required this.count,
    required this.total,
  });

  /// `'cash'` | `'noncash'` | `'debt'`.
  final String method;
  final int count;
  final int total;
}

/// Ringkasan laporan penjualan untuk satu rentang tanggal (plan.md
/// Milestone 4 poin 4 & 5) — omzet, jumlah transaksi, laba kotor, dan
/// pemecahan per metode bayar.
///
/// SELALU dihasilkan lewat agregasi SQL (`ReportRepository.getSummary`),
/// BUKAN dihitung ulang di Dart dari daftar transaksi mentah (plan.md
/// Milestone 4 poin 8). Transaksi berstatus `'voided'` DIKECUALIKAN dari
/// seluruh angka di sini.
class DailySummary {
  const DailySummary({
    required this.start,
    required this.end,
    required this.transactionCount,
    required this.totalOmzet,
    required this.grossProfit,
    required this.byPaymentMethod,
  });

  /// Rentang tanggal (inklusif) yang diringkas.
  final DateTime start;
  final DateTime end;

  /// Jumlah transaksi TIDAK termasuk yang voided.
  final int transactionCount;

  /// Total `sales.total` (omzet), tidak termasuk transaksi voided.
  final int totalOmzet;

  /// Laba kotor: jumlah `(sale_items.line_total - cost_price * qty)` untuk
  /// item yang harga modalnya (`cost_price`) terisi. Item tanpa harga modal
  /// TIDAK ikut dihitung (bukan dianggap modal = 0), sesuai PRD §3.1.D
  /// "laba kotor (jika harga modal diisi)".
  final int grossProfit;

  /// Pemecahan omzet & jumlah transaksi per metode bayar.
  final List<PaymentMethodTotal> byPaymentMethod;
}
