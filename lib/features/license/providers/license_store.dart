import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Kunci penyimpanan lisensi di `shared_preferences` (PRD v1.1 §6.5).
///
/// **Sengaja BUKAN di tabel `settings`/database (K-6.1).** Alasan pertama
/// yang menentukan: tabel `settings` ikut terbawa `backup → restore`, jadi
/// satu file backup yang beredar di grup WhatsApp akan membawa serta
/// lisensi berbayarnya. Token memang terikat perangkat sehingga tidak akan
/// lolos di HP lain — tapi merancang gerbang penjualan yang keselamatannya
/// bergantung pada satu lapisan saja adalah kecerobohan yang tidak perlu.
///
/// Alasan berikutnya: konsisten dengan preferensi tema (K-5.2), dan harus
/// bisa dibaca **sebelum** database dibuka (gerbang berjalan sebelum
/// `runApp()`).
const String kLicenseTokenPrefKey = 'license_token';
const String kLicenseActivatedAtPrefKey = 'license_activated_at';
const String kLicenseLastSeenAtPrefKey = 'license_last_seen_at';
const String kLicenseDeviceIdFallbackPrefKey = 'license_device_id_fallback';

/// Tempat token & saksi waktu lisensi dibaca/ditulis.
///
/// Dibuat sebagai abstraksi (bukan `SharedPreferences` langsung) karena
/// pembacaannya harus **sinkron**: keadaan lisensi menentukan frame pertama,
/// jadi tidak boleh ada `await` di jalur itu — persis pola `ThemeModeStore`.
abstract interface class LicenseStore {
  String? readToken();
  DateTime? readActivatedAt();
  DateTime? readLastSeenAt();
  String? readDeviceIdFallback();

  Future<void> writeToken(String token, DateTime activatedAt);
  Future<void> writeLastSeenAt(DateTime at);
  Future<void> writeDeviceIdFallback(String value);
}

/// Implementasi produksi.
class SharedPrefsLicenseStore implements LicenseStore {
  const SharedPrefsLicenseStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? readToken() {
    final value = _prefs.getString(kLicenseTokenPrefKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  DateTime? readActivatedAt() => _readMillis(kLicenseActivatedAtPrefKey);

  @override
  DateTime? readLastSeenAt() => _readMillis(kLicenseLastSeenAtPrefKey);

  @override
  String? readDeviceIdFallback() {
    final value = _prefs.getString(kLicenseDeviceIdFallbackPrefKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<void> writeToken(String token, DateTime activatedAt) async {
    await _prefs.setString(kLicenseTokenPrefKey, token);
    await _prefs.setInt(
      kLicenseActivatedAtPrefKey,
      activatedAt.millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> writeLastSeenAt(DateTime at) async {
    // Saksi ini HANYA boleh maju (§6.3.G). Menulis nilai yang lebih kecil
    // sama saja memberi hadiah kepada jam yang dimundurkan.
    final current = readLastSeenAt();
    if (current != null && !at.isAfter(current)) return;
    await _prefs.setInt(kLicenseLastSeenAtPrefKey, at.millisecondsSinceEpoch);
  }

  @override
  Future<void> writeDeviceIdFallback(String value) =>
      _prefs.setString(kLicenseDeviceIdFallbackPrefKey, value);

  DateTime? _readMillis(String key) {
    final millis = _prefs.getInt(key);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}

/// Implementasi tanpa penyimpanan — dipakai sebagai **default provider** dan
/// oleh test.
///
/// Sama seperti `InMemoryThemeModeStore`: kalau `main()` lupa meng-override,
/// aplikasi tetap jalan dan pilihan pengguna hanya tidak bertahan. Itu jauh
/// lebih baik daripada `throw` yang mematikan setiap widget test M0–M9 yang
/// membangun `KasirApp` tanpa tahu-menahu soal lisensi.
class InMemoryLicenseStore implements LicenseStore {
  InMemoryLicenseStore({
    String? token,
    DateTime? activatedAt,
    DateTime? lastSeenAt,
    String? deviceIdFallback,
  }) {
    _token = token;
    _activatedAt = activatedAt;
    _lastSeenAt = lastSeenAt;
    _deviceIdFallback = deviceIdFallback;
  }

  String? _token;
  DateTime? _activatedAt;
  DateTime? _lastSeenAt;
  String? _deviceIdFallback;

  @override
  String? readToken() => _token;

  @override
  DateTime? readActivatedAt() => _activatedAt;

  @override
  DateTime? readLastSeenAt() => _lastSeenAt;

  @override
  String? readDeviceIdFallback() => _deviceIdFallback;

  @override
  Future<void> writeToken(String token, DateTime activatedAt) async {
    _token = token;
    _activatedAt = activatedAt;
  }

  @override
  Future<void> writeLastSeenAt(DateTime at) async {
    if (_lastSeenAt != null && !at.isAfter(_lastSeenAt!)) return;
    _lastSeenAt = at;
  }

  @override
  Future<void> writeDeviceIdFallback(String value) async =>
      _deviceIdFallback = value;
}

/// Pengenal cadangan 16 karakter heksadesimal untuk perangkat yang SSAID-nya
/// tidak terbaca atau bernilai cacat (PRD §6.3.C).
///
/// Konsekuensinya dinyatakan terus terang di UI: pada perangkat itu,
/// memasang ulang aplikasi **akan** mengubah kode perangkat, dan pembeli
/// perlu kode baru dari penjual. Menyembunyikan fakta ini akan berubah
/// menjadi tuduhan "aplikasinya rusak" di kemudian hari.
String generateFallbackDeviceSeed([Random? random]) {
  final rng = random ?? Random.secure();
  final buffer = StringBuffer('fallback-');
  for (var i = 0; i < 16; i++) {
    buffer.write(rng.nextInt(16).toRadixString(16));
  }
  return buffer.toString();
}
