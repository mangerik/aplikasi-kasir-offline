import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/report_repository_impl.dart';
import '../../../domain/entities/daily_summary.dart';
import '../../../domain/entities/sales_series.dart';
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

  /// Panjang rentang dalam hari kalender (inklusif).
  int get dayCount => SeriesBucket.dayCount(start, end);

  /// Ukuran ember grafik tren untuk rentang ini (PRD v1.1 §9.3.A).
  SeriesBucket get bucket => SeriesBucket.forRange(start, end);

  /// Rentang **periode sebelumnya** yang sama panjang, tepat menempel di
  /// depan rentang ini (PRD §9.3.A: "+12% dari 7 hari sebelumnya",
  /// AC-9.7).
  ///
  /// Dihitung dari tanggal, bukan `subtract(Duration)`, supaya pergantian
  /// bulan & tahun diurus kalender: 7 hari sebelum 3 Maret adalah 24
  /// Februari, bukan 604.800.000 milidetik yang mungkin meleset satu jam.
  ReportDateRange get previousPeriod {
    final days = dayCount;
    final prevStart = DateTime(start.year, start.month, start.day - days);
    final prevEnd = _endOfDay(
      DateTime(start.year, start.month, start.day - 1),
    );
    return ReportDateRange(
      start: prevStart,
      end: prevEnd,
      preset: preset,
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
  return ref.watch(reportRepoProvider).getSummary(
        start: range.start,
        end: range.end,
        userId: ref.watch(reportUserFilterProvider),
      );
});

/// Filter "Kasir" di layar Laporan (AC-8.9) — `null` berarti seluruh
/// kasir. Sengaja provider tersendiri (bukan bagian [ReportDateRange])
/// supaya pemilih rentang tanggal yang sudah ada tidak berubah sama
/// sekali.
final NotifierProvider<ReportUserFilterNotifier, int?> reportUserFilterProvider =
    NotifierProvider<ReportUserFilterNotifier, int?>(ReportUserFilterNotifier.new);

class ReportUserFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? userId) => state = userId;
}

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
      .getTopProducts(
        start: range.start,
        end: range.end,
        sortBy: sortBy,
        userId: ref.watch(reportUserFilterProvider),
      );
});

// =====================================================================
// M14 — Grafik penjualan (PRD v1.1 §9).
//
// Seluruh provider di bawah ini `ref.watch` [reportDateRangeProvider] &
// [reportUserFilterProvider] yang SAMA dengan kartu ringkasan — itulah
// yang menjamin K-9.3 (tidak ada pemilih rentang kedua) dan AC-9.14
// (filter kasir memengaruhi grafik konsisten dengan kartu ringkasan)
// tanpa satu baris kode sinkronisasi pun.
// =====================================================================

/// Metrik yang digambar grafik tren: omzet atau laba kotor (PRD §9.3.A).
enum TrendMetric { omzet, profit }

/// Peralih Omzet ↔ Laba pada grafik tren.
///
/// Datanya untuk KEDUA metrik ikut dalam satu hasil query
/// ([SalesPoint.omzet] & [SalesPoint.grossProfit]), sehingga mengubah
/// peralih ini hanya menggambar ulang — tanpa query ulang dan tanpa
/// memuat ulang layar (AC-9.6).
final NotifierProvider<TrendMetricNotifier, TrendMetric> trendMetricProvider =
    NotifierProvider<TrendMetricNotifier, TrendMetric>(TrendMetricNotifier.new);

class TrendMetricNotifier extends Notifier<TrendMetric> {
  @override
  TrendMetric build() => TrendMetric.omzet;

  void set(TrendMetric metric) => state = metric;
}

/// Deret batang grafik tren untuk rentang & filter kasir aktif.
final FutureProvider<List<SalesPoint>> salesSeriesProvider =
    FutureProvider<List<SalesPoint>>((ref) {
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(reportRepoProvider).getSalesSeries(
        start: range.start,
        end: range.end,
        bucket: range.bucket,
        userId: ref.watch(reportUserFilterProvider),
      );
});

/// Distribusi jam ramai (0–23) untuk rentang & filter kasir aktif.
final FutureProvider<List<HourlyPoint>> hourlyDistributionProvider =
    FutureProvider<List<HourlyPoint>>((ref) {
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(reportRepoProvider).getHourlyDistribution(
        start: range.start,
        end: range.end,
        userId: ref.watch(reportUserFilterProvider),
      );
});

/// Ringkasan **periode sebelumnya** yang sama panjang — dipakai kalimat
/// perbandingan "+12% dari 7 hari sebelumnya" (AC-9.7).
///
/// Sengaja memakai `getSummary` yang sudah ada, bukan query baru: angka
/// pembandingnya wajib dihitung dengan aturan yang sama persis dengan
/// angka yang dibandingkan, kalau tidak persentasenya berbohong.
final FutureProvider<DailySummary> previousPeriodSummaryProvider =
    FutureProvider<DailySummary>((ref) {
  final previous = ref.watch(reportDateRangeProvider).previousPeriod;
  return ref.watch(reportRepoProvider).getSummary(
        start: previous.start,
        end: previous.end,
        userId: ref.watch(reportUserFilterProvider),
      );
});

// CATATAN M12: `unpaidDebtsProvider` & `customerDebtTransactionsProvider`
// DIHAPUS. Sejak `schemaVersion` 2 hutang dikelompokkan per **pelanggan**
// (`sales.customer_id`), bukan per teks `sales.customer_name` — lihat
// `features/customers/providers/customer_providers.dart`. Pengelompokan
// per nama yang lama tetap ada di `ReportRepository` (dipakai laporan &
// export yang membaca snapshot nama historis), tapi tidak lagi punya
// konsumen UI: dua nama berbeda ejaan akan tampil sebagai dua penghutang,
// dan itulah persis masalah yang PRD §7.1 minta diselesaikan.
