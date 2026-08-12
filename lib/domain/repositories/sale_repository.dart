import '../entities/cart_item.dart';
import '../entities/points_settings.dart';
import '../entities/sale.dart';
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
  ///
  /// Sejak `schemaVersion` 2 (PRD v1.1 §7) penyimpanan ini SEKALIGUS
  /// menulis buku besar poin di dalam transaksi yang sama:
  /// - [customerId] menautkan transaksi ke pelanggan ([customerName] tetap
  ///   ditulis sebagai snapshot historis, K-7.1);
  /// - [pointsRedeemed] menghasilkan entri `redeem` (nilainya sudah
  ///   termasuk di dalam [transactionDiscount], K-7.6);
  /// - [points] menentukan berapa poin yang didapat dari total akhir
  ///   (entri `earn`, AC-7.7 & AC-7.10). Program mati → tidak ada entri
  ///   poin sama sekali (AC-7.6).
  Future<SaleResult> saveSale({
    required List<CartItem> items,
    required int transactionDiscount,
    required String paymentMethod,
    required int paidAmount,
    String? customerName,
    int? customerId,
    int pointsRedeemed = 0,
    PointsSettings points = const PointsSettings(),
    String? note,
    int? userId,
    String? userName,
  });

  /// Daftar riwayat transaksi, terbaru dulu, difilter & DIPAGINASI lewat
  /// SQL `LIMIT`/`OFFSET` (plan.md Milestone 3 poin 2: "infinite
  /// scroll/pagination efisien" — memakai index `sales(created_at)`/
  /// `sales(status)` dari architecture.md §4).
  ///
  /// Semua filter `null` berarti "semua": [startDate]/[endDate] rentang
  /// tanggal (inklusif), [paymentMethod] (`'cash'|'noncash'|'debt'`),
  /// [status] (`'completed'|'debt_unpaid'|'voided'`).
  Future<List<Sale>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? status,
    int? userId,
    required int limit,
    required int offset,
  });

  /// Detail LENGKAP satu transaksi (header + seluruh item), dipakai layar
  /// Detail Transaksi dan dibagikan ulang sebagai struk lewat
  /// `ReceiptService` (reuse format Milestone 2, plan.md Milestone 3 poin
  /// 3). Melempar `TransaksiTidakDitemukanException` bila [saleId] tidak
  /// ada.
  Future<SaleResult> getDetail(int saleId);

  /// Tandai transaksi hutang sebagai LUNAS: `status` -> `'completed'`,
  /// `debt_paid_at` -> sekarang (plan.md Milestone 3 poin 4).
  ///
  /// Validasi bahwa [saleId] memang berstatus `'debt_unpaid'` ada di
  /// `MarkDebtPaidUsecase` (domain), BUKAN di sini.
  Future<void> markDebtPaid(int saleId);

  /// Void/batalkan transaksi (plan.md Milestone 3 poin 5,
  /// architecture.md §4 "Aturan Integritas" poin 2): `status` ->
  /// `'voided'`, `voided_at` -> sekarang, KEMBALIKAN stok tiap item
  /// terdaftar (`productId != null`) + insert
  /// `stock_movements(type='void_return')` — SEMUA dalam SATU
  /// `db.transaction()`. Item bebas (`productId == null`) TIDAK menyentuh
  /// stok. Transaksi tidak pernah dihapus, hanya ditandai.
  ///
  /// Sejak `schemaVersion` 2: poin yang sempat diberikan transaksi ini
  /// DITARIK kembali dan poin yang sempat ditukar DIKEMBALIKAN, keduanya
  /// sebagai entri `void_return` terpisah di dalam transaksi DB yang sama
  /// (PRD v1.1 §7.3.C, AC-7.8). Saldo tidak pernah negatif.
  ///
  /// Sejak `schemaVersion` 3: [voidedByUserId] dicatat di
  /// `sales.voided_by_user_id` (PRD v1.1 §8.3.D).
  ///
  /// Validasi bahwa [saleId] belum pernah di-void ada di `VoidSaleUsecase`
  /// (domain), BUKAN di sini.
  Future<void> voidSale(int saleId, {int? voidedByUserId});
}
