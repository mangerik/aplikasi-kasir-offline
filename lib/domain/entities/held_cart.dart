import 'cart_item.dart';

/// Transaksi yang ditahan/parkir (hold) — lihat architecture.md §4 tabel
/// `held_carts` dan plan.md Milestone 2 poin 8.
class HeldCart {
  const HeldCart({
    required this.id,
    this.label,
    required this.items,
    required this.transactionDiscount,
    required this.createdAt,
  });

  final int id;
  final String? label;
  final List<CartItem> items;

  /// Diskon total transaksi (nominal) yang tersimpan bersama keranjang.
  final int transactionDiscount;
  final DateTime createdAt;

  int get itemsSubtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  int get total => (itemsSubtotal - transactionDiscount).clamp(0, itemsSubtotal).toInt();

  double get totalQty => items.fold(0, (sum, item) => sum + item.qty);
}
