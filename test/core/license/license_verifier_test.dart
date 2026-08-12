import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/license/crockford_base32.dart';
import 'package:kasir_warung/core/license/device_code.dart';
import 'package:kasir_warung/core/license/license_keys.dart';
import 'package:kasir_warung/core/license/license_payload.dart';
import 'package:kasir_warung/core/license/license_token.dart';
import 'package:kasir_warung/core/license/license_verifier.dart';

import '../../fixtures/license_vectors.dart';

/// Verifikasi kode aktivasi terhadap **vektor uji tetap** (AC-6.7, AC-6.8,
/// AC-6.9, AC-6.21) — tanpa perangkat, tanpa jaringan, tanpa berkas di luar
/// repo.
void main() {
  final verifier = LicenseVerifier(
    trustedPublicKeysBase64: trustedLicensePublicKeysFor(debugBuild: true),
  );

  Future<LicenseVerification> verify(String code, {String? device}) =>
      verifier.verify(code: code, deviceRaw: device ?? kVectorDeviceRaw);

  group('vektor uji tetap (AC-6.8)', () {
    test('kode perangkat vektor konsisten dengan benihnya', () {
      expect(DeviceCode.fromSeed(kVectorDeviceSeed), kVectorDeviceRaw);
      expect(
        DeviceCode.fromSeed(kVectorOtherDeviceSeed),
        kVectorOtherDeviceRaw,
      );
    });

    test('semua vektor panjangnya persis 120 karakter', () {
      for (final code in [
        kVectorTrialValid,
        kVectorTrialExpired,
        kVectorLifetime,
        kVectorLifetimeOld,
        kVectorYearlyValid,
        kVectorYearlyExpired,
        kVectorOtherDevice,
        kVectorForeignKey,
        kVectorFutureVersion,
      ]) {
        expect(code.length, LicenseToken.textLength);
      }
    });

    test('trial / selamanya / tahunan — sah maupun kedaluwarsa — SEMUANYA '
        'lolos verifikasi tanda tangan', () async {
      // Kedaluwarsa BUKAN urusan verifikator: tanda tangannya tetap sah,
      // yang berubah hanya keadaan yang diturunkan dari tanggalnya
      // (license_status_test.dart). Memisahkan keduanya penting supaya
      // "kode kedaluwarsa" tidak pernah salah dilaporkan sebagai
      // "kode tidak sah".
      final cases = <String, LicenseType>{
        kVectorTrialValid: LicenseType.coba,
        kVectorTrialExpired: LicenseType.coba,
        kVectorLifetime: LicenseType.selamanya,
        kVectorLifetimeOld: LicenseType.selamanya,
        kVectorYearlyValid: LicenseType.tahunan,
        kVectorYearlyExpired: LicenseType.tahunan,
      };
      for (final entry in cases.entries) {
        final result = await verify(entry.key);
        expect(result, isA<LicenseAccepted>(), reason: entry.key);
        expect((result as LicenseAccepted).payload.type, entry.value);
      }
    });

    test(
      'masa tenggang tahunan ikut ditandatangani = 7 hari (K-6.13)',
      () async {
        final result = await verify(kVectorYearlyValid) as LicenseAccepted;
        expect(result.payload.graceDays, 7);
        expect(result.payload.isLifetime, isFalse);
      },
    );

    test('trial tidak punya masa tenggang', () async {
      final result = await verify(kVectorTrialValid) as LicenseAccepted;
      expect(result.payload.graceDays, 0);
    });

    test('lifetime tidak punya tanggal kedaluwarsa', () async {
      final result = await verify(kVectorLifetime) as LicenseAccepted;
      expect(result.payload.isLifetime, isTrue);
      expect(result.payload.expiresAt, isNull);
    });
  });

  group('penolakan berjenis-jenis, bukan satu `false`', () {
    test('kode untuk perangkat lain → perangkatLain, bukan tidakSah '
        '(AC-6.5)', () async {
      final result = await verify(kVectorOtherDevice);
      expect(result, isA<LicenseRejected>());
      expect(
        (result as LicenseRejected).reason,
        LicenseRejection.perangkatLain,
      );
      expect(result.message, contains('perangkat lain'));
    });

    test('kode yang sama SAH di perangkat yang memintanya', () async {
      final result = await verify(
        kVectorOtherDevice,
        device: kVectorOtherDeviceRaw,
      );
      expect(result, isA<LicenseAccepted>());
    });

    test('ditandatangani kunci di luar daftar tepercaya → tidakSah', () async {
      final result = await verify(kVectorForeignKey);
      expect((result as LicenseRejected).reason, LicenseRejection.tidakSah);
    });

    test('muatan versi lebih baru → versiTerlaluBaru, bukan tidakSah '
        '(AC-6.21)', () async {
      final result = await verify(kVectorFutureVersion);
      expect(
        (result as LicenseRejected).reason,
        LicenseRejection.versiTerlaluBaru,
      );
      expect(result.message, contains('versi aplikasi yang lebih baru'));
    });

    test('kode kosong / terlalu pendek → salahKetik', () async {
      expect(
        ((await verify('')) as LicenseRejected).reason,
        LicenseRejection.salahKetik,
      );
      expect(
        ((await verify('KW1-040GJ-V89E0')) as LicenseRejected).reason,
        LicenseRejection.salahKetik,
      );
    });
  });

  group('salah ketik vs kode palsu (K-6.7, AC-6.6, AC-6.7)', () {
    test('SATU karakter diubah pada SELURUH 120 posisi → selalu '
        'salahKetik', () async {
      const alphabet = CrockfordBase32.alphabet;
      for (var i = 0; i < kVectorLifetime.length; i++) {
        final original = kVectorLifetime[i];
        // Ganti dengan karakter alfabet lain yang bukan sinonimnya.
        final replacement = original == alphabet[0] ? alphabet[7] : alphabet[0];
        final mutated = kVectorLifetime.replaceRange(i, i + 1, replacement);
        final result = await verify(mutated);
        expect(
          result,
          isA<LicenseRejected>(),
          reason: 'posisi $i ($original→$replacement) diterima',
        );
        expect(
          (result as LicenseRejected).reason,
          LicenseRejection.salahKetik,
          reason:
              'posisi $i ($original→$replacement) menuduh pengguna memakai '
              'kode palsu padahal ia cuma salah ketik',
        );
      }
    });

    test('muatan dipalsukan lalu CRC dihitung ULANG → selalu ditolak, dan '
        'BUKAN sebagai salah ketik', () async {
      final bytes = CrockfordBase32.decode(kVectorLifetime).toList();
      // Balik satu bit di tiap byte muatan (byte 0..8), hitung ulang CRC.
      for (var index = 0; index < LicensePayload.lengthInBytes; index++) {
        final tampered = [...bytes];
        tampered[index] = tampered[index] ^ 0x01;
        final payload = tampered.sublist(0, LicensePayload.lengthInBytes);
        final signature = tampered.sublist(
          LicensePayload.lengthInBytes,
          LicensePayload.lengthInBytes + LicenseToken.signatureLength,
        );
        final forged = LicenseToken.encode(payload, signature);
        final result = await verify(forged);
        expect(result, isA<LicenseRejected>(), reason: 'byte $index lolos');
        expect(
          (result as LicenseRejected).reason,
          isNot(LicenseRejection.salahKetik),
          reason: 'byte $index: CRC sudah benar, jadi ini pemalsuan',
        );
      }
    });

    test('tanda tangan dipalsukan (CRC dihitung ulang) → tidakSah', () async {
      final bytes = CrockfordBase32.decode(kVectorLifetime).toList();
      final payload = bytes.sublist(0, LicensePayload.lengthInBytes);
      final signature = bytes.sublist(
        LicensePayload.lengthInBytes,
        LicensePayload.lengthInBytes + LicenseToken.signatureLength,
      );
      signature[10] = signature[10] ^ 0xFF;
      final forged = LicenseToken.encode(payload, signature);
      expect(
        ((await verify(forged)) as LicenseRejected).reason,
        LicenseRejection.tidakSah,
      );
    });
  });

  group('normalisasi masukan (AC-6.9)', () {
    test('huruf kecil, I/l→1, O→0, spasi & tanda hubung acak, awalan KW1- '
        'yang ada/tidak — semuanya menghasilkan hasil yang sama', () async {
      final variants = <String>[
        kVectorLifetime,
        kVectorLifetime.toLowerCase(),
        LicenseToken.format(kVectorLifetime),
        'KW1-$kVectorLifetime',
        kVectorLifetime.replaceAll('0', 'O').replaceAll('1', 'l'),
        kVectorLifetime.replaceAll('1', 'I').toLowerCase(),
        '  ${CrockfordBase32.group(kVectorLifetime, size: 3, separator: ' ')}  ',
      ];
      for (final variant in variants) {
        final result = await verify(variant);
        expect(
          result,
          isA<LicenseAccepted>(),
          reason: 'varian ditolak: ${variant.substring(0, 12)}…',
        );
      }
    });

    test('token yang disimpan selalu bentuk yang sudah dinormalkan', () async {
      final result =
          await verify(LicenseToken.format(kVectorLifetime)) as LicenseAccepted;
      expect(result.normalizedToken, kVectorLifetime);
      expect(result.normalizedToken, isNot(contains('-')));
    });
  });
}
