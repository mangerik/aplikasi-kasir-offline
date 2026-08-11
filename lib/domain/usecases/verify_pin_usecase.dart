import '../../core/utils/pin_hasher.dart';
import '../repositories/settings_repository.dart';

/// Usecase verifikasi PIN — dipakai gerbang PIN (`checkPinGate`) DAN alur
/// "ubah/hapus PIN" di Pengaturan (harus tahu PIN lama dulu), plan.md
/// Milestone 5 poin 6.
class VerifyPinUsecase {
  const VerifyPinUsecase(this._repository);

  final SettingsRepository _repository;

  /// `true` bila BELUM ada PIN aktif tersimpan (kondisi "kunci nonaktif" —
  /// dianggap lolos, konsisten dengan hook Milestone 3) ATAU [pin] cocok
  /// dengan hash tersimpan. `false` bila PIN aktif tapi [pin] salah.
  Future<bool> call(String pin) async {
    final storedHash = await _repository.getValue('pin_hash');
    if (storedHash == null || storedHash.isEmpty) return true;
    final salt = await _repository.getValue('pin_salt') ?? '';
    return PinHasher.hash(pin, salt) == storedHash;
  }

  /// `true` bila sudah ada PIN aktif tersimpan.
  Future<bool> isPinActive() async {
    final storedHash = await _repository.getValue('pin_hash');
    return storedHash != null && storedHash.isNotEmpty;
  }
}
