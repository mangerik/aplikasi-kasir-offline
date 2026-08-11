/// Total hutang belum lunas satu pelanggan (plan.md Milestone 4 poin 7) —
/// hasil agregasi SQL `GROUP BY customer_name` atas transaksi berstatus
/// `'debt_unpaid'`.
class CustomerDebt {
  const CustomerDebt({
    required this.customerName,
    required this.totalDebt,
    required this.transactionCount,
  });

  final String customerName;

  /// Jumlah `sales.total` seluruh transaksi hutang belum lunas pelanggan ini.
  final int totalDebt;

  /// Jumlah transaksi hutang belum lunas pelanggan ini.
  final int transactionCount;
}
