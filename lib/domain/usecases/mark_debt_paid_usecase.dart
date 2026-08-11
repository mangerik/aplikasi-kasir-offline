import '../repositories/repository_exceptions.dart';
import '../repositories/sale_repository.dart';

/// Usecase "pelunasan hutang" (plan.md Milestone 3 poin 4) — satu-satunya
/// pintu masuk dari layer `features/transactions` untuk menandai transaksi
/// hutang sebagai lunas.
///
/// Tanggung jawab MURNI validasi domain (transaksi harus ada dan berstatus
/// `'debt_unpaid'`) sebelum delegasi ke `SaleRepository.markDebtPaid` —
/// sama seperti pola `SaveSaleUsecase` (lihat
/// `domain/usecases/save_sale_usecase.dart`).
class MarkDebtPaidUsecase {
  const MarkDebtPaidUsecase(this._repository);

  final SaleRepository _repository;

  /// Melempar `TransaksiTidakDitemukanException` bila [saleId] tidak ada,
  /// atau `TransaksiBukanHutangException` bila transaksi tersebut bukan
  /// hutang yang masih belum lunas — TIDAK menyentuh database sama sekali
  /// di kedua kasus itu.
  Future<void> call(int saleId) async {
    final sale = await _repository.getDetail(saleId);
    if (sale.status != 'debt_unpaid') {
      throw const TransaksiBukanHutangException();
    }
    await _repository.markDebtPaid(saleId);
  }
}
