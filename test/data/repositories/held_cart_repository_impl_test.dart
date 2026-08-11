import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/held_cart_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';

void main() {
  late AppDatabase db;
  late HeldCartRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HeldCartRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  const items = [
    CartItem(
      key: 'p_1',
      productId: 1,
      name: 'Teh Botol',
      unit: 'pcs',
      qty: 2,
      sellPrice: 5000,
      costPrice: 3000,
      discount: 500,
    ),
    CartItem(key: 'f_1', name: 'Item Bebas', unit: 'kg', qty: 1.5, sellPrice: 12000),
  ];

  group('HeldCartRepositoryImpl — hold & baca kembali', () {
    test('hold menyimpan keranjang, getById mengembalikan data identik', () async {
      final id = await repo.hold(label: 'Budi', items: items, transactionDiscount: 1000);

      final heldCart = await repo.getById(id);
      expect(heldCart, isNotNull);
      expect(heldCart!.label, 'Budi');
      expect(heldCart.transactionDiscount, 1000);
      expect(heldCart.items, hasLength(2));

      final restoredProductItem = heldCart.items.firstWhere((i) => i.productId == 1);
      expect(restoredProductItem.name, 'Teh Botol');
      expect(restoredProductItem.qty, 2);
      expect(restoredProductItem.sellPrice, 5000);
      expect(restoredProductItem.costPrice, 3000);
      expect(restoredProductItem.discount, 500);

      final restoredFreeItem = heldCart.items.firstWhere((i) => i.productId == null);
      expect(restoredFreeItem.name, 'Item Bebas');
      expect(restoredFreeItem.qty, 1.5, reason: 'qty desimal (kg) harus tetap presisi');
      expect(restoredFreeItem.costPrice, isNull);
    });

    test('label kosong/whitespace disimpan sebagai null', () async {
      final id = await repo.hold(label: '   ', items: items, transactionDiscount: 0);
      final heldCart = await repo.getById(id);
      expect(heldCart!.label, isNull);
    });

    test('watchAll bersifat reaktif dan memuat semua hold', () async {
      await repo.hold(items: items, transactionDiscount: 0);
      await repo.hold(items: items, transactionDiscount: 0, label: 'Kedua');

      final all = await repo.watchAll().first;
      expect(all, hasLength(2));
    });

    test('getById mengembalikan null untuk id yang tidak ada', () async {
      final result = await repo.getById(999);
      expect(result, isNull);
    });
  });

  group('HeldCartRepositoryImpl — hapus', () {
    test('delete menghapus hold dari daftar', () async {
      final id = await repo.hold(items: items, transactionDiscount: 0);

      await repo.delete(id);

      final all = await repo.watchAll().first;
      expect(all, isEmpty);
      expect(await repo.getById(id), isNull);
    });
  });
}
