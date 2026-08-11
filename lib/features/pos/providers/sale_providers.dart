import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/sale_repository_impl.dart';
import '../../../domain/repositories/sale_repository.dart';
import '../../../domain/usecases/mark_debt_paid_usecase.dart';
import '../../../domain/usecases/save_sale_usecase.dart';
import '../../../domain/usecases/void_sale_usecase.dart';

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

/// Usecase pelunasan hutang (plan.md Milestone 3 poin 4) — satu-satunya
/// jalur dari UI (`features/transactions`) untuk menandai lunas.
final Provider<MarkDebtPaidUsecase> markDebtPaidUsecaseProvider =
    Provider<MarkDebtPaidUsecase>((ref) {
  return MarkDebtPaidUsecase(ref.watch(saleRepoProvider));
});

/// Usecase void transaksi (plan.md Milestone 3 poin 5) — satu-satunya
/// jalur dari UI (`features/transactions`) untuk membatalkan transaksi.
final Provider<VoidSaleUsecase> voidSaleUsecaseProvider = Provider<VoidSaleUsecase>((ref) {
  return VoidSaleUsecase(ref.watch(saleRepoProvider));
});
