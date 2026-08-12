import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/data/repositories/stock_repository_impl.dart';
import 'package:kasir_warung/data/repositories/user_repository_impl.dart';
import 'package:kasir_warung/data/services/receipt_service.dart';
import 'package:kasir_warung/domain/entities/app_user.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/usecases/adjust_stock_usecase.dart';
import 'package:kasir_warung/domain/usecases/save_sale_usecase.dart';
import 'package:kasir_warung/domain/usecases/void_sale_usecase.dart';
import 'package:drift/drift.dart' show Value;

/// Jejak pengguna pada transaksi & stok (PRD v1.1 §8.3.D — AC-8.6, AC-8.7,
/// AC-8.8, AC-8.9).
///
/// Inti milestone ini bagi pemilik warung: kalau kas kurang, dia harus bisa
/// menunjuk baris transaksi dan tahu siapa yang melayani.
void main() {
  late AppDatabase db;
  late SaleRepositoryImpl sales;
  late StockRepositoryImpl stock;
  late UserRepositoryImpl users;
  late int productId;

  setUpAll(() async {
    await DateFormatter.init();
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sales = SaleRepositoryImpl(db);
    stock = StockRepositoryImpl(db);
    users = UserRepositoryImpl(db);
    productId = await db.into(db.products).insert(
          ProductsCompanion.insert(
            name: 'Gula 1kg',
            sellPrice: 15000,
            costPrice: const Value(12000),
            stock: const Value(20),
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  });

  tearDown(() => db.close());

  CartItem item() => CartItem(
        key: 'p$productId',
        productId: productId,
        name: 'Gula 1kg',
        unit: 'pcs',
        qty: 2,
        sellPrice: 15000,
        costPrice: 12000,
      );

  Future<AppUser> cashier() =>
      users.createUser(name: 'Ani', role: UserRole.cashier, pin: '111111');

  Future<AppUser> owner() =>
      users.createUser(name: 'Pemilik', role: UserRole.owner, pin: '222222');

  test('AC-8.7: penjualan menyimpan user_id & user_name yang benar', () async {
    final ani = await cashier();
    final result = await SaveSaleUsecase(sales, actor: ani)(
      items: [item()],
      transactionDiscount: 0,
      paymentMethod: 'cash',
      paidAmount: 30000,
    );

    final row = await (db.select(db.sales)
          ..where((s) => s.id.equals(result.saleId)))
        .getSingle();
    expect(row.userId, ani.id);
    expect(row.userName, 'Ani');
    expect(result.userName, 'Ani');
  });

  test(
    'AC-8.7: mengganti nama pengguna tidak mengubah nama pada transaksi lama',
    () async {
      final ani = await cashier();
      final result = await SaveSaleUsecase(sales, actor: ani)(
        items: [item()],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 30000,
      );

      await users.rename(userId: ani.id, name: 'Ani Suryani');

      final detail = await sales.getDetail(result.saleId);
      expect(detail.userName, 'Ani');
    },
  );

  test('multi-user mati (tanpa actor) → user_id tetap NULL (AC-8.1)', () async {
    final result = await SaveSaleUsecase(sales)(
      items: [item()],
      transactionDiscount: 0,
      paymentMethod: 'cash',
      paidAmount: 30000,
    );
    final row = await (db.select(db.sales)
          ..where((s) => s.id.equals(result.saleId)))
        .getSingle();
    expect(row.userId, isNull);
    expect(row.userName, isNull);
  });

  test('AC-8.8: penyesuaian stok oleh kasir tercatat atas namanya', () async {
    final ani = await cashier();
    await AdjustStockUsecase(stock, actor: ani)(
      productId: productId,
      type: 'adjust_in',
      amount: 5,
      note: 'Kiriman pagi',
    );

    final movement = await (db.select(db.stockMovements)
          ..where((m) => m.type.equals('adjust_in')))
        .getSingle();
    expect(movement.userId, ani.id);
  });

  test('AC-8.6: Kasir ditolak saat void, transaksi TIDAK berubah', () async {
    final ani = await cashier();
    final result = await SaveSaleUsecase(sales, actor: ani)(
      items: [item()],
      transactionDiscount: 0,
      paymentMethod: 'cash',
      paidAmount: 30000,
    );

    await expectLater(
      VoidSaleUsecase(sales, actor: ani)(result.saleId),
      throwsA(isA<AksesDitolakException>()),
    );

    final row = await (db.select(db.sales)
          ..where((s) => s.id.equals(result.saleId)))
        .getSingle();
    expect(row.status, 'completed');
    expect(row.voidedAt, isNull);
    // Stok pun tidak dikembalikan diam-diam.
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingle();
    expect(product.stock, 18);
  });

  test('void oleh Pemilik tercatat di voided_by_user_id', () async {
    final ani = await cashier();
    final budi = await owner();
    final result = await SaveSaleUsecase(sales, actor: ani)(
      items: [item()],
      transactionDiscount: 0,
      paymentMethod: 'cash',
      paidAmount: 30000,
    );

    await VoidSaleUsecase(sales, actor: budi)(result.saleId);

    final row = await (db.select(db.sales)
          ..where((s) => s.id.equals(result.saleId)))
        .getSingle();
    expect(row.status, 'voided');
    expect(row.voidedByUserId, budi.id);
    // Jejak kasir yang melayani TETAP, bukan tertimpa oleh yang membatalkan.
    expect(row.userId, ani.id);
  });

  test('AC-8.9: riwayat bisa difilter per kasir & angkanya cocok', () async {
    final ani = await cashier();
    final budi = await owner();

    Future<void> sale(AppUser actor) => SaveSaleUsecase(sales, actor: actor)(
          items: [item()],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 30000,
        );

    await sale(ani);
    await sale(ani);
    await sale(budi);

    final aniRows = await sales.getHistory(userId: ani.id, limit: 50, offset: 0);
    final budiRows =
        await sales.getHistory(userId: budi.id, limit: 50, offset: 0);
    final all = await sales.getHistory(limit: 50, offset: 0);

    expect(aniRows, hasLength(2));
    expect(budiRows, hasLength(1));
    expect(all, hasLength(3));
    expect(
      aniRows.fold<int>(0, (sum, s) => sum + s.total) +
          budiRows.fold<int>(0, (sum, s) => sum + s.total),
      all.fold<int>(0, (sum, s) => sum + s.total),
    );
    expect(aniRows.every((s) => s.userName == 'Ani'), isTrue);
  });

  group('struk (§8.3.D)', () {
    test('baris "Kasir" dicetak saat transaksi punya nama kasir', () async {
      final ani = await cashier();
      final result = await SaveSaleUsecase(sales, actor: ani)(
        items: [item()],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 30000,
      );

      expect(ReceiptService.formatReceiptText(result), contains('Kasir: Ani'));
    });

    test('AC-8.1: tanpa multi-user, struk TIDAK punya baris "Kasir"',
        () async {
      final result = await SaveSaleUsecase(sales)(
        items: [item()],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 30000,
      );

      expect(
        ReceiptService.formatReceiptText(result),
        isNot(contains('Kasir:')),
      );
    });
  });
}
