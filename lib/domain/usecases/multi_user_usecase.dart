import '../../core/utils/pin_hasher.dart';
import '../../core/utils/recovery_code.dart';
import '../entities/app_user.dart';
import '../entities/multi_user_settings.dart';
import '../repositories/repository_exceptions.dart';
import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';

/// Orkestrasi menyalakan/mematikan multi-user & kode pemulihan
/// (PRD v1.1 §8.3.A & §8.3.E).
///
/// Ditaruh di layer domain karena aturannya lintas dua repository
/// (`users` + `settings`) dan sarat konsekuensi: satu langkah yang
/// terlewat di sini berarti pemilik warung terkunci dari datanya sendiri.
class MultiUserUsecase {
  const MultiUserUsecase(this._settings, this._users);

  final SettingsRepository _settings;
  final UserRepository _users;

  /// Baca setelan multi-user apa adanya (default: mati — K-8.5, AC-8.1).
  Future<MultiUserSettings> readSettings() async {
    final results = await Future.wait([
      _settings.getValue(MultiUserSettings.keyEnabled),
      _settings.getValue(MultiUserSettings.keyAutoLockMinutes),
      _settings.getValue(MultiUserSettings.keyRecoveryHash),
    ]);
    final minutes = int.tryParse(results[1] ?? '') ?? 0;
    return MultiUserSettings(
      enabled: results[0] == '1',
      autoLockMinutes:
          MultiUserSettings.autoLockChoices.contains(minutes) ? minutes : 0,
      hasRecoveryCode: (results[2] ?? '').isNotEmpty,
    );
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    await _settings.setValue(
      MultiUserSettings.keyAutoLockMinutes,
      minutes.toString(),
    );
  }

  /// Apakah masih ada PIN global v1.0 yang bisa dipakai ulang sebagai PIN
  /// Pemilik (AC-8.2)? Menentukan apakah alur aktivasi perlu meminta PIN
  /// baru atau tidak.
  Future<bool> hasReusableGlobalPin() async {
    if (await _users.firstOwner() != null) return true;
    final hash = await _settings.getValue(MultiUserSettings.keyLegacyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Menyalakan multi-user (§8.3.A).
  ///
  /// - Sudah ada akun Pemilik (mis. hasil migrasi 2 → 3) → dipakai apa
  ///   adanya, hanya namanya yang disesuaikan bila diisi.
  /// - Belum ada akun tapi masih ada PIN global v1.0 → PIN itu **otomatis**
  ///   menjadi PIN akun Pemilik (AC-8.2); [newPin] tidak diperlukan.
  /// - Belum ada keduanya → [newPin] WAJIB (6 digit).
  ///
  /// Mengembalikan **kode pemulihan teks polos** — satu-satunya saat kode
  /// itu ada di memori. Pemanggil WAJIB menampilkannya sekali lalu
  /// melupakannya (AC-8.3).
  Future<MultiUserActivation> enable({
    required String ownerName,
    String? newPin,
  }) async {
    var owner = await _users.firstOwner();

    if (owner == null) {
      final legacyHash =
          await _settings.getValue(MultiUserSettings.keyLegacyPinHash);
      if (legacyHash != null && legacyHash.isNotEmpty) {
        owner = await _users.createOwnerFromExistingHash(
          name: ownerName,
          pinHash: legacyHash,
          pinSalt:
              await _settings.getValue(MultiUserSettings.keyLegacyPinSalt) ?? '',
        );
      } else {
        if (newPin == null) throw const PinBelumDiaturException();
        owner = await _users.createUser(
          name: ownerName,
          role: UserRole.owner,
          pin: newPin,
        );
      }
    } else if (ownerName.trim().isNotEmpty && ownerName.trim() != owner.name) {
      await _users.rename(userId: owner.id, name: ownerName);
      owner = (await _users.findById(owner.id))!;
    }

    final code = await _issueRecoveryCode();
    await _settings.setValue(MultiUserSettings.keyEnabled, '1');
    return MultiUserActivation(owner: owner, recoveryCode: code);
  }

  /// Mematikan multi-user (§8.3.A).
  ///
  /// Akun kasir dinonaktifkan, PIN akun Pemilik dikembalikan menjadi PIN
  /// global v1.0, dan `sales.user_id` historis **tidak disentuh sama
  /// sekali** (AC-8.13) — riwayat siapa melayani apa tidak boleh hilang
  /// hanya karena fiturnya dimatikan.
  Future<void> disable() async {
    final owner = await _users.firstOwner();
    if (owner != null) {
      final pin = await _users.storedPin(owner.id);
      if (pin != null) {
        await _settings.setValue(MultiUserSettings.keyLegacyPinHash, pin.hash);
        await _settings.setValue(MultiUserSettings.keyLegacyPinSalt, pin.salt);
      }
    }
    await _users.deactivateAllCashiers();
    await _settings.setValue(MultiUserSettings.keyEnabled, '0');
  }

  /// Menerbitkan kode pemulihan BARU (kode lama otomatis hangus karena
  /// hash-nya ditimpa) — dipakai saat aktivasi dan setiap kali pemulihan
  /// PIN Pemilik berhasil (§8.3.E).
  Future<String> _issueRecoveryCode() async {
    final code = RecoveryCode.generate();
    final salt = PinHasher.generateSalt();
    await _settings.setValue(MultiUserSettings.keyRecoverySalt, salt);
    await _settings.setValue(
      MultiUserSettings.keyRecoveryHash,
      PinHasher.hash(RecoveryCode.normalize(code), salt),
    );
    return code;
  }

  /// Menerbitkan ulang kode pemulihan atas permintaan pemilik (mis. kertas
  /// catatannya hilang). Kode lama langsung tidak berlaku.
  Future<String> regenerateRecoveryCode() => _issueRecoveryCode();

  /// `true` bila [input] cocok dengan kode pemulihan tersimpan.
  Future<bool> verifyRecoveryCode(String input) async {
    final hash = await _settings.getValue(MultiUserSettings.keyRecoveryHash);
    if (hash == null || hash.isEmpty) return false;
    final salt =
        await _settings.getValue(MultiUserSettings.keyRecoverySalt) ?? '';
    return PinHasher.hash(RecoveryCode.normalize(input), salt) == hash;
  }

  /// Pemulihan PIN Pemilik lewat kode pemulihan (§8.3.E).
  ///
  /// Melempar [KodePemulihanSalahException] bila kodenya tidak cocok —
  /// PIN tidak berubah sedikit pun dalam kasus itu. Berhasil → PIN Pemilik
  /// diganti, kode lama hangus, dan **kode baru** dikembalikan untuk
  /// ditampilkan sekali lagi.
  Future<String> resetOwnerPinWithRecoveryCode({
    required String code,
    required String newPin,
    int? ownerId,
  }) async {
    if (!await verifyRecoveryCode(code)) {
      throw const KodePemulihanSalahException();
    }
    final owner = ownerId == null
        ? await _users.firstOwner()
        : await _users.findById(ownerId);
    if (owner == null || !owner.isOwner) {
      throw const PenggunaTidakDitemukanException();
    }
    await _users.setPin(userId: owner.id, pin: newPin);
    return _issueRecoveryCode();
  }
}

/// Hasil menyalakan multi-user: akun Pemilik yang berlaku + kode pemulihan
/// yang WAJIB ditampilkan sekali.
class MultiUserActivation {
  const MultiUserActivation({required this.owner, required this.recoveryCode});

  final AppUser owner;
  final String recoveryCode;
}
