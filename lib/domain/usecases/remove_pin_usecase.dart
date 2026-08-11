import 'verify_pin_usecase.dart';
import '../repositories/repository_exceptions.dart';
import '../repositories/settings_repository.dart';

/// Usecase "hapus PIN" (plan.md Milestone 5 poin 6): wajib memasukkan PIN
/// lama yang benar dulu sebelum kunci dinonaktifkan.
class RemovePinUsecase {
  const RemovePinUsecase(this._repository, this._verifyPinUsecase);

  final SettingsRepository _repository;
  final VerifyPinUsecase _verifyPinUsecase;

  /// Melempar `PinBelumDiaturException` bila belum ada PIN aktif, atau
  /// `PinSalahException` bila [currentPin] tidak cocok.
  Future<void> call(String currentPin) async {
    final active = await _verifyPinUsecase.isPinActive();
    if (!active) {
      throw const PinBelumDiaturException();
    }
    final correct = await _verifyPinUsecase(currentPin);
    if (!correct) {
      throw const PinSalahException();
    }
    await _repository.deleteValue('pin_hash');
    await _repository.deleteValue('pin_salt');
  }
}
