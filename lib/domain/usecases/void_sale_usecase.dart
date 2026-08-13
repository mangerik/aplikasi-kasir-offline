import '../entities/app_user.dart';
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
  const VoidSaleUsecase(this._repository, {this.actor});

  final SaleRepository _repository;

  /// Siapa yang membatalkan (PRD v1.1 §8.3.D) — dicatat di
  /// `sales.voided_by_user_id`. Void adalah aksi yang menyentuh uang; tanpa
  /// nama di belakangnya, "kas kurang" tidak pernah bisa ditelusuri.
  ///
  /// Penjagaan bahwa Kasir TIDAK BOLEH void (AC-8.6) ada di lapisan UI &
  /// router; pemeriksaan di sini adalah jaring terakhirnya.
  final AppUser? actor;

  /// Melempar `TransaksiTidakDitemukanException` bila [saleId] tidak ada,
  /// `TransaksiSudahDibatalkanException` bila transaksi tersebut sudah
  /// pernah di-void sebelumnya, atau `HutangSudahLunasException` bila
  /// transaksi itu hutang yang sudah dilunasi — TIDAK menyentuh database
  /// sama sekali di ketiga kasus itu.
  Future<void> call(int saleId) async {
    final sale = await _repository.getDetail(saleId);
    if (sale.status == 'voided') {
      throw const TransaksiSudahDibatalkanException();
    }
    // Hutang lunas TIDAK boleh di-void: uangnya sudah diterima, sedangkan
    // void akan mengembalikan stok & menghapus omzetnya dari laporan —
    // laci kas dan laporan langsung tidak cocok. Pengecekan yang sama
    // diulang di dalam `db.transaction()` repository sebagai jaring akhir.
    if (sale.debtPaidAt != null) {
      throw const HutangSudahLunasException();
    }
    final by = actor;
    if (by != null && !by.role.canVoidSale) {
      throw const AksesDitolakException();
    }
    await _repository.voidSale(saleId, voidedByUserId: by?.id);
  }
}
