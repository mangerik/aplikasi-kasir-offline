/// Setelan multi-user (PRD v1.1 §8.5) — empat key baru di tabel
/// `settings`, plus dua key LAMA (`pin_hash`/`pin_salt`) yang sengaja
/// dipertahankan untuk mode single-user.
class MultiUserSettings {
  const MultiUserSettings({
    this.enabled = false,
    this.autoLockMinutes = 0,
    this.hasRecoveryCode = false,
  });

  /// `settings.multi_user_enabled` — `'0'`/`'1'`, **default `'0'`**
  /// (K-8.5, AC-8.1).
  static const String keyEnabled = 'multi_user_enabled';

  /// `settings.auto_lock_minutes` — `0` berarti kunci otomatis MATI.
  static const String keyAutoLockMinutes = 'auto_lock_minutes';

  /// Hash & salt kode pemulihan (K-8.4) — kodenya sendiri hanya pernah
  /// ada di layar, sekali (AC-8.3).
  static const String keyRecoveryHash = 'recovery_code_hash';
  static const String keyRecoverySalt = 'recovery_code_salt';

  /// Key PIN global v1.0 — TETAP dipakai saat multi-user mati (§8.5).
  static const String keyLegacyPinHash = 'pin_hash';
  static const String keyLegacyPinSalt = 'pin_salt';

  /// Pilihan kunci otomatis yang ditawarkan UI (PRD §8.3.B): mati
  /// (default), 1, 5, atau 15 menit.
  static const List<int> autoLockChoices = [0, 1, 5, 15];

  final bool enabled;

  /// `0` = mati.
  final int autoLockMinutes;

  final bool hasRecoveryCode;

  Duration? get autoLockDuration =>
      autoLockMinutes <= 0 ? null : Duration(minutes: autoLockMinutes);

  static String autoLockLabel(int minutes) =>
      minutes <= 0 ? 'Mati' : '$minutes menit';

  MultiUserSettings copyWith({
    bool? enabled,
    int? autoLockMinutes,
    bool? hasRecoveryCode,
  }) =>
      MultiUserSettings(
        enabled: enabled ?? this.enabled,
        autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
        hasRecoveryCode: hasRecoveryCode ?? this.hasRecoveryCode,
      );
}
