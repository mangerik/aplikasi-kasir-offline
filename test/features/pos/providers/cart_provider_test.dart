import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/entities/held_cart.dart';
import 'package:kasir_warung/domain/entities/product.dart';
import 'package:kasir_warung/features/pos/providers/cart_provider.dart';

Product _product({
  int id = 1,
  String name = 'Teh Botol',
  int sellPrice = 5000,
  int? costPrice = 3000,
  String unit = 'pcs',
}) {
  final now = DateTime(2026, 8, 11);
  return Product(
    id: id,
    name: name,
    sellPrice: sellPrice,
    costPrice: costPrice,
    stock: 100,
    unit: unit,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  CartNotifier notifier() => container.read(cartProvider.notifier);
  CartState state() => container.read(cartProvider);

  group('CartNotifier — tambah produk', () {
    test('addProduct menambah baris baru untuk produk berbeda', () {
      notifier().addProduct(_product(id: 1, name: 'Teh Botol'));
      notifier().addProduct(_product(id: 2, name: 'Kopi Sachet', sellPrice: 2000));

      expect(state().lineCount, 2);
      expect(state().items[0].qty, 1);
      expect(state().items[1].qty, 1);
    });

    test('addProduct produk yang sama menambah qty, bukan baris baru', () {
      final product = _product(id: 1);
      notifier().addProduct(product);
      notifier().addProduct(product);
      notifier().addProduct(product, qty: 2);

      expect(state().lineCount, 1);
      expect(state().items.single.qty, 4);
    });

    test('addFreeItem selalu jadi baris baru walau nama/harga sama', () {
      notifier().addFreeItem(name: 'Barang X', price: 1000);
      notifier().addFreeItem(name: 'Barang X', price: 1000);

      expect(state().lineCount, 2);
      expect(state().items.every((item) => item.productId == null), isTrue);
    });
  });

  group('CartNotifier — qty', () {
    test('incrementQty & decrementQty mengubah qty baris yang tepat', () {
      notifier().addProduct(_product(id: 1));
      final key = state().items.single.key;

      notifier().incrementQty(key);
      expect(state().items.single.qty, 2);

      notifier().decrementQty(key);
      expect(state().items.single.qty, 1);
    });

    test('decrementQty sampai <= 0 menghapus baris otomatis', () {
      notifier().addProduct(_product(id: 1));
      final key = state().items.single.key;

      notifier().decrementQty(key);
      expect(state().isEmpty, isTrue);
    });

    test('setQty <= 0 menghapus baris', () {
      notifier().addProduct(_product(id: 1));
      final key = state().items.single.key;

      notifier().setQty(key, 0);
      expect(state().isEmpty, isTrue);
    });

    test('setQty > 0 mengubah qty langsung (dukung desimal, mis. kg)', () {
      notifier().addProduct(_product(id: 1, unit: 'kg'));
      final key = state().items.single.key;

      notifier().setQty(key, 2.5);
      expect(state().items.single.qty, 2.5);
    });

    test('removeItem menghapus baris tertentu', () {
      notifier().addProduct(_product(id: 1, name: 'A'));
      notifier().addProduct(_product(id: 2, name: 'B'));
      final keyA = state().items.first.key;

      notifier().removeItem(keyA);

      expect(state().lineCount, 1);
      expect(state().items.single.name, 'B');
    });
  });

  group('CartNotifier — diskon & total', () {
    test('subtotal = jumlah lineTotal semua baris', () {
      notifier().addProduct(_product(id: 1, sellPrice: 5000)); // qty 1 -> 5000
      notifier().addProduct(_product(id: 2, sellPrice: 2000), qty: 3); // 6000

      expect(state().subtotal, 11000);
    });

    test('setItemDiscount nominal mengurangi lineTotal baris tsb', () {
      notifier().addProduct(_product(id: 1, sellPrice: 5000));
      final key = state().items.single.key;

      notifier().setItemDiscount(key, 1000);

      expect(state().items.single.discount, 1000);
      expect(state().items.single.lineTotal, 4000);
      expect(state().subtotal, 4000);
    });

    test('setItemDiscount dibatasi maksimal grossTotal baris (tidak boleh negatif)', () {
      notifier().addProduct(_product(id: 1, sellPrice: 5000));
      final key = state().items.single.key;

      notifier().setItemDiscount(key, 999999);

      expect(state().items.single.discount, 5000);
      expect(state().items.single.lineTotal, 0);
    });

    test('setTransactionDiscount mengurangi total, subtotal tetap utuh', () {
      notifier().addProduct(_product(id: 1, sellPrice: 10000));
      notifier().setTransactionDiscount(3000);

      expect(state().subtotal, 10000);
      expect(state().transactionDiscount, 3000);
      expect(state().total, 7000);
    });

    test('setTransactionDiscount dibatasi maksimal subtotal', () {
      notifier().addProduct(_product(id: 1, sellPrice: 10000));
      notifier().setTransactionDiscount(999999);

      expect(state().transactionDiscount, 10000);
      expect(state().total, 0);
    });

    test('total = subtotal - diskon transaksi, memperhitungkan diskon item juga', () {
      notifier().addProduct(_product(id: 1, sellPrice: 10000));
      final key = state().items.single.key;
      notifier().setItemDiscount(key, 2000); // lineTotal 8000
      notifier().setTransactionDiscount(1000);

      expect(state().subtotal, 8000);
      expect(state().total, 7000);
    });
  });

  group('CartNotifier — clear & hold', () {
    test('clear mengosongkan keranjang & reset diskon transaksi', () {
      notifier().addProduct(_product(id: 1, sellPrice: 5000));
      notifier().setTransactionDiscount(1000);

      notifier().clear();

      expect(state().isEmpty, isTrue);
      expect(state().transactionDiscount, 0);
    });

    test('loadHeldCart mengganti seluruh isi keranjang aktif', () {
      notifier().addProduct(_product(id: 1, sellPrice: 5000));

      final held = HeldCart(
        id: 1,
        label: 'Budi',
        items: [
          const CartItem(key: 'p_9', productId: 9, name: 'Gula', unit: 'kg', qty: 2, sellPrice: 15000),
        ],
        transactionDiscount: 500,
        createdAt: DateTime(2026, 8, 11),
      );

      notifier().loadHeldCart(held);

      expect(state().lineCount, 1);
      expect(state().items.single.name, 'Gula');
      expect(state().transactionDiscount, 500);
    });
  });
}
