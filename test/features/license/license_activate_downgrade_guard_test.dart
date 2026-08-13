import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/license/license_status.dart';
import 'package:kasir_warung/core/license/license_verifier.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/features/license/providers/license_providers.dart';
import 'package:kasir_warung/features/license/providers/license_store.dart';

import '../../fixtures/license_vectors.dart';

/// Gerbang anti-penurunan lisensi di `LicenseController.activate`:
/// kode yang SAH tapi SUDAH kedaluwarsa tidak boleh menimpa lisensi yang
/// masih berlaku. Tanpa gerbang ini, pengguna lifetime yang tak sengaja
/// menempel kode trial lamanya langsung terlempar ke layar "masa coba
/// berakhir" — padahal lisensinya baik-baik saja.
///
/// Kebalikannya WAJIB tetap berlaku: saat TIDAK ada lisensi berjalan
/// (belumAktif/kedaluwarsa), kode kedaluwarsa tetap diterima apa adanya —
/// itulah yang membuat "trial tidak bisa direset dengan pasang ulang"
/// (AC-6.11, diuji di `license_activation_flow_test.dart`).
void main() {
  late AppDatabase db;

  setUpAll(() => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Muatan hasil verifikasi [code] pada perangkat uji — untuk membangun
  /// status bootstrap persis seperti yang dilakukan `main()`.
  Future<LicenseStatus> statusFor(String code) async {
    final probe = ProviderContainer();
    addTearDown(probe.dispose);
    final accepted =
        await probe
                .read(licenseVerifierProvider)
                .verify(code: code, deviceRaw: probe.read(deviceCodeProvider))
            as LicenseAccepted;
    final now = DateTime.now();
    return LicenseStatus.evaluate(
      payload: accepted.payload,
      referenceTime: now,
      activatedAt: now,
      clockRolledBack: false,
    );
  }

  ProviderContainer buildContainer({
    required InMemoryLicenseStore store,
    required LicenseStatus bootstrap,
  }) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        licenseStoreProvider.overrideWithValue(store),
        licenseBootstrapProvider.overrideWithValue(bootstrap),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('kode trial kedaluwarsa DITOLAK saat lisensi lifetime masih aktif — '
      'token & keadaan tidak berubah', () async {
    final store = InMemoryLicenseStore(
      token: kVectorLifetime,
      activatedAt: DateTime.now(),
    );
    final container = buildContainer(
      store: store,
      bootstrap: await statusFor(kVectorLifetime),
    );

    final result = await container
        .read(licenseStatusProvider.notifier)
        .activate(kVectorTrialExpired);

    expect(result, isA<LicenseRejected>());
    expect(
      (result as LicenseRejected).reason,
      LicenseRejection.kodeSudahKedaluwarsa,
    );
    expect(store.readToken(), kVectorLifetime, reason: 'token TIDAK tertimpa');
    expect(container.read(licenseStatusProvider).state.canSell, isTrue);
  });

  test('kode tahunan kedaluwarsa juga ditolak saat lisensi masih aktif', () async {
    final store = InMemoryLicenseStore(
      token: kVectorLifetime,
      activatedAt: DateTime.now(),
    );
    final container = buildContainer(
      store: store,
      bootstrap: await statusFor(kVectorLifetime),
    );

    final result = await container
        .read(licenseStatusProvider.notifier)
        .activate(kVectorYearlyExpired);

    expect(result, isA<LicenseRejected>());
    expect(store.readToken(), kVectorLifetime);
  });

  test('kode yang MASIH berlaku tetap diterima saat lisensi lain aktif '
      '(perpanjangan/pindah jenis bukan penurunan)', () async {
    final store = InMemoryLicenseStore(
      token: kVectorYearlyValid,
      activatedAt: DateTime.now(),
    );
    final container = buildContainer(
      store: store,
      bootstrap: await statusFor(kVectorYearlyValid),
    );

    final result = await container
        .read(licenseStatusProvider.notifier)
        .activate(kVectorLifetime);

    expect(result, isA<LicenseAccepted>());
    expect(store.readToken(), kVectorLifetime);
    expect(container.read(licenseStatusProvider).state.canSell, isTrue);
  });

  test('saat TIDAK ada lisensi berjalan, kode kedaluwarsa tetap diterima '
      '(AC-6.11 tidak berubah arti)', () async {
    final store = InMemoryLicenseStore();
    final container = buildContainer(
      store: store,
      bootstrap: LicenseStatus.belumAktif(referenceTime: DateTime.now()),
    );

    final result = await container
        .read(licenseStatusProvider.notifier)
        .activate(kVectorTrialExpired);

    expect(result, isA<LicenseAccepted>());
    expect(store.readToken(), kVectorTrialExpired);
    expect(
      container.read(licenseStatusProvider).state,
      LicenseState.kedaluwarsaTrial,
    );
  });
}
