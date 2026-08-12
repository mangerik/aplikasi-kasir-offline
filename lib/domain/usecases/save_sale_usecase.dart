import '../entities/cart_item.dart';
import '../entities/points_settings.dart';
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
  /// [transactionDiscount] adalah diskon MANUAL yang diketik kasir.
  /// Potongan hasil penukaran poin ([pointsRedeemed]) dijumlahkan ke
  /// dalamnya di sini, karena penukaran poin memang diwujudkan sebagai
  /// diskon transaksi biasa (K-7.6) — dengan begitu laporan, laba kotor,
  /// dan struk yang sudah ada bekerja tanpa perubahan konsep.
  Future<SaleResult> call({
    required List<CartItem> items,
    required int transactionDiscount,
    required String paymentMethod,
    required int paidAmount,
    String? customerName,
    int? customerId,
    int pointsRedeemed = 0,
    PointsSettings points = const PointsSettings(),
    String? note,
  }) async {
    if (items.isEmpty) {
      throw const KeranjangKosongException();
    }

    final itemsSubtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    final manualDiscount = transactionDiscount.clamp(0, itemsSubtotal).toInt();

    // Penukaran poin hanya sah bila programnya menyala DAN ada pelanggan
    // yang dipilih — tanpa pelanggan tidak ada saldo yang bisa dikurangi.
    final effectiveRedeem =
        (points.enabled && customerId != null && pointsRedeemed > 0)
            ? pointsRedeemed
            : 0;
    final redeemValue = points
        .rupiahFor(effectiveRedeem)
        .clamp(0, itemsSubtotal - manualDiscount)
        .toInt();
    final clampedDiscount = manualDiscount + redeemValue;
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
      customerId: customerId,
      pointsRedeemed: effectiveRedeem,
      points: points,
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
    );
  }
}
