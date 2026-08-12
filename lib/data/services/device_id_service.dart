import 'package:flutter/services.dart';

import '../../core/license/device_code.dart';
import '../../features/license/providers/license_store.dart';

/// Sumber kode perangkat (PRD v1.1 §6.3.C).
///
/// Membaca SSAID lewat `MethodChannel` milik sendiri (lihat
/// `MainActivity.kt`) — nol dependency platform baru, alasan yang sama
/// persis dengan K-9.1.
abstract final class DeviceIdService {
  static const MethodChannel channel = MethodChannel('kasirwarung/device');

  /// Baca SSAID mentah. `null` bila kanal tidak tersedia (mis. di widget
  /// test atau platform selain Android).
  static Future<String?> readSsaid() async {
    try {
      return await channel.invokeMethod<String>('ssaid');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Kode perangkat 10 karakter (tanpa awalan `KW-`) untuk perangkat ini.
  ///
  /// Bila SSAID tidak terbaca atau bernilai cacat yang terkenal, sebuah
  /// pengenal acak dibangkitkan **sekali** dan disimpan di
  /// `shared_preferences` — supaya kode perangkatnya tetap stabil selama
  /// aplikasi tidak dipasang ulang.
  static Future<String> resolveDeviceRaw(LicenseStore store) async {
    final ssaid = await readSsaid();
    if (!DeviceCode.isUnusableSsaid(ssaid)) {
      return DeviceCode.fromSeed(ssaid!.trim().toLowerCase());
    }

    final existing = store.readDeviceIdFallback();
    if (existing != null) return DeviceCode.fromSeed(existing);

    final generated = generateFallbackDeviceSeed();
    await store.writeDeviceIdFallback(generated);
    return DeviceCode.fromSeed(generated);
  }
}
