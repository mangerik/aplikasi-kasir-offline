import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/license/device_code.dart';
import 'package:kasir_warung/core/license/license_payload.dart';
import 'package:kasir_warung/core/license/license_status.dart';

import '../../fixtures/license_vectors.dart';

/// Keadaan lisensi & mitigasi mundur-jam (PRD v1.1 §6.3.E/G, AC-6.10,
/// AC-6.13, AC-6.14, AC-6.16).
///
/// Seluruhnya diuji dengan **menyuntikkan tanggal acuan**, bukan menunggu
/// hari berganti — kalau sebuah aturan masa berlaku hanya bisa diuji dengan
/// menunggu, ia tidak akan pernah diuji.
void main() {
  LicensePayload payload({
    required LicenseType type,
    required DateTime issuedAt,
    int? durationDays,
    int? graceDays,
  }) {
    final issuedDay = LicensePayload.dateToDay(issuedAt);
    final duration = durationDays ?? type.defaultDurationDays;
    return LicensePayload(
      version: LicensePayload.currentVersion,
      type: type,
      issuedDay: issuedDay,
      expiryDay: duration == null
          ? LicensePayload.noExpiry
          : issuedDay + duration,
      graceDays: graceDays ?? type.defaultGraceDays,
      deviceHint: DeviceCode.hint(kVectorDeviceRaw),
    );
  }

  LicenseState stateAt(LicensePayload p, DateTime when) =>
      LicenseStatus.evaluate(payload: p, referenceTime: when).state;

  group('trial 3 hari (AC-6.10)', () {
    final trial = payload(
      type: LicenseType.coba,
      issuedAt: DateTime.utc(2026, 8, 10),
    );

    test('hari ke-1 & ke-2 terbuka normal', () {
      expect(stateAt(trial, DateTime.utc(2026, 8, 10, 9)), LicenseState.aktif);
      expect(stateAt(trial, DateTime.utc(2026, 8, 11, 9)), LicenseState.aktif);
    });

    test('hari ke-3 terbuka, dengan peringatan hari terakhir', () {
      expect(
        stateAt(trial, DateTime.utc(2026, 8, 12, 9)),
        LicenseState.akanBerakhir,
      );
    });

    test('hari ke-4 → layar "masa coba berakhir", tanpa masa tenggang', () {
      expect(
        stateAt(trial, DateTime.utc(2026, 8, 13, 0, 1)),
        LicenseState.kedaluwarsaTrial,
      );
      expect(
        stateAt(trial, DateTime.utc(2027, 1, 1)),
        LicenseState.kedaluwarsaTrial,
      );
    });

    test('trial yang habis mengunci seluruh aplikasi, tahunan tidak', () {
      expect(LicenseState.kedaluwarsaTrial.locksWholeApp, isTrue);
      expect(LicenseState.kedaluwarsaTahunan.locksWholeApp, isFalse);
      expect(LicenseState.kedaluwarsaTahunan.canSell, isFalse);
    });
  });

  group('lisensi selamanya', () {
    test('tidak pernah kedaluwarsa berapa pun umurnya', () {
      final lifetime = payload(
        type: LicenseType.selamanya,
        issuedAt: DateTime.utc(2020, 1, 1),
      );
      expect(stateAt(lifetime, DateTime.utc(2099, 12, 31)), LicenseState.aktif);
      expect(lifetime.isLifetime, isTrue);
    });
  });

  group('tahunan + masa tenggang 7 hari (AC-6.13, AC-6.14)', () {
    final yearly = payload(
      type: LicenseType.tahunan,
      issuedAt: DateTime.utc(2026, 8, 1),
    );
    // Kedaluwarsa = 2026-08-01 + 365 hari = 2027-08-01.
    final expiry = LicensePayload.dayToDate(yearly.expiryDay);

    test('jauh sebelum kedaluwarsa: aktif penuh, tanpa banner', () {
      expect(stateAt(yearly, DateTime.utc(2026, 9, 1)), LicenseState.aktif);
    });

    test('sisa 7 hari → akanBerakhir', () {
      final status = LicenseStatus.evaluate(
        payload: yearly,
        referenceTime: expiry.subtract(const Duration(days: 7)),
      );
      expect(status.state, LicenseState.akanBerakhir);
      expect(status.remainingDays, 7);
    });

    test('hari ke-1 masa tenggang: berfungsi penuh, sisa 7 hari', () {
      final status = LicenseStatus.evaluate(
        payload: yearly,
        referenceTime: expiry,
      );
      expect(status.state, LicenseState.masaTenggang);
      expect(status.graceRemainingDays, 7);
      expect(status.state.canSell, isTrue);
    });

    test('hari ke-7 masa tenggang: masih berfungsi, sisa 1 hari', () {
      final status = LicenseStatus.evaluate(
        payload: yearly,
        referenceTime: expiry.add(const Duration(days: 6)),
      );
      expect(status.state, LicenseState.masaTenggang);
      expect(status.graceRemainingDays, 1);
    });

    test('hari ke-8: layar Kasir terkunci, tapi bukan seluruh aplikasi', () {
      final status = LicenseStatus.evaluate(
        payload: yearly,
        referenceTime: expiry.add(const Duration(days: 7)),
      );
      expect(status.state, LicenseState.kedaluwarsaTahunan);
      expect(status.state.canSell, isFalse);
      expect(status.state.locksWholeApp, isFalse);
    });

    test('masa tenggang yang ikut ditandatangani bisa disesuaikan '
        'per pelanggan (K-6.13)', () {
      final generous = payload(
        type: LicenseType.tahunan,
        issuedAt: DateTime.utc(2026, 8, 1),
        graceDays: 30,
      );
      final generousExpiry = LicensePayload.dayToDate(generous.expiryDay);
      expect(
        stateAt(generous, generousExpiry.add(const Duration(days: 20))),
        LicenseState.masaTenggang,
      );
    });
  });

  group('jam monoton — mundur-jam tidak pernah menambah masa berlaku '
      '(K-6.8, AC-6.16)', () {
    test('waktuAcuan = max dari jam perangkat & tiga saksi', () {
      final result = monotonicReferenceTime(
        deviceNow: DateTime.utc(2025, 1, 1),
        lastSeenAt: DateTime.utc(2026, 8, 10),
        lastSaleAt: DateTime.utc(2026, 8, 11),
        activatedAt: DateTime.utc(2026, 8, 9),
      );
      expect(result, DateTime.utc(2026, 8, 11));
    });

    test('jam maju dipakai apa adanya (pengguna jujur tidak dihukum)', () {
      final result = monotonicReferenceTime(
        deviceNow: DateTime.utc(2027, 1, 1),
        lastSeenAt: DateTime.utc(2026, 8, 10),
      );
      expect(result, DateTime.utc(2027, 1, 1));
    });

    test('jam dimundurkan 1 tahun: lisensi yang sudah habis TETAP habis', () {
      final trial = payload(
        type: LicenseType.coba,
        issuedAt: DateTime.utc(2026, 8, 10),
      );
      final reference = monotonicReferenceTime(
        deviceNow: DateTime.utc(2025, 8, 20), // jam dimundurkan setahun
        lastSeenAt: DateTime.utc(2026, 8, 20),
        lastSaleAt: DateTime.utc(2026, 8, 19),
      );
      expect(
        LicenseStatus.evaluate(payload: trial, referenceTime: reference).state,
        LicenseState.kedaluwarsaTrial,
      );
    });

    test('`created_at` transaksi terbaru jadi saksi yang ikut terbawa '
        'restore backup', () {
      // Skenario nyata: pengguna memulihkan backup di HP yang jamnya sudah
      // dimundurkan, sehingga `license_last_seen_at` (yang TIDAK ikut
      // backup) tidak bisa menolong.
      final yearly = payload(
        type: LicenseType.tahunan,
        issuedAt: DateTime.utc(2024, 1, 1),
      );
      final reference = monotonicReferenceTime(
        deviceNow: DateTime.utc(2024, 6, 1),
        lastSaleAt: DateTime.utc(2026, 8, 1),
      );
      expect(
        LicenseStatus.evaluate(payload: yearly, referenceTime: reference).state,
        LicenseState.kedaluwarsaTahunan,
      );
    });

    test('banner jam mundur muncul di atas toleransi 10 menit, dan hanya '
        'itu — TIDAK mengunci', () {
      final now = DateTime.utc(2026, 8, 12, 10);
      expect(
        isClockRolledBack(
          deviceNow: now,
          referenceTime: now.add(const Duration(minutes: 5)),
        ),
        isFalse,
        reason: 'koreksi NTP biasa tidak boleh memicu peringatan palsu',
      );
      expect(
        isClockRolledBack(
          deviceNow: now,
          referenceTime: now.add(const Duration(hours: 5)),
        ),
        isTrue,
      );

      // Jam kacau + masa berlaku masih panjang → tetap aktif.
      final lifetime = payload(
        type: LicenseType.tahunan,
        issuedAt: DateTime.utc(2026, 8, 1),
      );
      final status = LicenseStatus.evaluate(
        payload: lifetime,
        referenceTime: now,
        clockRolledBack: true,
      );
      expect(status.state, LicenseState.aktif);
      expect(status.clockRolledBack, isTrue);
    });
  });

  group('belum aktif', () {
    test('tanpa muatan → belumAktif & mengunci seluruh aplikasi', () {
      final status = LicenseStatus.evaluate(
        payload: null,
        referenceTime: DateTime.utc(2026, 8, 12),
      );
      expect(status.state, LicenseState.belumAktif);
      expect(status.state.locksWholeApp, isTrue);
      expect(status.typeLabel, '—');
    });
  });
}
