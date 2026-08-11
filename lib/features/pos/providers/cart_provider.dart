import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cart_item.dart';
import '../../../domain/entities/held_cart.dart';
import '../../../domain/entities/product.dart';

/// State keranjang kasir aktif — IN-MEMORY, tidak menyentuh database
/// kecuali saat "tahan" (hold) atau "bayar" (architecture.md §5.1, plan.md
/// Milestone 2 poin 1).
class CartState {
  const CartState({this.items = const [], this.transactionDiscount = 0});

  final List<CartItem> items;

  /// Diskon total transaksi, SELALU nominal (lihat dokumentasi
  /// [CartItem.discount] untuk alasan yang sama berlaku di level item).
  final int transactionDiscount;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Jumlah baris (BUKAN jumlah qty) di keranjang.
  int get lineCount => items.length;

  /// Total qty seluruh baris (dipakai badge ringkas di bar keranjang).
  double get totalQty => items.fold(0, (sum, item) => sum + item.qty);

  /// Subtotal = jumlah `lineTotal` tiap baris (SUDAH bersih dari diskon per
  /// item, BELUM dikurangi diskon transaksi) — konsisten dengan makna
  /// `sales.subtotal` di architecture.md §4.
  int get subtotal => items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Total akhir setelah diskon transaksi, tidak pernah negatif / melebihi
  /// [subtotal].
  int get total => (subtotal - transactionDiscount).clamp(0, subtotal).toInt();

  CartState copyWith({List<CartItem>? items, int? transactionDiscount}) {
    return CartState(
      items: items ?? this.items,
      transactionDiscount: transactionDiscount ?? this.transactionDiscount,
    );
  }
}

/// Notifier keranjang kasir (plan.md Milestone 2 poin 1): tambah/kurang
/// qty, hapus item, diskon per item & total, dan dukungan item bebas.
class CartNotifier extends Notifier<CartState> {
  int _freeItemSequence = 0;

  @override
  CartState build() => const CartState();

  /// Menambah produk terdaftar ke keranjang. Jika produk yang sama sudah
  /// ada di keranjang, qty-nya bertambah (bukan bikin baris baru).
  void addProduct(Product product, {double qty = 1}) {
    final key = 'p_${product.id}';
    final existingIndex = state.items.indexWhere((item) => item.key == key);
    if (existingIndex == -1) {
      final newItem = CartItem(
        key: key,
        productId: product.id,
        name: product.name,
        unit: product.unit,
        qty: qty,
        sellPrice: product.sellPrice,
        costPrice: product.costPrice,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    } else {
      _updateItemAt(existingIndex, (item) => item.copyWith(qty: item.qty + qty));
    }
  }

  /// Menambah item bebas (barang tak terdaftar — nama & harga diketik
  /// manual, `productId` null). Selalu jadi baris baru, tidak pernah
  /// digabung dengan baris lain (plan.md Milestone 2 poin 1).
  void addFreeItem({
    required String name,
    required int price,
    double qty = 1,
    String unit = 'pcs',
  }) {
    _freeItemSequence += 1;
    final key = 'f_${DateTime.now().microsecondsSinceEpoch}_$_freeItemSequence';
    final newItem = CartItem(key: key, name: name, unit: unit, qty: qty, sellPrice: price);
    state = state.copyWith(items: [...state.items, newItem]);
  }

  void incrementQty(String key, [double step = 1]) {
    final index = state.items.indexWhere((item) => item.key == key);
    if (index == -1) return;
    _updateItemAt(index, (item) => item.copyWith(qty: item.qty + step));
  }

  /// Mengurangi qty; jika hasilnya <= 0, baris otomatis dihapus.
  void decrementQty(String key, [double step = 1]) {
    final index = state.items.indexWhere((item) => item.key == key);
    if (index == -1) return;
    final newQty = state.items[index].qty - step;
    if (newQty <= 0) {
      removeItem(key);
    } else {
      _updateItemAt(index, (item) => item.copyWith(qty: newQty));
    }
  }

  /// Set qty langsung (mis. dari input manual). qty <= 0 menghapus baris.
  void setQty(String key, double qty) {
    if (qty <= 0) {
      removeItem(key);
      return;
    }
    final index = state.items.indexWhere((item) => item.key == key);
    if (index == -1) return;
    _updateItemAt(index, (item) => item.copyWith(qty: qty));
  }

  void removeItem(String key) {
    state = state.copyWith(items: state.items.where((item) => item.key != key).toList());
  }

  /// Set diskon per item, SELALU nominal (Rp), dibatasi maksimal
  /// `grossTotal` baris tsb. UI yang menyediakan mode persen (lihat
  /// `ItemDiscountDialog`) WAJIB mengonversi ke nominal sebelum memanggil
  /// ini (plan.md Milestone 2 poin 1: "diskon per item (nominal/%→disimpan
  /// nominal)").
  void setItemDiscount(String key, int nominalDiscount) {
    final index = state.items.indexWhere((item) => item.key == key);
    if (index == -1) return;
    final clamped = nominalDiscount.clamp(0, state.items[index].grossTotal).toInt();
    _updateItemAt(index, (item) => item.copyWith(discount: clamped));
  }

  /// Set diskon total transaksi, SELALU nominal (Rp), dibatasi maksimal
  /// [CartState.subtotal].
  void setTransactionDiscount(int nominalDiscount) {
    final clamped = nominalDiscount.clamp(0, state.subtotal).toInt();
    state = state.copyWith(transactionDiscount: clamped);
  }

  void clear() {
    state = const CartState();
  }

  /// Memuat ulang keranjang dari transaksi yang ditahan (hold) — dipakai
  /// saat "lanjutkan" dari daftar `held_carts` (plan.md Milestone 2 poin 8).
  void loadHeldCart(HeldCart heldCart) {
    state = CartState(items: heldCart.items, transactionDiscount: heldCart.transactionDiscount);
  }

  void _updateItemAt(int index, CartItem Function(CartItem) update) {
    final items = [...state.items];
    items[index] = update(items[index]);
    state = state.copyWith(items: items);
  }
}

final NotifierProvider<CartNotifier, CartState> cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
