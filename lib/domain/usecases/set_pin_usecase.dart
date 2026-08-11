import '../../core/utils/pin_hasher.dart';
import '../repositories/repository_exceptions.dart';
import '../repositories/settings_repository.dart';

/// Usecase "aktifkan/ubah PIN" (plan.md Milestone 5 poin 6, architecture.md
/// §5.4): validasi PIN baru harus 6 digit angka, lalu simpan hash SHA-256 +
/// salt acak ke `settings.pin_hash`/`settings.pin_salt`.
///
/// Verifikasi PIN LAMA (wajib untuk alur "ubah PIN") dilakukan DI LUAR
/// usecase ini (lewat layar keypad + [SettingsRepository.getValue]),
/// sama seperti pola `checkPinGate` — usecase ini murni bertanggung jawab
/// atas penyimpanan PIN BARU yang sudah lolos verifikasi/konfirmasi UI.
class SetPinUsecase {
  const SetPinUsecase(this._repository);

  final SettingsRepository _repository;

  /// Melempar `PinTidakValidException` bila [pin] bukan 6 digit angka.
  Future<void> call(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const PinTidakValidException();
    }
    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(pin, salt);
    await _repository.setValue('pin_salt', salt);
    await _repository.setValue('pin_hash', hash);
  }
}
