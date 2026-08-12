import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/license/license_keys.dart';
import 'core/license/license_verifier.dart';
import 'core/utils/date_formatter.dart';
import 'data/services/device_id_service.dart';
import 'features/license/providers/license_providers.dart';
import 'features/license/providers/license_store.dart';
import 'features/settings/providers/theme_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib dipanggil sebelum widget apa pun memakai DateFormatter (format
  // tanggal Indonesia, lihat core/utils/date_formatter.dart).
  await DateFormatter.init();

  // Preferensi tema dibaca SEBELUM runApp() (PRD v1.1 AC-5.5): kalau dibaca
  // setelahnya, frame pertama lahir bertema terang lalu berganti gelap —
  // "kedip putih" yang persis ingin dihindari mode gelap. `shared_preferences`
  // dipilih justru karena bisa dimuat di sini tanpa membuka database.
  final prefs = await SharedPreferences.getInstance();

  // Gerbang lisensi juga dievaluasi SEBELUM runApp() (PRD v1.1 §6.3.F,
  // AC-6.1): token dibaca dari `shared_preferences`, kode perangkat dibaca
  // dari SSAID, lalu tanda tangannya diverifikasi — semuanya offline dan
  // tanpa membuka database. Hasilnya membuat frame pertama sudah menampilkan
  // layar yang benar, tanpa kedipan layar Kasir sebelum layar Aktivasi.
  //
  // Saksi `MAX(sales.created_at)` untuk mitigasi mundur-jam BELUM ikut di
  // sini (databasenya belum terbuka); `KasirApp` menjalankan evaluasi ulang
  // setelah frame pertama, dan `redirect` router bereaksi sendiri.
  final licenseStore = SharedPrefsLicenseStore(prefs);
  final deviceRaw = await DeviceIdService.resolveDeviceRaw(licenseStore);
  final licenseStatus = await evaluateLicense(
    store: licenseStore,
    deviceRaw: deviceRaw,
    verifier: LicenseVerifier(
      trustedPublicKeysBase64: trustedLicensePublicKeys(),
    ),
    deviceNow: DateTime.now(),
  );

  runApp(
    ProviderScope(
      overrides: [
        themeModeStoreProvider.overrideWithValue(
          SharedPrefsThemeModeStore(prefs),
        ),
        licenseStoreProvider.overrideWithValue(licenseStore),
        deviceCodeProvider.overrideWithValue(deviceRaw),
        licenseBootstrapProvider.overrideWithValue(licenseStatus),
      ],
      child: const KasirApp(),
    ),
  );
}
