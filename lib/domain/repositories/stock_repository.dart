import '../entities/stock_movement.dart';

/// Kontrak repository Stok — penyesuaian manual & riwayat pergerakan
/// (plan.md Milestone 4 poin 1 & 2).
///
/// Implementasi (Drift) ada di `data/repositories/stock_repository_impl.dart`
/// — `adjustStock` WAJIB atomik (satu `db.transaction()`): update
/// `products.stock` + insert `stock_movements`, sama seperti pola
/// `saveSale`/`voidSale` di `SaleRepository` (architecture.md §4).
abstract class StockRepository {
  /// Menyesuaikan stok satu produk secara manual.
  ///
  /// [type] wajib salah satu dari `'adjust_in'` (stok masuk), `'adjust_out'`
  /// (stok keluar), atau `'opname'` (stok hasil hitung fisik).
  ///
  /// Arti [amount] tergantung [type]:
  /// - `adjust_in`/`adjust_out`: jumlah perubahan (SELALU positif) — stok
  ///   akhir dihitung `stok sekarang ± amount`.
  /// - `opname`: nilai stok akhir ABSOLUT hasil hitung fisik (bukan
  ///   selisih) — `qty_change` yang tersimpan di `stock_movements` dihitung
  ///   otomatis sebagai `amount - stok sekarang`.
  ///
  /// Validasi [amount]/[note] (wajib diisi) ada di `AdjustStockUsecase`
  /// (domain), BUKAN di sini. Melempar `ProdukTidakDitemukanException` bila
  /// [productId] tidak ada.
  Future<void> adjustStock({
    required int productId,
    required String type,
    required double amount,
    String? note,
    int? userId,
  });

  /// Riwayat pergerakan stok SATU produk, terbaru dulu, dipaginasi lewat
  /// `LIMIT`/`OFFSET` (index `stock_movements(product_id, created_at)`,
  /// architecture.md §4) — pola sama dengan `SaleRepository.getHistory`.
  Future<List<StockMovement>> getMovements({
    required int productId,
    required int limit,
    required int offset,
  });
}
