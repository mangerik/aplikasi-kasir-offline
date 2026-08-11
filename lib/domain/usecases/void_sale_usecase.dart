import '../repositories/repository_exceptions.dart';
import '../repositories/sale_repository.dart';

/// Usecase "void/batalkan transaksi" (plan.md Milestone 3 poin 5) —
/// satu-satunya pintu masuk dari layer `features/transactions` untuk
/// membatalkan transaksi.
///
/// Tanggung jawab MURNI validasi domain (transaksi harus ada dan belum
/// pernah di-void sebelumnya) sebelum delegasi ke
/// `SaleRepository.voidSale`, yang bertanggung jawab atas ATOMISITAS
/// pengembalian stok + `stock_movements(type='void_return')` dalam SATU
/// `db.transaction()` (architecture.md §4 poin 2). Konfirmasi UI dan
/// gerbang PIN (hook, lihat `features/transactions/utils/pin_gate.dart`)
/// dilakukan DI LUAR usecase ini, sebelum dipanggil.
class VoidSaleUsecase {
  const VoidSaleUsecase(this._repository);

  final SaleRepository _repository;

  /// Melempar `TransaksiTidakDitemukanException` bila [saleId] tidak ada,
  /// atau `TransaksiSudahDibatalkanException` bila transaksi tersebut
  /// sudah pernah di-void sebelumnya — TIDAK menyentuh database sama
  /// sekali di kedua kasus itu.
  Future<void> call(int saleId) async {
    final sale = await _repository.getDetail(saleId);
    if (sale.status == 'voided') {
      throw const TransaksiSudahDibatalkanException();
    }
    await _repository.voidSale(saleId);
  }
}
