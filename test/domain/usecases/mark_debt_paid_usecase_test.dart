import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/entities/points_settings.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/entities/sale.dart';
import 'package:kasir_warung/domain/entities/sale_result.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/repositories/sale_repository.dart';
import 'package:kasir_warung/domain/usecases/mark_debt_paid_usecase.dart';

/// Fake [SaleRepository] — merekam pemanggilan `markDebtPaid`, TANPA
/// database sungguhan, supaya [MarkDebtPaidUsecase] bisa diuji murni
/// sebagai unit domain (validasi status sebelum menulis).
class _FakeSaleRepository implements SaleRepository {
  _FakeSaleRepository({required this.detailStatus});

  final String detailStatus;
  bool markDebtPaidCalled = false;

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
      paymentMethod: 'debt',
      paidAmount: 0,
      changeAmount: 0,
      customerName: 'Budi',
      createdAt: DateTime(2026, 8, 11),
      items: const [],
      status: detailStatus,
    );
  }

  @override
  Future<void> markDebtPaid(int saleId) async {
    markDebtPaidCalled = true;
  }

  @override
  Future<void> voidSale(int saleId, {int? voidedByUserId}) => throw UnimplementedError();
}

void main() {
  group('MarkDebtPaidUsecase', () {
    test('memanggil repository.markDebtPaid bila status debt_unpaid', () async {
      final repository = _FakeSaleRepository(detailStatus: 'debt_unpaid');
      final usecase = MarkDebtPaidUsecase(repository);

      await usecase(1);

      expect(repository.markDebtPaidCalled, isTrue);
    });

    test('melempar TransaksiBukanHutangException bila status sudah completed', () async {
      final repository = _FakeSaleRepository(detailStatus: 'completed');
      final usecase = MarkDebtPaidUsecase(repository);

      await expectLater(usecase(1), throwsA(isA<TransaksiBukanHutangException>()));
      expect(repository.markDebtPaidCalled, isFalse);
    });

    test('melempar TransaksiBukanHutangException bila status voided', () async {
      final repository = _FakeSaleRepository(detailStatus: 'voided');
      final usecase = MarkDebtPaidUsecase(repository);

      await expectLater(usecase(1), throwsA(isA<TransaksiBukanHutangException>()));
      expect(repository.markDebtPaidCalled, isFalse);
    });
  });
}
