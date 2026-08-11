import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/product_repository_impl.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/product_repository.dart';

/// Repository Produk (lihat architecture.md §6 tabel Provider).
final Provider<ProductRepository> productRepoProvider =
    Provider<ProductRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ProductRepositoryImpl(database);
});

/// Filter aktif untuk daftar produk: kata kunci pencarian (nama/barcode)
/// dan kategori terpilih (`null` = semua kategori).
class ProductFilter {
  const ProductFilter({this.query = '', this.categoryId});

  final String query;
  final int? categoryId;

  ProductFilter copyWith({String? query, int? categoryId, bool clearCategory = false}) {
    return ProductFilter(
      query: query ?? this.query,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductFilter && other.query == query && other.categoryId == categoryId);

  @override
  int get hashCode => Object.hash(query, categoryId);
}

/// Notifier filter produk. Pencarian real-time di-debounce 300ms (lihat
/// architecture.md §5.1: "debounce 150 ms" untuk layar Kasir — untuk layar
/// Produk dipakai 300ms karena hasil ditampilkan sebagai list biasa, bukan
/// grid kasir yang butuh respons lebih instan) supaya query ke database
/// tidak dijalankan pada setiap ketukan huruf.
class ProductFilterNotifier extends Notifier<ProductFilter> {
  Timer? _debounce;

  @override
  ProductFilter build() {
    ref.onDispose(() => _debounce?.cancel());
    return const ProductFilter();
  }

  /// Dipanggil langsung dari `onChanged` search field. Query efektif baru
  /// diterapkan setelah pengguna berhenti mengetik selama 300ms.
  void setQuery(String rawQuery) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(query: rawQuery.trim());
    });
  }

  /// Dipanggil dari chip filter kategori. `null` berarti "Semua kategori".
  void setCategory(int? categoryId) {
    state = state.copyWith(categoryId: categoryId, clearCategory: categoryId == null);
  }
}

final NotifierProvider<ProductFilterNotifier, ProductFilter> productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(ProductFilterNotifier.new);

/// Stream reaktif daftar produk sesuai [ProductFilter] aktif, langsung dari
/// Drift (auto-update saat data berubah).
final StreamProvider<List<Product>> productListProvider =
    StreamProvider<List<Product>>((ref) {
  final filter = ref.watch(productFilterProvider);
  final repo = ref.watch(productRepoProvider);
  return repo.watchAll(
    query: filter.query.isEmpty ? null : filter.query,
    categoryId: filter.categoryId,
  );
});
