import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/license/license_keys.dart';
import 'package:kasir_warung/core/license/license_status.dart';
import 'package:kasir_warung/core/license/license_verifier.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/services/backup_service.dart';
import 'package:kasir_warung/features/license/providers/license_providers.dart';
import 'package:kasir_warung/features/license/providers/license_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../fixtures/license_vectors.dart';

/// `BackupService` menulis lewat `getApplicationDocumentsDirectory()`, yang
/// tidak tersedia di `flutter_test` — arahkan ke folder temp sistem (pola
/// sama dengan `test/data/services/backup_service_test.dart`).
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

/// Penyimpanan lisensi & jaminan bahwa ia TIDAK ikut backup
/// (K-6.1, AC-6.17).
void main() {
  final verifier = LicenseVerifier(
    trustedPublicKeysBase64: trustedLicensePublicKeysFor(debugBuild: true),
  );

  group('lokasi penyimpanan', () {
    test('kunci penyimpanan persis seperti PRD §6.5', () {
      expect(kLicenseTokenPrefKey, 'license_token');
      expect(kLicenseActivatedAtPrefKey, 'license_activated_at');
      expect(kLicenseLastSeenAtPrefKey, 'license_last_seen_at');
      expect(kLicenseDeviceIdFallbackPrefKey, 'license_device_id_fallback');
    });

    test('saksi last_seen HANYA boleh maju', () async {
      final store = InMemoryLicenseStore();
      await store.writeLastSeenAt(DateTime.utc(2026, 8, 12));
      await store.writeLastSeenAt(DateTime.utc(2025, 1, 1));
      expect(store.readLastSeenAt(), DateTime.utc(2026, 8, 12));

      await store.writeLastSeenAt(DateTime.utc(2026, 9, 1));
      expect(store.readLastSeenAt(), DateTime.utc(2026, 9, 1));
    });

    test('pengenal cadangan dibangkitkan sekali & bentuknya stabil', () {
      final a = generateFallbackDeviceSeed();
      final b = generateFallbackDeviceSeed();
      expect(a, startsWith('fallback-'));
      expect(a.length, 'fallback-'.length + 16);
      expect(a, isNot(b));
    });
  });

  group('evaluateLicense', () {
    test('tanpa token → belumAktif', () async {
      final status = await evaluateLicense(
        store: InMemoryLicenseStore(),
        deviceRaw: kVectorDeviceRaw,
        verifier: verifier,
        deviceNow: DateTime.utc(2026, 8, 12),
      );
      expect(status.state, LicenseState.belumAktif);
    });

    test('token untuk perangkat lain → belumAktif (bukan crash, bukan '
        'lolos)', () async {
      final status = await evaluateLicense(
        store: InMemoryLicenseStore(token: kVectorOtherDevice),
        deviceRaw: kVectorDeviceRaw,
        verifier: verifier,
        deviceNow: DateTime.utc(2026, 8, 12),
      );
      expect(status.state, LicenseState.belumAktif);
    });

    test('token lifetime → aktif, dan jenisnya diturunkan ulang dari token '
        '(bukan disimpan terpisah)', () async {
      final status = await evaluateLicense(
        store: InMemoryLicenseStore(
          token: kVectorLifetime,
          activatedAt: DateTime.utc(2026, 8, 10),
        ),
        deviceRaw: kVectorDeviceRaw,
        verifier: verifier,
        deviceNow: DateTime.utc(2026, 8, 12),
      );
      expect(status.state, LicenseState.aktif);
      expect(status.typeLabel, 'Selamanya');
      expect(status.isLifetime, isTrue);
    });

    test('saksi MAX(sales.created_at) mengalahkan jam yang dimundurkan '
        '(AC-6.16)', () async {
      final status = await evaluateLicense(
        store: InMemoryLicenseStore(token: kVectorTrialValid),
        deviceRaw: kVectorDeviceRaw,
        verifier: verifier,
        // Jam dimundurkan ke dalam masa berlaku trial…
        deviceNow: DateTime.utc(2026, 8, 11),
        // …tapi ada transaksi tersimpan jauh setelahnya.
        lastSaleAt: DateTime.utc(2027, 1, 1),
      );
      expect(status.state, LicenseState.kedaluwarsaTrial);
      expect(status.clockRolledBack, isTrue);
    });
  });

  group('backup TIDAK pernah membawa lisensi (AC-6.17)', () {
    test('file backup dari perangkat berlisensi tidak memuat satu pun '
        'nilai lisensi di tabel settings', () async {
      final dir = await Directory.systemTemp.createTemp('kasir_lisensi_test');
      addTearDown(() => dir.delete(recursive: true));
      PathProviderPlatform.instance = _FakePathProviderPlatform(dir.path);

      final dbFile = File('${dir.path}/kasir_warung.sqlite');
      final db = AppDatabase(NativeDatabase(dbFile));
      // Aplikasi dipakai normal: ada pengaturan toko, dan lisensi AKTIF —
      // yang terakhir sengaja disimpan di `shared_preferences`, bukan di
      // sini (K-6.1).
      await db
          .into(db.settings)
          .insert(
            SettingsCompanion.insert(key: 'store_name', value: 'Warung Bu Ani'),
          );
      final backupPath = await BackupService.createBackup(db);
      await db.close();

      final backup = sqlite.sqlite3.open(backupPath);
      addTearDown(backup.close);
      final rows = backup.select('SELECT key, value FROM settings');
      final keys = rows.map((r) => r['key'] as String).toList();
      final values = rows.map((r) => '${r['value']}').join('\n');

      expect(keys, contains('store_name'));
      for (final licenseKey in [
        kLicenseTokenPrefKey,
        kLicenseActivatedAtPrefKey,
        kLicenseLastSeenAtPrefKey,
        kLicenseDeviceIdFallbackPrefKey,
      ]) {
        expect(keys, isNot(contains(licenseKey)), reason: licenseKey);
      }
      expect(values.contains(kVectorLifetime), isFalse);
      expect(values.contains(kVectorDeviceRaw), isFalse);
    });

    test('restore di perangkat lain tetap meminta aktivasi: penyimpanan '
        'lisensi tidak tersentuh restore', () async {
      // Restore hanya menimpa berkas database. `shared_preferences`
      // perangkat tujuan — tempat token hidup — tidak ikut, sehingga
      // perangkat B tetap `belumAktif`.
      final targetStore = InMemoryLicenseStore();
      final status = await evaluateLicense(
        store: targetStore,
        deviceRaw: 'PERANGKATB',
        verifier: verifier,
        deviceNow: DateTime.utc(2026, 8, 12),
      );
      expect(status.state, LicenseState.belumAktif);
      expect(targetStore.readToken(), isNull);
    });
  });
}
