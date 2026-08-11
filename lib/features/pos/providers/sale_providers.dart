import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/sale_repository_impl.dart';
import '../../../domain/repositories/sale_repository.dart';
import '../../../domain/usecases/save_sale_usecase.dart';

/// Repository Penjualan (lihat architecture.md §6 tabel Provider).
final Provider<SaleRepository> saleRepoProvider = Provider<SaleRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SaleRepositoryImpl(database);
});

/// Usecase simpan penjualan (plan.md Milestone 2 poin 6) — satu-satunya
/// jalur dari UI untuk menyimpan transaksi.
final Provider<SaveSaleUsecase> saveSaleUsecaseProvider = Provider<SaveSaleUsecase>((ref) {
  return SaveSaleUsecase(ref.watch(saleRepoProvider));
});
