import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/customer_repository_impl.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/customer_point_entry.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/repositories/customer_repository.dart';

/// Repository Pelanggan (architecture.md §6 tabel Provider, PRD v1.1 §7).
final Provider<CustomerRepository> customerRepoProvider =
    Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(ref.watch(databaseProvider));
});

/// Filter aktif layar Pelanggan: kata kunci + saklar "Punya hutang"
/// (menggantikan layar daftar hutang terpisah, PRD §7.6).
class CustomerFilter {
  const CustomerFilter({this.query = '', this.onlyWithDebt = false, this.includeInactive = false});

  final String query;
  final bool onlyWithDebt;
  final bool includeInactive;

  CustomerFilter copyWith({String? query, bool? onlyWithDebt, bool? includeInactive}) {
    return CustomerFilter(
      query: query ?? this.query,
      onlyWithDebt: onlyWithDebt ?? this.onlyWithDebt,
      includeInactive: includeInactive ?? this.includeInactive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerFilter &&
          other.query == query &&
          other.onlyWithDebt == onlyWithDebt &&
          other.includeInactive == includeInactive);

  @override
  int get hashCode => Object.hash(query, onlyWithDebt, includeInactive);
}

class CustomerFilterNotifier extends Notifier<CustomerFilter> {
  @override
  CustomerFilter build() => const CustomerFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setOnlyWithDebt(bool value) => state = state.copyWith(onlyWithDebt: value);

  void setIncludeInactive(bool value) => state = state.copyWith(includeInactive: value);

  void reset() => state = const CustomerFilter();
}

final NotifierProvider<CustomerFilterNotifier, CustomerFilter> customerFilterProvider =
    NotifierProvider<CustomerFilterNotifier, CustomerFilter>(CustomerFilterNotifier.new);

/// State daftar pelanggan TERPAGINASI — pola sama dengan `HistoryState`
/// (M3): halaman pertama di `build()`, halaman berikutnya lewat
/// [CustomerListNotifier.loadMore] (AC-7.15).
class CustomerListState {
  const CustomerListState({
    this.items = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<CustomerListItem> items;
  final bool hasMore;
  final bool isLoadingMore;

  CustomerListState copyWith({
    List<CustomerListItem>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CustomerListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  int get totalDebt => items.fold<int>(0, (sum, item) => sum + item.totalDebt);

  int get debtorCount => items.where((item) => item.hasDebt).length;
}

class CustomerListNotifier extends AsyncNotifier<CustomerListState> {
  static const int pageSize = 30;

  @override
  Future<CustomerListState> build() async {
    final filter = ref.watch(customerFilterProvider);
    final items = await _fetch(filter, offset: 0);
    return CustomerListState(items: items, hasMore: items.length == pageSize);
  }

  Future<List<CustomerListItem>> _fetch(CustomerFilter filter, {required int offset}) {
    return ref.read(customerRepoProvider).search(
          query: filter.query,
          onlyWithDebt: filter.onlyWithDebt,
          includeInactive: filter.includeInactive,
          limit: pageSize,
          offset: offset,
        );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filter = ref.read(customerFilterProvider);
      final next = await _fetch(filter, offset: current.items.length);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next],
          hasMore: next.length == pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final AsyncNotifierProvider<CustomerListNotifier, CustomerListState> customerListProvider =
    AsyncNotifierProvider<CustomerListNotifier, CustomerListState>(CustomerListNotifier.new);

/// Ringkasan hutang seluruh pelanggan untuk kartu di tab Laporan (PRD
/// §7.6) — dua angka saja, dihitung lewat agregasi SQL.
class CustomerDebtOverview {
  const CustomerDebtOverview({
    required this.totalDebt,
    required this.debtorCount,
    required this.customerCount,
  });

  final int totalDebt;
  final int debtorCount;
  final int customerCount;
}

final FutureProvider<CustomerDebtOverview> customerDebtOverviewProvider =
    FutureProvider<CustomerDebtOverview>((ref) async {
  final repo = ref.watch(customerRepoProvider);
  // Penghutang jumlahnya kecil (yang aktif ditagih), jadi memuat daftarnya
  // untuk dijumlahkan tetap murah — sementara jumlah pelanggan total
  // diambil dari pencarian tanpa filter dengan limit besar.
  final debtors = await repo.search(onlyWithDebt: true, limit: 1000);
  final all = await repo.search(limit: 1000);
  return CustomerDebtOverview(
    totalDebt: debtors.fold<int>(0, (sum, item) => sum + item.totalDebt),
    debtorCount: debtors.length,
    customerCount: all.length,
  );
});

/// Satu pelanggan (untuk layar detail & tautan dari detail transaksi).
final AutoDisposeFutureProviderFamily<Customer, int> customerDetailProvider =
    FutureProvider.autoDispose.family<Customer, int>((ref, id) {
  return ref.watch(customerRepoProvider).getById(id);
});

/// Ringkasan satu pelanggan (total belanja, transaksi, hutang, poin).
final AutoDisposeFutureProviderFamily<CustomerSummary, int> customerSummaryProvider =
    FutureProvider.autoDispose.family<CustomerSummary, int>((ref, id) {
  return ref.watch(customerRepoProvider).getSummary(id);
});

/// Riwayat poin satu pelanggan (halaman pertama, cukup untuk layar detail).
final AutoDisposeFutureProviderFamily<List<CustomerPointEntry>, int>
    customerPointEntriesProvider =
    FutureProvider.autoDispose.family<List<CustomerPointEntry>, int>((ref, id) {
  return ref.watch(customerRepoProvider).getPointEntries(id, limit: 50, offset: 0);
});

/// Riwayat belanja satu pelanggan, TERPAGINASI (AC-7.15) — detail dengan
/// 5.000 transaksi tetap terbuka mulus karena hanya 20 baris pertama yang
/// dimuat.
class CustomerSalesState {
  const CustomerSalesState({
    this.items = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<Sale> items;
  final bool hasMore;
  final bool isLoadingMore;

  CustomerSalesState copyWith({List<Sale>? items, bool? hasMore, bool? isLoadingMore}) {
    return CustomerSalesState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class CustomerSalesNotifier
    extends AutoDisposeFamilyAsyncNotifier<CustomerSalesState, int> {
  static const int pageSize = 20;

  @override
  Future<CustomerSalesState> build(int arg) async {
    final items = await _fetch(offset: 0);
    return CustomerSalesState(items: items, hasMore: items.length == pageSize);
  }

  Future<List<Sale>> _fetch({required int offset}) {
    return ref
        .read(customerRepoProvider)
        .getSales(arg, limit: pageSize, offset: offset);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _fetch(offset: current.items.length);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next],
          hasMore: next.length == pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final AutoDisposeAsyncNotifierProviderFamily<CustomerSalesNotifier, CustomerSalesState, int>
    customerSalesProvider =
    AsyncNotifierProvider.autoDispose.family<CustomerSalesNotifier, CustomerSalesState, int>(
  CustomerSalesNotifier.new,
);

/// Hasil pencarian untuk **pemilih pelanggan** di sheet pembayaran —
/// `autoDispose` + family supaya tiap ketikan menghasilkan query sendiri
/// dan sheet yang ditutup tidak menyisakan cache.
final AutoDisposeFutureProviderFamily<List<CustomerListItem>, String>
    customerPickerResultsProvider =
    FutureProvider.autoDispose.family<List<CustomerListItem>, String>((ref, query) {
  return ref.watch(customerRepoProvider).search(query: query, limit: 20);
});
