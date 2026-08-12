import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/entities/points_settings.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/entities/sale.dart';
import 'package:kasir_warung/domain/entities/sale_result.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/repositories/sale_repository.dart';
import 'package:kasir_warung/domain/usecases/save_sale_usecase.dart';

/// Fake [SaleRepository] — merekam argumen terakhir yang diterima, TANPA
/// database sungguhan, supaya [SaveSaleUsecase] bisa diuji murni sebagai
/// unit domain (validasi & orkestrasi).
class _FakeSaleRepository implements SaleRepository {
  List<CartItem>? lastItems;
  int? lastTransactionDiscount;
  String? lastPaymentMethod;
  int? lastPaidAmount;
  String? lastCustomerName;
  String? lastNote;

  @override
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
  }) async {
    lastItems = items;
    lastTransactionDiscount = transactionDiscount;
    lastPaymentMethod = paymentMethod;
    lastPaidAmount = paidAmount;
    lastCustomerName = customerName;
    lastNote = note;

    final subtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotal);
    final total = subtotal - transactionDiscount;
    return SaleResult(
      saleId: 1,
      invoiceNumber: '20260811-0001',
      subtotal: subtotal,
      discount: transactionDiscount,
      total: total,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      changeAmount: paymentMethod == 'cash' ? paidAmount - total : 0,
      customerName: customerName,
      note: note,
      createdAt: DateTime(2026, 8, 11),
      items: const [],
      status: paymentMethod == 'debt' ? 'debt_unpaid' : 'completed',
    );
  }

  @override
  Future<List<Sale>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? status,
    int? userId,
    required int limit,
    required int offset,
  }) async => const [];

  @override
  Future<SaleResult> getDetail(int saleId) => throw UnimplementedError();

  @override
  Future<void> markDebtPaid(int saleId) => throw UnimplementedError();

  @override
  Future<void> voidSale(int saleId, {int? voidedByUserId}) => throw UnimplementedError();
}

CartItem _item({int sellPrice = 5000, double qty = 1, int discount = 0}) {
  return CartItem(
    key: 'p_1',
    productId: 1,
    name: 'Teh Botol',
    unit: 'pcs',
    qty: qty,
    sellPrice: sellPrice,
    discount: discount,
  );
}

void main() {
  late _FakeSaleRepository repository;
  late SaveSaleUsecase usecase;

  setUp(() {
    repository = _FakeSaleRepository();
    usecase = SaveSaleUsecase(repository);
  });

  group('SaveSaleUsecase — validasi', () {
    test('melempar KeranjangKosongException bila items kosong', () {
      expect(
        () => usecase(
          items: const [],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 0,
        ),
        throwsA(isA<KeranjangKosongException>()),
      );
    });

    test('melempar UangTidakCukupException bila bayar tunai kurang dari total', () {
      expect(
        () => usecase(
          items: [_item(sellPrice: 10000)],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 5000,
        ),
        throwsA(
          isA<UangTidakCukupException>().having(
            (e) => e.toString(),
            'pesan',
            contains('kurang'),
          ),
        ),
      );
    });

    test('tidak melempar error bila bayar tunai tepat sama dengan total (uang pas)', () async {
      final result = await usecase(
        items: [_item(sellPrice: 10000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 10000,
      );
      expect(result.changeAmount, 0);
    });

    test('melempar NamaPelangganWajibException untuk hutang tanpa nama pelanggan', () {
      expect(
        () => usecase(
          items: [_item(sellPrice: 10000)],
          transactionDiscount: 0,
          paymentMethod: 'debt',
          paidAmount: 0,
        ),
        throwsA(isA<NamaPelangganWajibException>()),
      );
    });

    test('hutang dengan nama pelanggan (whitespace) tetap ditolak', () {
      expect(
        () => usecase(
          items: [_item(sellPrice: 10000)],
          transactionDiscount: 0,
          paymentMethod: 'debt',
          paidAmount: 0,
          customerName: '   ',
        ),
        throwsA(isA<NamaPelangganWajibException>()),
      );
    });

    test('validasi gagal TIDAK memanggil repository sama sekali', () async {
      try {
        await usecase(
          items: const [],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 0,
        );
      } catch (_) {
        // diabaikan, fokus mengecek repo tidak dipanggil
      }
      expect(repository.lastItems, isNull);
    });
  });

  group('SaveSaleUsecase — kembalian & orkestrasi', () {
    test('menghitung kembalian tunai dengan benar', () async {
      final result = await usecase(
        items: [_item(sellPrice: 12000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 20000,
      );
      expect(result.total, 12000);
      expect(result.changeAmount, 8000);
    });

    test('diskon transaksi dibatasi maksimal subtotal sebelum diteruskan ke repo', () async {
      await usecase(
        items: [_item(sellPrice: 5000)],
        transactionDiscount: 999999,
        paymentMethod: 'cash',
        paidAmount: 999999,
      );
      expect(repository.lastTransactionDiscount, 5000);
    });

    test('nama pelanggan & catatan kosong/whitespace dikirim sebagai null ke repo', () async {
      await usecase(
        items: [_item(sellPrice: 5000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 5000,
        customerName: '   ',
        note: '',
      );
      expect(repository.lastCustomerName, isNull);
      expect(repository.lastNote, isNull);
    });

    test('meneruskan items & paymentMethod apa adanya ke repository', () async {
      final items = [_item(sellPrice: 5000, qty: 2)];
      await usecase(
        items: items,
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 10000,
      );
      expect(repository.lastItems, items);
      expect(repository.lastPaymentMethod, 'cash');
      expect(repository.lastPaidAmount, 10000);
    });
  });
}
