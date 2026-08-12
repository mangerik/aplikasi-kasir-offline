import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/pin_throttle.dart';

/// Kunci sesi di `shared_preferences`.
///
/// **Sengaja BUKAN di tabel `settings`** (§8.5, alasan yang sama dengan
/// K-5.2): siapa yang sedang bertugas adalah keadaan PERANGKAT, bukan data
/// toko. Kalau ikut masuk database, backup dari HP kasir akan "membawa
/// masuk" sesi orang lain saat direstore di HP pemilik.
const String kActiveUserIdPrefKey = 'active_user_id';
const String kPinFailedAttemptsPrefKey = 'pin_failed_attempts';
const String kPinLockedUntilPrefKey = 'pin_locked_until';

/// Cermin `settings.multi_user_enabled` supaya bisa dibaca **sinkron**
/// sebelum database terbuka — dengan begitu frame pertama sudah menampilkan
/// layar yang benar (layar Masuk vs layar Kasir), tanpa kedipan. Sumber
/// kebenarannya tetap tabel `settings`; nilai ini diselaraskan setiap kali
/// setelan dibaca atau diubah.
const String kMultiUserMirrorPrefKey = 'multi_user_enabled_mirror';

/// Tempat sesi & hitungan percobaan PIN disimpan.
///
/// Dibuat sebagai abstraksi (bukan `SharedPreferences` langsung) karena
/// pembacaannya harus sinkron di jalur frame pertama — pola yang sama
/// dengan `ThemeModeStore` (§5.3).
abstract interface class SessionStore {
  int? readActiveUserId();
  Future<void> writeActiveUserId(int? userId);

  bool readMultiUserEnabled();
  Future<void> writeMultiUserEnabled(bool enabled);

  PinThrottleState readThrottle();
  Future<void> writeThrottle(PinThrottleState state);
}

class SharedPrefsSessionStore implements SessionStore {
  const SharedPrefsSessionStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  int? readActiveUserId() => _prefs.getInt(kActiveUserIdPrefKey);

  @override
  Future<void> writeActiveUserId(int? userId) async {
    if (userId == null) {
      await _prefs.remove(kActiveUserIdPrefKey);
    } else {
      await _prefs.setInt(kActiveUserIdPrefKey, userId);
    }
  }

  @override
  bool readMultiUserEnabled() =>
      _prefs.getBool(kMultiUserMirrorPrefKey) ?? false;

  @override
  Future<void> writeMultiUserEnabled(bool enabled) =>
      _prefs.setBool(kMultiUserMirrorPrefKey, enabled);

  @override
  PinThrottleState readThrottle() {
    final millis = _prefs.getInt(kPinLockedUntilPrefKey);
    return PinThrottleState(
      failedAttempts: _prefs.getInt(kPinFailedAttemptsPrefKey) ?? 0,
      lockedUntil:
          millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  @override
  Future<void> writeThrottle(PinThrottleState state) async {
    await _prefs.setInt(kPinFailedAttemptsPrefKey, state.failedAttempts);
    final until = state.lockedUntil;
    if (until == null) {
      await _prefs.remove(kPinLockedUntilPrefKey);
    } else {
      await _prefs.setInt(kPinLockedUntilPrefKey, until.millisecondsSinceEpoch);
    }
  }
}

/// Implementasi tanpa penyimpanan — default provider & dipakai widget test.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore({this.activeUserId, this.multiUserEnabled = false});

  int? activeUserId;
  bool multiUserEnabled;
  PinThrottleState throttle = const PinThrottleState();

  @override
  int? readActiveUserId() => activeUserId;

  @override
  Future<void> writeActiveUserId(int? userId) async => activeUserId = userId;

  @override
  bool readMultiUserEnabled() => multiUserEnabled;

  @override
  Future<void> writeMultiUserEnabled(bool enabled) async =>
      multiUserEnabled = enabled;

  @override
  PinThrottleState readThrottle() => throttle;

  @override
  Future<void> writeThrottle(PinThrottleState state) async => throttle = state;
}

/// Sumber sesi. Di-override di `main()` dengan [SharedPrefsSessionStore]
/// yang `SharedPreferences`-nya sudah dimuat sebelum `runApp()`.
final Provider<SessionStore> sessionStoreProvider = Provider<SessionStore>(
  (ref) => InMemorySessionStore(),
);
