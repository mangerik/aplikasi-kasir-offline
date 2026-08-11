import '../entities/cart_item.dart';
import '../entities/sale_result.dart';

/// Kontrak repository Penjualan.
///
/// Implementasi (Drift) ada di `data/repositories/sale_repository_impl.dart`
/// — WAJIB atomik (satu `db.transaction()`): insert `sales` + seluruh
/// `sale_items` + update `products.stock` (untuk item terdaftar) + insert
/// `stock_movements(type='sale')`, plus generator nomor invoice harian
/// berurutan `YYYYMMDD-XXXX` di dalam transaksi yang sama (anti duplikat).
/// Lihat architecture.md §4 "Aturan Integritas" poin 1 & 4, dan plan.md
/// Milestone 2 poin 6.
abstract class SaleRepository {
  /// Menyimpan satu transaksi penjualan.
  ///
  /// [items] tidak boleh kosong dan [paidAmount] tunai wajib cukup —
  /// validasi tersebut ada di `SaveSaleUsecase` (domain), BUKAN di sini;
  /// implementasi repo boleh mengasumsikan input sudah tervalidasi.
  Future<SaleResult> saveSale({
    required List<CartItem> items,
    required int transactionDiscount,
    required String paymentMethod,
    required int paidAmount,
    String? customerName,
    String? note,
  });
}
