import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/sale.dart';
import '../../../domain/entities/sale_result.dart';
import '../../pos/providers/sale_providers.dart';

/// Filter aktif layar Riwayat (plan.md Milestone 3 poin 2): rentang
/// tanggal, metode bayar, status. `null` pada tiap field berarti "semua".
class HistoryFilter {
  const HistoryFilter({this.startDate, this.endDate, this.paymentMethod, this.status});

  final DateTime? startDate;
  final DateTime? endDate;

  /// `'cash'` | `'noncash'` | `'debt'` | `null` (semua).
  final String? paymentMethod;

  /// `'completed'` | `'debt_unpaid'` | `'voided'` | `null` (semua).
  final String? status;

  bool get isActive =>
      startDate != null || endDate != null || paymentMethod != null || status != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryFilter &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.paymentMethod == paymentMethod &&
          other.status == status);

  @override
  int get hashCode => Object.hash(startDate, endDate, paymentMethod, status);
}

/// Notifier filter riwayat — TIDAK di-debounce (beda dari filter pencarian
/// produk/kasir) karena diubah lewat sheet filter eksplisit (tombol
/// terapkan), bukan tiap ketukan huruf.
class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  /// Menerapkan seluruh filter sekaligus (dipanggil dari tombol "Terapkan"
  /// di `HistoryFilterSheet`).
  void apply({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? status,
  }) {
    state = HistoryFilter(
      startDate: startDate,
      endDate: endDate,
      paymentMethod: paymentMethod,
      status: status,
    );
  }

  void reset() => state = const HistoryFilter();
}

final NotifierProvider<HistoryFilterNotifier, HistoryFilter> historyFilterProvider =
    NotifierProvider<HistoryFilterNotifier, HistoryFilter>(HistoryFilterNotifier.new);

/// State daftar riwayat TERPAGINASI (plan.md Milestone 3 poin 2:
/// "infinite scroll/pagination efisien" — query SQL `LIMIT`/`OFFSET`
/// memakai index `sales(created_at)`/`sales(status)` dari architecture.md
/// §4, BUKAN memuat semua baris ke memori).
class HistoryState {
  const HistoryState({this.items = const [], this.hasMore = true, this.isLoadingMore = false});

  final List<Sale> items;
  final bool hasMore;
  final bool isLoadingMore;

  HistoryState copyWith({List<Sale>? items, bool? hasMore, bool? isLoadingMore}) {
    return HistoryState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Notifier daftar riwayat: `build()` (dipicu ulang otomatis tiap
/// [historyFilterProvider] berubah, lewat `ref.watch`) selalu memuat
/// HALAMAN PERTAMA dari awal; [loadMore] menambah halaman berikutnya untuk
/// infinite scroll.
class HistoryListNotifier extends AsyncNotifier<HistoryState> {
  static const int pageSize = 20;

  @override
  Future<HistoryState> build() async {
    final filter = ref.watch(historyFilterProvider);
    final items = await _fetch(filter, offset: 0);
    return HistoryState(items: items, hasMore: items.length == pageSize);
  }

  Future<List<Sale>> _fetch(HistoryFilter filter, {required int offset}) {
    final repo = ref.read(saleRepoProvider);
    return repo.getHistory(
      startDate: filter.startDate,
      endDate: filter.endDate,
      paymentMethod: filter.paymentMethod,
      status: filter.status,
      limit: pageSize,
      offset: offset,
    );
  }

  /// Muat halaman berikutnya & gabungkan ke [HistoryState.items] yang
  /// sudah ada. No-op bila sedang memuat atau sudah tidak ada halaman
  /// berikutnya (`hasMore == false`).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filter = ref.read(historyFilterProvider);
      final nextItems = await _fetch(filter, offset: current.items.length);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...nextItems],
          hasMore: nextItems.length == pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Gagal memuat halaman berikutnya (mis. error DB sesaat) — biarkan
      // daftar yang sudah ada tetap tampil, cukup matikan indikator
      // loading supaya pengguna bisa coba scroll lagi.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Muat ulang dari halaman pertama — dipanggil setelah void/pelunasan
  /// hutang berhasil supaya baris terkait di riwayat langsung ter-update.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final AsyncNotifierProvider<HistoryListNotifier, HistoryState> historyListProvider =
    AsyncNotifierProvider<HistoryListNotifier, HistoryState>(HistoryListNotifier.new);

/// Detail satu transaksi (header + item) — reusable untuk layar Detail
/// DAN share ulang struk (plan.md Milestone 3 poin 3, reuse
/// `ReceiptService` Milestone 2).
final AutoDisposeFutureProviderFamily<SaleResult, int> saleDetailProvider =
    FutureProvider.autoDispose.family<SaleResult, int>((ref, saleId) {
  return ref.watch(saleRepoProvider).getDetail(saleId);
});
