import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/report_repository_impl.dart';
import '../../../domain/entities/customer_debt.dart';
import '../../../domain/entities/daily_summary.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/entities/top_product.dart';
import '../../../domain/repositories/report_repository.dart';

/// Repository Laporan (lihat architecture.md §6 tabel Provider, plan.md
/// Milestone 4).
final Provider<ReportRepository> reportRepoProvider = Provider<ReportRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ReportRepositoryImpl(database);
});

/// Preset rentang tanggal laporan (plan.md Milestone 4 poin 5).
enum ReportRangePreset { today, yesterday, last7Days, thisMonth, custom }

/// Rentang tanggal aktif untuk dashboard Laporan: [start] awal hari,
/// [end] AKHIR hari (23:59:59.999) agar rentang tanggal inklusif memuat
/// seluruh transaksi di hari terakhir.
class ReportDateRange {
  const ReportDateRange({required this.start, required this.end, required this.preset});

  final DateTime start;
  final DateTime end;
  final ReportRangePreset preset;

  static DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  static DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  factory ReportDateRange.today() {
    final now = DateTime.now();
    return ReportDateRange(
      start: _startOfDay(now),
      end: _endOfDay(now),
      preset: ReportRangePreset.today,
    );
  }

  factory ReportDateRange.yesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return ReportDateRange(
      start: _startOfDay(yesterday),
      end: _endOfDay(yesterday),
      preset: ReportRangePreset.yesterday,
    );
  }

  /// 7 hari terakhir TERMASUK hari ini.
  factory ReportDateRange.last7Days() {
    final now = DateTime.now();
    return ReportDateRange(
      start: _startOfDay(now.subtract(const Duration(days: 6))),
      end: _endOfDay(now),
      preset: ReportRangePreset.last7Days,
    );
  }

  factory ReportDateRange.thisMonth() {
    final now = DateTime.now();
    return ReportDateRange(
      start: DateTime(now.year, now.month),
      end: _endOfDay(now),
      preset: ReportRangePreset.thisMonth,
    );
  }

  factory ReportDateRange.custom({required DateTime start, required DateTime end}) {
    return ReportDateRange(
      start: _startOfDay(start),
      end: _endOfDay(end),
      preset: ReportRangePreset.custom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportDateRange &&
          other.start == start &&
          other.end == end &&
          other.preset == preset);

  @override
  int get hashCode => Object.hash(start, end, preset);
}

/// Notifier rentang tanggal aktif layar Laporan — default preset "Hari ini"
/// (dashboard harian, plan.md Milestone 4 poin 4).
class ReportDateRangeNotifier extends Notifier<ReportDateRange> {
  @override
  ReportDateRange build() => ReportDateRange.today();

  void setPreset(ReportRangePreset preset) {
    state = switch (preset) {
      ReportRangePreset.today => ReportDateRange.today(),
      ReportRangePreset.yesterday => ReportDateRange.yesterday(),
      ReportRangePreset.last7Days => ReportDateRange.last7Days(),
      ReportRangePreset.thisMonth => ReportDateRange.thisMonth(),
      ReportRangePreset.custom => state,
    };
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = ReportDateRange.custom(start: start, end: end);
  }
}

final NotifierProvider<ReportDateRangeNotifier, ReportDateRange> reportDateRangeProvider =
    NotifierProvider<ReportDateRangeNotifier, ReportDateRange>(ReportDateRangeNotifier.new);

/// Ringkasan laporan (omzet, jumlah transaksi, laba kotor, per metode
/// bayar) untuk rentang tanggal aktif (plan.md Milestone 4 poin 4).
final FutureProvider<DailySummary> dailySummaryProvider = FutureProvider<DailySummary>((ref) {
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(reportRepoProvider).getSummary(start: range.start, end: range.end);
});

/// Urutan produk terlaris aktif di layar Laporan (qty terjual atau nilai
/// penjualan, plan.md Milestone 4 poin 6).
final NotifierProvider<TopProductSortNotifier, TopProductSort> topProductSortProvider =
    NotifierProvider<TopProductSortNotifier, TopProductSort>(TopProductSortNotifier.new);

class TopProductSortNotifier extends Notifier<TopProductSort> {
  @override
  TopProductSort build() => TopProductSort.qty;

  void set(TopProductSort sort) => state = sort;
}

/// Produk terlaris untuk rentang tanggal & urutan aktif.
final FutureProvider<List<TopProduct>> topProductsProvider = FutureProvider<List<TopProduct>>((
  ref,
) {
  final range = ref.watch(reportDateRangeProvider);
  final sortBy = ref.watch(topProductSortProvider);
  return ref
      .watch(reportRepoProvider)
      .getTopProducts(start: range.start, end: range.end, sortBy: sortBy);
});

/// Daftar hutang belum lunas per pelanggan (plan.md Milestone 4 poin 7) —
/// SEMUA rentang waktu, tidak terpengaruh filter tanggal dashboard.
final FutureProvider<List<CustomerDebt>> unpaidDebtsProvider = FutureProvider<List<CustomerDebt>>(
  (ref) {
    return ref.watch(reportRepoProvider).getUnpaidDebts();
  },
);

/// Daftar transaksi hutang belum lunas milik satu pelanggan — dipakai
/// layar "tap nama pelanggan -> daftar transaksinya".
final AutoDisposeFutureProviderFamily<List<Sale>, String> customerDebtTransactionsProvider =
    FutureProvider.autoDispose.family<List<Sale>, String>((ref, customerName) {
  return ref.watch(reportRepoProvider).getDebtTransactions(customerName);
});
