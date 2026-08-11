/// Item baris dalam keranjang kasir (in-memory) — lihat plan.md Milestone 2
/// poin 1 & architecture.md §5.1.
///
/// Dipakai bersama oleh `CartState`/`cartProvider` (state UI di
/// `features/pos`), usecase [SaveSaleUsecase] (lihat
/// `domain/usecases/save_sale_usecase.dart`), dan serialisasi keranjang
/// yang ditahan (`held_carts.cart_json`, lihat
/// `data/repositories/held_cart_repository_impl.dart`).
class CartItem {
  const CartItem({
    required this.key,
    this.productId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.sellPrice,
    this.costPrice,
    this.discount = 0,
  });

  /// Kunci unik baris di dalam keranjang (BUKAN id database). Untuk item
  /// produk terdaftar: `'p_<productId>'` (supaya tap produk yang sama
  /// menambah qty, bukan bikin baris baru). Untuk item bebas: dibangkitkan
  /// unik tiap kali ditambahkan (lihat `CartNotifier.addFreeItem`).
  final String key;

  /// null = item bebas (barang tak terdaftar, nama & harga diketik manual
  /// — plan.md Milestone 2 poin 1).
  final int? productId;
  final String name;
  final String unit;

  /// Kuantitas (REAL agar dukung satuan desimal seperti kg/liter).
  final double qty;

  /// Harga jual per unit (Rp), snapshot saat ditambahkan ke keranjang.
  final int sellPrice;

  /// Harga modal per unit (Rp), snapshot untuk hitung laba saat transaksi
  /// tersimpan. Null untuk item bebas (tidak ada modal tercatat).
  final int? costPrice;

  /// Diskon baris ini, SELALU disimpan nominal (Rp) — walau UI mengizinkan
  /// input persen, nilainya dikonversi ke nominal sebelum disimpan di sini
  /// (plan.md Milestone 2 poin 1).
  final int discount;

  /// Subtotal baris SEBELUM diskon item (`sellPrice * qty`, dibulatkan ke
  /// rupiah penuh — lihat architecture.md §4: uang integer rupiah).
  int get grossTotal => (sellPrice * qty).round();

  /// Total baris SETELAH diskon item, tidak pernah negatif / melebihi
  /// [grossTotal].
  int get lineTotal => (grossTotal - discount).clamp(0, grossTotal).toInt();

  CartItem copyWith({
    String? key,
    int? productId,
    bool clearProductId = false,
    String? name,
    String? unit,
    double? qty,
    int? sellPrice,
    int? costPrice,
    int? discount,
  }) {
    return CartItem(
      key: key ?? this.key,
      productId: clearProductId ? null : (productId ?? this.productId),
      name: name ?? this.name,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      sellPrice: sellPrice ?? this.sellPrice,
      costPrice: costPrice ?? this.costPrice,
      discount: discount ?? this.discount,
    );
  }

  /// Serialisasi untuk `held_carts.cart_json` (lihat
  /// `HeldCartRepositoryImpl`).
  Map<String, dynamic> toJson() => {
        'key': key,
        'productId': productId,
        'name': name,
        'unit': unit,
        'qty': qty,
        'sellPrice': sellPrice,
        'costPrice': costPrice,
        'discount': discount,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        key: json['key'] as String,
        productId: json['productId'] as int?,
        name: json['name'] as String,
        unit: json['unit'] as String,
        qty: (json['qty'] as num).toDouble(),
        sellPrice: json['sellPrice'] as int,
        costPrice: json['costPrice'] as int?,
        discount: json['discount'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CartItem &&
            other.key == key &&
            other.productId == productId &&
            other.name == name &&
            other.unit == unit &&
            other.qty == qty &&
            other.sellPrice == sellPrice &&
            other.costPrice == costPrice &&
            other.discount == discount);
  }

  @override
  int get hashCode =>
      Object.hash(key, productId, name, unit, qty, sellPrice, costPrice, discount);

  @override
  String toString() =>
      'CartItem(key: $key, name: $name, qty: $qty, sellPrice: $sellPrice, discount: $discount)';
}
