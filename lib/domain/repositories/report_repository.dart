import '../entities/customer_debt.dart';
import '../entities/daily_summary.dart';
import '../entities/sale.dart';
import '../entities/top_product.dart';

/// Urutan pengurutan "produk terlaris" (plan.md Milestone 4 poin 6).
enum TopProductSort { qty, value }

/// Kontrak repository Laporan (plan.md Milestone 4).
///
/// Implementasi (Drift) ada di `data/repositories/report_repository_impl.dart`
/// — SELURUH method WAJIB agregasi via SQL (`SUM`/`COUNT`/`GROUP BY`),
/// BUKAN memuat semua baris ke Dart lalu menjumlahkan manual (plan.md
/// Milestone 4 poin 8), agar tetap cepat di skala puluhan-ratusan ribu
/// transaksi (PRD §6).
abstract class ReportRepository {
  /// Ringkasan penjualan untuk rentang [start]..[end] (inklusif): omzet,
  /// jumlah transaksi, laba kotor, per metode bayar. Transaksi berstatus
  /// `'voided'` DIKECUALIKAN (plan.md Milestone 4 poin 4).
  ///
  /// [userId] memfilter per kasir (PRD v1.1 §8.3.D, AC-8.9); `null`
  /// berarti seluruh kasir.
  Future<DailySummary> getSummary({
    required DateTime start,
    required DateTime end,
    int? userId,
  });

  /// Produk terlaris pada rentang [start]..[end] (inklusif), diurutkan
  /// sesuai [sortBy] (qty terjual atau nilai penjualan), maksimal [limit]
  /// baris. Transaksi voided dikecualikan (plan.md Milestone 4 poin 6).
  Future<List<TopProduct>> getTopProducts({
    required DateTime start,
    required DateTime end,
    int limit = 10,
    TopProductSort sortBy = TopProductSort.qty,
    int? userId,
  });

  /// Total hutang belum lunas per pelanggan (SEMUA rentang waktu — hutang
  /// lama tetap harus ditagih), diurutkan dari yang terbesar (plan.md
  /// Milestone 4 poin 7).
  Future<List<CustomerDebt>> getUnpaidDebts();

  /// Daftar transaksi hutang BELUM LUNAS milik satu [customerName] —
  /// dipakai layar "tap nama pelanggan -> daftar transaksinya" (plan.md
  /// Milestone 4 poin 7).
  Future<List<Sale>> getDebtTransactions(String customerName);
}
