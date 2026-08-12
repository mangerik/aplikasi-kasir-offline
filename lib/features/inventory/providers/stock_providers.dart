import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/stock_repository_impl.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/stock_movement.dart';
import '../../../domain/repositories/stock_repository.dart';
import '../../../domain/usecases/adjust_stock_usecase.dart';
import '../../auth/providers/auth_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../settings/providers/settings_providers.dart';

/// Repository Stok (lihat architecture.md §6 tabel Provider, plan.md
/// Milestone 4).
final Provider<StockRepository> stockRepoProvider = Provider<StockRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return StockRepositoryImpl(database);
});

/// Usecase penyesuaian stok manual (plan.md Milestone 4 poin 1) —
/// satu-satunya jalur dari UI untuk stok masuk/keluar/opname.
final Provider<AdjustStockUsecase> adjustStockUsecaseProvider = Provider<AdjustStockUsecase>((
  ref,
) {
  return AdjustStockUsecase(
    ref.watch(stockRepoProvider),
    actor: ref.watch(currentUserProvider),
  );
});

/// Threshold stok menipis default global — dibaca dari `settings` (key
/// `low_stock_default`, diisi lewat layar Pengaturan Milestone 5). Belum
/// diisi -> fallback ke [Product.defaultLowStockThreshold] (sama seperti
/// keputusan teknis M1, lihat plan.md catatan keputusan 2026-08-11 M1).
final FutureProvider<double> lowStockDefaultThresholdProvider = FutureProvider<double>((
  ref,
) async {
  final raw = await ref.watch(settingsRepoProvider).getValue('low_stock_default');
  if (raw == null || raw.trim().isEmpty) return Product.defaultLowStockThreshold;
  return double.tryParse(raw.trim()) ?? Product.defaultLowStockThreshold;
});

/// Stream reaktif JUMLAH produk stok menipis — dipakai badge tab Produk
/// (plan.md Milestone 4 poin 3). `0` selama threshold default masih dimuat.
final StreamProvider<int> lowStockCountProvider = StreamProvider<int>((ref) {
  final thresholdAsync = ref.watch(lowStockDefaultThresholdProvider);
  final threshold = thresholdAsync.value;
  if (threshold == null) return const Stream.empty();
  return ref.watch(productRepoProvider).watchLowStockCount(defaultThreshold: threshold);
});

/// Stream reaktif daftar produk stok menipis — layar "Stok Menipis" (plan.md
/// Milestone 4 poin 3).
final StreamProvider<List<Product>> lowStockListProvider = StreamProvider<List<Product>>((ref) {
  final thresholdAsync = ref.watch(lowStockDefaultThresholdProvider);
  final threshold = thresholdAsync.value;
  if (threshold == null) return const Stream.empty();
  return ref.watch(productRepoProvider).watchLowStock(defaultThreshold: threshold);
});

/// State daftar riwayat pergerakan stok SATU produk, TERPAGINASI (pola sama
/// dengan `HistoryListNotifier` di `features/transactions`, plan.md
/// Milestone 4 poin 2).
class StockMovementState {
  const StockMovementState({this.items = const [], this.hasMore = true, this.isLoadingMore = false});

  final List<StockMovement> items;
  final bool hasMore;
  final bool isLoadingMore;

  StockMovementState copyWith({List<StockMovement>? items, bool? hasMore, bool? isLoadingMore}) {
    return StockMovementState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Notifier riwayat pergerakan stok satu produk — `family` per [productId].
class StockMovementNotifier extends FamilyAsyncNotifier<StockMovementState, int> {
  static const int pageSize = 30;

  @override
  Future<StockMovementState> build(int arg) async {
    final items = await _fetch(offset: 0);
    return StockMovementState(items: items, hasMore: items.length == pageSize);
  }

  Future<List<StockMovement>> _fetch({required int offset}) {
    return ref.read(stockRepoProvider).getMovements(productId: arg, limit: pageSize, offset: offset);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final nextItems = await _fetch(offset: current.items.length);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...nextItems],
          hasMore: nextItems.length == pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Muat ulang dari halaman pertama — dipanggil setelah penyesuaian stok
  /// berhasil disimpan.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final AsyncNotifierProviderFamily<StockMovementNotifier, StockMovementState, int>
stockMovementListProvider =
    AsyncNotifierProvider.family<StockMovementNotifier, StockMovementState, int>(
  StockMovementNotifier.new,
);
