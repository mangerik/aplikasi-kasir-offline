import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/license/device_code.dart';
import '../../../core/license/license_keys.dart';
import '../../../core/license/license_status.dart';
import '../../../core/license/license_verifier.dart';
import '../../../data/db/database_provider.dart';
import 'license_store.dart';

/// Tempat token lisensi disimpan. Di-override di `main()` dengan
/// [SharedPrefsLicenseStore] yang sudah dimuat sebelum `runApp()`.
final Provider<LicenseStore> licenseStoreProvider = Provider<LicenseStore>(
  (ref) => InMemoryLicenseStore(),
);

/// Kode perangkat 10 karakter (tanpa awalan `KW-`).
///
/// Di-override di `main()` dengan nilai hasil `DeviceIdService`. Nilai
/// default di sini hanya dipakai widget test — sengaja turunan dari benih
/// tetap supaya test bersifat deterministik dan tidak butuh perangkat.
final Provider<String> deviceCodeProvider = Provider<String>(
  (ref) => DeviceCode.fromSeed('kasirwarung.test.device'),
);

/// Verifikator dengan daftar kunci tepercaya build ini (AC-6.20).
final Provider<LicenseVerifier> licenseVerifierProvider =
    Provider<LicenseVerifier>(
      (ref) =>
          LicenseVerifier(trustedPublicKeysBase64: trustedLicensePublicKeys()),
    );

/// Keadaan lisensi hasil evaluasi **sebelum `runApp()`** (§6.3.F).
///
/// Default-nya sengaja "aktif tanpa muatan": tanpa itu, seluruh widget test
/// M0–M9 (yang membangun `KasirApp` tanpa tahu-menahu soal lisensi) akan
/// mati di layar Aktivasi. `main()` SELALU meng-override provider ini —
/// dijaga oleh `test/features/license/license_bootstrap_wiring_test.dart`
/// supaya default ini tidak pernah diam-diam menjadi gerbang yang terbuka
/// di produksi.
final Provider<LicenseStatus> licenseBootstrapProvider =
    Provider<LicenseStatus>((ref) => LicenseStatus.gerbangDimatikan());

/// Keadaan lisensi yang berlaku sekarang.
final NotifierProvider<LicenseController, LicenseStatus> licenseStatusProvider =
    NotifierProvider<LicenseController, LicenseStatus>(LicenseController.new);

class LicenseController extends Notifier<LicenseStatus> {
  @override
  LicenseStatus build() => ref.read(licenseBootstrapProvider);

  /// Coba aktifkan dengan [code]. Mengembalikan hasil verifikasi apa adanya
  /// supaya layar bisa menampilkan pesan yang **spesifik** per jenis
  /// kesalahan (AC-6.5, AC-6.6, AC-6.21).
  Future<LicenseVerification> activate(String code) async {
    final result = await ref
        .read(licenseVerifierProvider)
        .verify(code: code, deviceRaw: ref.read(deviceCodeProvider));
    if (result is! LicenseAccepted) return result;

    final store = ref.read(licenseStoreProvider);
    final now = DateTime.now();
    await store.writeToken(result.normalizedToken, now);
    await store.writeLastSeenAt(now);

    final reference = monotonicReferenceTime(
      deviceNow: now,
      lastSeenAt: store.readLastSeenAt(),
      lastSaleAt: await _lastSaleAt(),
      activatedAt: now,
    );
    state = LicenseStatus.evaluate(
      payload: result.payload,
      referenceTime: reference,
      activatedAt: now,
      clockRolledBack: isClockRolledBack(
        deviceNow: now,
        referenceTime: reference,
      ),
    );
    return result;
  }

  /// Evaluasi ulang keadaan: dipanggil setelah database terbuka (saksi
  /// `MAX(sales.created_at)`), saat `AppLifecycleState.resumed`, dan setiap
  /// kali satu penjualan tersimpan.
  ///
  /// Tidak pernah dipanggil di tengah alur pembayaran — layar Kasir baru
  /// terkunci pada frame berikutnya, sehingga transaksi berjalan tetap bisa
  /// diselesaikan sampai tersimpan (K-6.10, AC-6.18).
  Future<void> revalidate() async {
    // Gerbang yang sengaja dimatikan (default test) tidak boleh "dihidupkan
    // kembali" oleh evaluasi ulang — kalau tidak, setiap widget test M0–M9
    // akan terlempar ke layar Aktivasi begitu frame pertama lewat.
    if (state.gateDisabled) return;

    final store = ref.read(licenseStoreProvider);
    final now = DateTime.now();
    await store.writeLastSeenAt(now);

    final status = await evaluateLicense(
      store: store,
      deviceRaw: ref.read(deviceCodeProvider),
      verifier: ref.read(licenseVerifierProvider),
      deviceNow: now,
      lastSaleAt: await _lastSaleAt(),
    );
    state = status;
  }

  Future<DateTime?> _lastSaleAt() async {
    try {
      final db = ref.read(databaseProvider);
      final maxCreatedAt = db.sales.createdAt.max();
      final row = await (db.selectOnly(
        db.sales,
      )..addColumns([maxCreatedAt])).getSingleOrNull();
      final millis = row?.read<int>(maxCreatedAt);
      return millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (e) {
      // Saksi ini adalah bonus, bukan syarat. Database yang belum siap atau
      // sedang di-restore tidak boleh membuat aplikasi salah mengunci.
      debugPrint('Lisensi: saksi MAX(sales.created_at) dilewati ($e)');
      return null;
    }
  }
}

/// Evaluasi keadaan lisensi dari penyimpanan.
///
/// Dipakai `main()` (sebelum `runApp()`, tanpa database) **dan**
/// [LicenseController.revalidate] (setelah database terbuka, dengan saksi
/// `MAX(sales.created_at)`) — satu jalur kode, satu tafsir.
Future<LicenseStatus> evaluateLicense({
  required LicenseStore store,
  required String deviceRaw,
  required LicenseVerifier verifier,
  required DateTime deviceNow,
  DateTime? lastSaleAt,
}) async {
  final reference = monotonicReferenceTime(
    deviceNow: deviceNow,
    lastSeenAt: store.readLastSeenAt(),
    lastSaleAt: lastSaleAt,
    activatedAt: store.readActivatedAt(),
  );
  final rolledBack = isClockRolledBack(
    deviceNow: deviceNow,
    referenceTime: reference,
  );

  final token = store.readToken();
  if (token == null) {
    return LicenseStatus.belumAktif(
      referenceTime: reference,
      clockRolledBack: rolledBack,
    );
  }

  final result = await verifier.verify(code: token, deviceRaw: deviceRaw);
  if (result is! LicenseAccepted) {
    // Token tersimpan tidak lagi lolos (mis. kuncinya sudah dicabut, atau
    // berkas preferensi diedit). Perlakukan seperti belum aktif — jangan
    // sekali pun menghapus data pengguna karenanya.
    return LicenseStatus.belumAktif(
      referenceTime: reference,
      clockRolledBack: rolledBack,
    );
  }

  return LicenseStatus.evaluate(
    payload: result.payload,
    referenceTime: reference,
    activatedAt: store.readActivatedAt(),
    clockRolledBack: rolledBack,
  );
}

/// Jembatan `LicenseState` → `Listenable` untuk `GoRouter.refreshListenable`.
///
/// Gerbangnya harus hidup di lapisan router (K-6.9), dan `go_router` hanya
/// mau mendengarkan `Listenable` — bukan provider.
final Provider<ValueNotifier<LicenseState>> licenseGateProvider =
    Provider<ValueNotifier<LicenseState>>((ref) {
      final notifier = ValueNotifier<LicenseState>(
        ref.read(licenseStatusProvider).state,
      );
      ref.listen<LicenseStatus>(licenseStatusProvider, (previous, next) {
        notifier.value = next.state;
      });
      ref.onDispose(notifier.dispose);
      return notifier;
    });
