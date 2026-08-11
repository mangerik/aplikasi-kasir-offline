import '../entities/cart_item.dart';
import '../entities/sale_result.dart';
import '../repositories/repository_exceptions.dart';
import '../repositories/sale_repository.dart';

/// Usecase "simpan penjualan" (plan.md Milestone 2 poin 6) — satu-satunya
/// pintu masuk dari layer `features/pos` untuk menyimpan transaksi.
///
/// Tanggung jawab usecase ini murni VALIDASI & ORKESTRASI di layer domain
/// (keranjang tidak boleh kosong, uang tunai wajib cukup, nama pelanggan
/// wajib untuk hutang). ATOMISITAS penulisan ke database (insert `sales` +
/// `sale_items` + update stok + `stock_movements`, plus nomor invoice, dalam
/// SATU `db.transaction()`) adalah tanggung jawab implementasi
/// [SaleRepository] di layer data
/// (`data/repositories/sale_repository_impl.dart`), sesuai aturan
/// arsitektur `features -> domain <- data` (architecture.md §3).
class SaveSaleUsecase {
  const SaveSaleUsecase(this._repository);

  final SaleRepository _repository;

  /// Menyimpan transaksi. Melempar [KeranjangKosongException],
  /// [UangTidakCukupException], atau [NamaPelangganWajibException] bila
  /// validasi gagal — TIDAK menyentuh database sama sekali di kasus itu.
  Future<SaleResult> call({
    required List<CartItem> items,
    required int transactionDiscount,
    required String paymentMethod,
    required int paidAmount,
    String? customerName,
    String? note,
  }) async {
    if (items.isEmpty) {
      throw const KeranjangKosongException();
    }

    final itemsSubtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    final clampedDiscount = transactionDiscount.clamp(0, itemsSubtotal).toInt();
    final total = itemsSubtotal - clampedDiscount;

    if (paymentMethod == 'cash' && paidAmount < total) {
      throw UangTidakCukupException(total: total, dibayar: paidAmount);
    }

    final trimmedCustomerName = customerName?.trim();
    if (paymentMethod == 'debt' &&
        (trimmedCustomerName == null || trimmedCustomerName.isEmpty)) {
      throw const NamaPelangganWajibException();
    }

    final trimmedNote = note?.trim();

    return _repository.saveSale(
      items: items,
      transactionDiscount: clampedDiscount,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      customerName: (trimmedCustomerName == null || trimmedCustomerName.isEmpty)
          ? null
          : trimmedCustomerName,
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
    );
  }
}
