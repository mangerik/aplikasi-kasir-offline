import '../entities/cart_item.dart';
import '../entities/held_cart.dart';

/// Kontrak repository transaksi yang ditahan/parkir (hold).
///
/// Implementasi (Drift) ada di
/// `data/repositories/held_cart_repository_impl.dart`, menyimpan isi
/// keranjang sebagai JSON di kolom `held_carts.cart_json` (lihat
/// architecture.md §4 dan plan.md Milestone 2 poin 8).
abstract class HeldCartRepository {
  Stream<List<HeldCart>> watchAll();

  /// Menahan/parkir keranjang, mengembalikan id baris `held_carts` baru.
  Future<int> hold({
    String? label,
    required List<CartItem> items,
    required int transactionDiscount,
  });

  Future<HeldCart?> getById(int id);

  /// Menghapus hold (dipanggil setelah "lanjutkan" transaksi, atau saat
  /// pengguna membatalkan hold).
  Future<void> delete(int id);
}
