import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/entities/points_settings.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/entities/sale.dart';
import 'package:kasir_warung/domain/entities/sale_result.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/repositories/sale_repository.dart';
import 'package:kasir_warung/domain/usecases/void_sale_usecase.dart';

/// Fake [SaleRepository] — merekam pemanggilan `voidSale`, TANPA database
/// sungguhan, supaya [VoidSaleUsecase] bisa diuji murni sebagai unit
/// domain (validasi status sebelum menulis).
class _FakeSaleRepository implements SaleRepository {
  _FakeSaleRepository({required this.detailStatus, this.detailDebtPaidAt});

  final String detailStatus;
  final DateTime? detailDebtPaidAt;
  bool voidSaleCalled = false;

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
  }) => throw UnimplementedError();

  @override
  Future<List<Sale>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? status,
    int? userId,
    required int limit,
    required int offset,
  }) => throw UnimplementedError();

  @override
  Future<SaleResult> getDetail(int saleId) async {
    return SaleResult(
      saleId: saleId,
      invoiceNumber: '20260811-0001',
      subtotal: 10000,
      discount: 0,
      total: 10000,
      paymentMethod: 'cash',
      paidAmount: 10000,
      changeAmount: 0,
      createdAt: DateTime(2026, 8, 11),
      items: const [],
      status: detailStatus,
      debtPaidAt: detailDebtPaidAt,
    );
  }

  @override
  Future<void> markDebtPaid(int saleId) => throw UnimplementedError();

  @override
  Future<void> voidSale(int saleId, {int? voidedByUserId}) async {
    voidSaleCalled = true;
  }
}

void main() {
  group('VoidSaleUsecase', () {
    test('memanggil repository.voidSale bila status masih completed', () async {
      final repository = _FakeSaleRepository(detailStatus: 'completed');
      final usecase = VoidSaleUsecase(repository);

      await usecase(1);

      expect(repository.voidSaleCalled, isTrue);
    });

    test('memanggil repository.voidSale bila status debt_unpaid', () async {
      final repository = _FakeSaleRepository(detailStatus: 'debt_unpaid');
      final usecase = VoidSaleUsecase(repository);

      await usecase(1);

      expect(repository.voidSaleCalled, isTrue);
    });

    test('melempar TransaksiSudahDibatalkanException bila sudah voided', () async {
      final repository = _FakeSaleRepository(detailStatus: 'voided');
      final usecase = VoidSaleUsecase(repository);

      await expectLater(usecase(1), throwsA(isA<TransaksiSudahDibatalkanException>()));
      expect(repository.voidSaleCalled, isFalse);
    });

    test('melempar HutangSudahLunasException bila hutang sudah dilunasi', () async {
      // Hutang lunas berstatus 'completed' + debt_paid_at terisi — status
      // saja tidak cukup untuk membedakannya dari penjualan tunai biasa.
      final repository = _FakeSaleRepository(
        detailStatus: 'completed',
        detailDebtPaidAt: DateTime(2026, 8, 12),
      );
      final usecase = VoidSaleUsecase(repository);

      await expectLater(usecase(1), throwsA(isA<HutangSudahLunasException>()));
      expect(repository.voidSaleCalled, isFalse);
    });
  });
}
