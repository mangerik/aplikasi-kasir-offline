import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/category_repository_impl.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/repositories/category_repository.dart';

/// Repository Kategori (lihat architecture.md §6 tabel Provider).
final Provider<CategoryRepository> categoryRepoProvider =
    Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CategoryRepositoryImpl(database);
});

/// Stream reaktif seluruh kategori, dipakai oleh chip filter (layar Produk)
/// dan dropdown kategori (form produk).
final StreamProvider<List<Category>> categoryListProvider =
    StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepoProvider).watchAll();
});
