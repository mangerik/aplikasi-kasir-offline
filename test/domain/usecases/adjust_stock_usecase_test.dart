import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/entities/stock_movement.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/repositories/stock_repository.dart';
import 'package:kasir_warung/domain/usecases/adjust_stock_usecase.dart';

/// Fake [StockRepository] — merekam pemanggilan `adjustStock`, TANPA
/// database sungguhan, supaya [AdjustStockUsecase] bisa diuji murni sebagai
/// unit domain (validasi jumlah & alasan sebelum menulis).
class _FakeStockRepository implements StockRepository {
  bool adjustStockCalled = false;
  String? lastType;
  double? lastAmount;
  String? lastNote;

  @override
  Future<void> adjustStock({
    required int productId,
    required String type,
    required double amount,
    String? note,
    int? userId,
  }) async {
    adjustStockCalled = true;
    lastType = type;
    lastAmount = amount;
    lastNote = note;
  }

  @override
  Future<List<StockMovement>> getMovements({
    required int productId,
    required int limit,
    required int offset,
  }) => throw UnimplementedError();
}

void main() {
  late _FakeStockRepository repository;
  late AdjustStockUsecase usecase;

  setUp(() {
    repository = _FakeStockRepository();
    usecase = AdjustStockUsecase(repository);
  });

  group('AdjustStockUsecase — stok masuk/keluar', () {
    test('memanggil repository dengan amount > 0 & note ter-trim', () async {
      await usecase(productId: 1, type: 'adjust_in', amount: 5, note: '  Belanja baru  ');

      expect(repository.adjustStockCalled, isTrue);
      expect(repository.lastType, 'adjust_in');
      expect(repository.lastAmount, 5);
      expect(repository.lastNote, 'Belanja baru');
    });

    test('menolak amount <= 0 untuk adjust_in TANPA memanggil repository', () async {
      await expectLater(
        usecase(productId: 1, type: 'adjust_in', amount: 0, note: 'x'),
        throwsA(isA<JumlahPenyesuaianTidakValidException>()),
      );
      expect(repository.adjustStockCalled, isFalse);
    });

    test('menolak amount negatif untuk adjust_out', () async {
      await expectLater(
        usecase(productId: 1, type: 'adjust_out', amount: -1, note: 'x'),
        throwsA(isA<JumlahPenyesuaianTidakValidException>()),
      );
      expect(repository.adjustStockCalled, isFalse);
    });
  });

  group('AdjustStockUsecase — opname', () {
    test('menerima amount = 0 (stok akhir absolut boleh nol)', () async {
      await usecase(productId: 1, type: 'opname', amount: 0, note: 'Kosong semua');
      expect(repository.adjustStockCalled, isTrue);
    });

    test('menolak amount negatif', () async {
      await expectLater(
        usecase(productId: 1, type: 'opname', amount: -1, note: 'x'),
        throwsA(isA<JumlahPenyesuaianTidakValidException>()),
      );
      expect(repository.adjustStockCalled, isFalse);
    });
  });

  group('AdjustStockUsecase — alasan wajib', () {
    test('menolak note null', () async {
      await expectLater(
        usecase(productId: 1, type: 'adjust_in', amount: 1, note: null),
        throwsA(isA<AlasanPenyesuaianWajibException>()),
      );
      expect(repository.adjustStockCalled, isFalse);
    });

    test('menolak note kosong/hanya spasi', () async {
      await expectLater(
        usecase(productId: 1, type: 'adjust_in', amount: 1, note: '   '),
        throwsA(isA<AlasanPenyesuaianWajibException>()),
      );
      expect(repository.adjustStockCalled, isFalse);
    });
  });

  test('melempar ArgumentError untuk jenis penyesuaian tidak dikenal', () async {
    await expectLater(
      usecase(productId: 1, type: 'invalid_type', amount: 1, note: 'x'),
      throwsA(isA<ArgumentError>()),
    );
    expect(repository.adjustStockCalled, isFalse);
  });
}
