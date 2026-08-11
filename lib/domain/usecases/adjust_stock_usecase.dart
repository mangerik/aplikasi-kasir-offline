import '../repositories/repository_exceptions.dart';
import '../repositories/stock_repository.dart';

/// Usecase "penyesuaian stok manual" (plan.md Milestone 4 poin 1) —
/// satu-satunya pintu masuk dari layer `features/inventory` untuk stok
/// masuk, stok keluar, dan opname.
///
/// Tanggung jawab MURNI validasi domain sebelum delegasi ke
/// `StockRepository.adjustStock`, yang bertanggung jawab atas ATOMISITAS
/// update `products.stock` + insert `stock_movements` dalam SATU
/// `db.transaction()` (architecture.md §4).
class AdjustStockUsecase {
  const AdjustStockUsecase(this._repository);

  final StockRepository _repository;

  static const Set<String> _validTypes = {'adjust_in', 'adjust_out', 'opname'};

  /// Melempar:
  /// - `ArgumentError` bila [type] bukan salah satu dari `adjust_in`/
  ///   `adjust_out`/`opname` (kesalahan programmer, bukan input pengguna —
  ///   UI hanya boleh mengirim salah satu dari ketiganya).
  /// - `JumlahPenyesuaianTidakValidException` bila [amount] <= 0 (stok
  ///   masuk/keluar) atau [amount] < 0 (opname).
  /// - `AlasanPenyesuaianWajibException` bila [note] kosong/tidak diisi.
  Future<void> call({
    required int productId,
    required String type,
    required double amount,
    String? note,
  }) async {
    if (!_validTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Jenis penyesuaian stok tidak dikenal');
    }
    final isOpname = type == 'opname';
    if (isOpname ? amount < 0 : amount <= 0) {
      throw const JumlahPenyesuaianTidakValidException();
    }
    final trimmedNote = note?.trim();
    if (trimmedNote == null || trimmedNote.isEmpty) {
      throw const AlasanPenyesuaianWajibException();
    }

    await _repository.adjustStock(
      productId: productId,
      type: type,
      amount: amount,
      note: trimmedNote,
    );
  }
}
