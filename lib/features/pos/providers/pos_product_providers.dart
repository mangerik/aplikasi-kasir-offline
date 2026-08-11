import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/product.dart';
import '../../products/providers/product_providers.dart';

/// Filter produk khusus layar Kasir: kata kunci pencarian (nama/barcode)
/// dan kategori terpilih (`null` = semua kategori). Terpisah dari
/// `ProductFilter` (fitur Produk) karena `onlyActive` SELALU `true` di sini
/// (plan.md Milestone 2 poin 2: "Hanya produk aktif yang tampil").
class PosProductFilter {
  const PosProductFilter({this.query = '', this.categoryId});

  final String query;
  final int? categoryId;

  PosProductFilter copyWith({
    String? query,
    int? categoryId,
    bool clearCategory = false,
  }) {
    return PosProductFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PosProductFilter && other.query == query && other.categoryId == categoryId);

  @override
  int get hashCode => Object.hash(query, categoryId);
}

/// Notifier filter produk Kasir. Debounce **150ms** (architecture.md §5.1:
/// "Pencarian produk memakai stream Drift dengan LIKE, debounce 150 ms" —
/// lebih cepat dari layar Produk/300ms karena ini dipakai saat transaksi
/// berlangsung dan butuh respons lebih instan).
class PosProductFilterNotifier extends Notifier<PosProductFilter> {
  Timer? _debounce;

  @override
  PosProductFilter build() {
    ref.onDispose(() => _debounce?.cancel());
    return const PosProductFilter();
  }

  void setQuery(String rawQuery) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      state = state.copyWith(query: rawQuery.trim());
    });
  }

  void setCategory(int? categoryId) {
    state = state.copyWith(categoryId: categoryId, clearCategory: categoryId == null);
  }
}

final NotifierProvider<PosProductFilterNotifier, PosProductFilter> posProductFilterProvider =
    NotifierProvider<PosProductFilterNotifier, PosProductFilter>(PosProductFilterNotifier.new);

/// Stream reaktif daftar produk AKTIF sesuai [PosProductFilter] — dipakai
/// grid produk layar Kasir. Reuse `productRepoProvider` dari fitur Produk
/// (tetap lewat kontrak domain `ProductRepository`, tidak mengimpor Drift
/// langsung — lihat architecture.md §3).
final StreamProvider<List<Product>> posProductListProvider = StreamProvider<List<Product>>((ref) {
  final filter = ref.watch(posProductFilterProvider);
  final repo = ref.watch(productRepoProvider);
  return repo.watchAll(
    query: filter.query.isEmpty ? null : filter.query,
    categoryId: filter.categoryId,
    onlyActive: true,
  );
});
