import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/repositories/settings_repository.dart';
import 'package:kasir_warung/domain/usecases/remove_pin_usecase.dart';
import 'package:kasir_warung/domain/usecases/set_pin_usecase.dart';
import 'package:kasir_warung/domain/usecases/verify_pin_usecase.dart';

/// Fake [SettingsRepository] — key-value in-memory sederhana, TANPA
/// database sungguhan, supaya usecase PIN (plan.md Milestone 5 poin 6)
/// bisa diuji murni sebagai unit domain.
class _FakeSettingsRepository implements SettingsRepository {
  final Map<String, String> _store = {};

  @override
  Future<String?> getValue(String key) async => _store[key];

  @override
  Future<void> setValue(String key, String value) async => _store[key] = value;

  @override
  Future<void> deleteValue(String key) async => _store.remove(key);
}

void main() {
  late _FakeSettingsRepository repository;

  setUp(() {
    repository = _FakeSettingsRepository();
  });

  group('SetPinUsecase', () {
    test('menyimpan pin_hash & pin_salt bila PIN 6 digit angka', () async {
      final usecase = SetPinUsecase(repository);
      await usecase('123456');

      expect(await repository.getValue('pin_hash'), isNotNull);
      expect(await repository.getValue('pin_salt'), isNotNull);
    });

    test('dua kali set PIN yang sama menghasilkan salt & hash berbeda (salt acak)', () async {
      final usecase = SetPinUsecase(repository);
      await usecase('123456');
      final firstHash = await repository.getValue('pin_hash');
      final firstSalt = await repository.getValue('pin_salt');

      await usecase('123456');
      final secondHash = await repository.getValue('pin_hash');
      final secondSalt = await repository.getValue('pin_salt');

      expect(secondSalt, isNot(firstSalt));
      expect(secondHash, isNot(firstHash));
    });

    test('melempar PinTidakValidException bila kurang dari 6 digit', () async {
      final usecase = SetPinUsecase(repository);
      await expectLater(usecase('123'), throwsA(isA<PinTidakValidException>()));
    });

    test('melempar PinTidakValidException bila mengandung huruf', () async {
      final usecase = SetPinUsecase(repository);
      await expectLater(usecase('12345a'), throwsA(isA<PinTidakValidException>()));
    });
  });

  group('VerifyPinUsecase', () {
    test('lolos (true) bila belum ada PIN aktif sama sekali', () async {
      final usecase = VerifyPinUsecase(repository);
      expect(await usecase('000000'), isTrue);
    });

    test('true bila PIN yang dimasukkan cocok dengan yang tersimpan', () async {
      await SetPinUsecase(repository)('123456');
      final usecase = VerifyPinUsecase(repository);
      expect(await usecase('123456'), isTrue);
    });

    test('false bila PIN yang dimasukkan salah', () async {
      await SetPinUsecase(repository)('123456');
      final usecase = VerifyPinUsecase(repository);
      expect(await usecase('654321'), isFalse);
    });

    test('isPinActive mengikuti status pin_hash', () async {
      final usecase = VerifyPinUsecase(repository);
      expect(await usecase.isPinActive(), isFalse);

      await SetPinUsecase(repository)('123456');
      expect(await usecase.isPinActive(), isTrue);
    });
  });

  group('RemovePinUsecase', () {
    test('menghapus pin_hash & pin_salt bila PIN lama benar', () async {
      await SetPinUsecase(repository)('123456');
      final usecase = RemovePinUsecase(repository, VerifyPinUsecase(repository));

      await usecase('123456');

      expect(await repository.getValue('pin_hash'), isNull);
      expect(await repository.getValue('pin_salt'), isNull);
    });

    test('melempar PinSalahException bila PIN lama salah (tidak menghapus apa pun)', () async {
      await SetPinUsecase(repository)('123456');
      final usecase = RemovePinUsecase(repository, VerifyPinUsecase(repository));

      await expectLater(usecase('000000'), throwsA(isA<PinSalahException>()));
      expect(await repository.getValue('pin_hash'), isNotNull);
    });

    test('melempar PinBelumDiaturException bila belum ada PIN aktif', () async {
      final usecase = RemovePinUsecase(repository, VerifyPinUsecase(repository));
      await expectLater(usecase('123456'), throwsA(isA<PinBelumDiaturException>()));
    });
  });
}
