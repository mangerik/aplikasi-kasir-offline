import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crockford_base32.dart';
import 'device_code.dart';
import 'license_payload.dart';
import 'license_token.dart';

/// Sebab sebuah kode ditolak.
///
/// Sengaja **bukan** satu `false`: pesan yang tepat adalah bagian dari
/// fiturnya. Menuduh pembeli yang salah ketik satu karakter sebagai pemakai
/// kode bajakan adalah kerusakan yang jauh lebih mahal daripada kode yang
/// panjang (PRD v1.1 §6.3.D, K-6.7).
enum LicenseRejection {
  /// CRC gagal / panjang tidak pas / ada karakter di luar alfabet.
  salahKetik,

  /// Petunjuk perangkat tidak cocok — kode ini milik HP lain.
  perangkatLain,

  /// Tanda tangan tidak cocok dengan satu pun kunci tepercaya.
  tidakSah,

  /// Versi format lebih baru daripada yang dikenal aplikasi ini (AC-6.21).
  versiTerlaluBaru,
}

/// Pesan Bahasa Indonesia per jenis penolakan. Dipakai layar Aktivasi
/// **dan** perintah `--verifikasi` di tool penjual, supaya penjual melihat
/// persis kalimat yang dilihat pembeli.
extension LicenseRejectionMessage on LicenseRejection {
  String get message => switch (this) {
    LicenseRejection.salahKetik =>
      'Kode salah ketik atau belum lengkap. Periksa lagi — pastikan semua '
          'kelompok terisi 5 karakter.',
    LicenseRejection.perangkatLain =>
      'Kode ini diterbitkan untuk perangkat lain. Kirim kode perangkat HP '
          'ini ke penjual untuk mendapat kode yang cocok.',
    LicenseRejection.tidakSah =>
      'Kode tidak sah. Pastikan kode disalin utuh dari pesan penjual.',
    LicenseRejection.versiTerlaluBaru =>
      'Kode ini butuh versi aplikasi yang lebih baru. Perbarui aplikasi '
          'dulu, lalu masukkan kembali kodenya.',
  };
}

/// Hasil verifikasi: diterima (beserta muatannya) atau ditolak (beserta
/// sebabnya).
sealed class LicenseVerification {
  const LicenseVerification();

  bool get isAccepted => this is LicenseAccepted;
}

class LicenseAccepted extends LicenseVerification {
  const LicenseAccepted({required this.payload, required this.normalizedToken});

  final LicensePayload payload;

  /// Bentuk kode yang disimpan ke `shared_preferences`: 120 karakter, tanpa
  /// awalan & tanpa tanda hubung.
  final String normalizedToken;
}

class LicenseRejected extends LicenseVerification {
  const LicenseRejected(this.reason);

  final LicenseRejection reason;

  String get message => reason.message;
}

/// Verifikator Ed25519 (K-6.2).
///
/// Menerima **daftar** kunci publik tepercaya, bukan satu kunci (AC-6.20):
/// rotasi kunci penerbit tidak boleh memaksa perubahan format token maupun
/// alur verifikasi, dan token lama harus tetap lolos selama kunci lamanya
/// masih terdaftar.
class LicenseVerifier {
  LicenseVerifier({required this.trustedPublicKeysBase64});

  /// Kunci publik (32 byte, base64). Lihat `license_keys.dart`.
  final List<String> trustedPublicKeysBase64;

  static final Ed25519 _algorithm = Ed25519();

  /// Verifikasi [code] untuk perangkat [deviceRaw] (10 karakter, tanpa
  /// awalan `KW-`).
  ///
  /// Urutan pemeriksaannya disengaja: bentuk → CRC → versi → jenis →
  /// petunjuk perangkat → tanda tangan. Setiap langkah punya pesan sendiri,
  /// dan yang paling sering terjadi (salah ketik) diperiksa paling awal.
  Future<LicenseVerification> verify({
    required String code,
    required String deviceRaw,
  }) async {
    final normalized = LicenseToken.normalize(code);
    if (normalized.length != LicenseToken.textLength ||
        !CrockfordBase32.isValidNormalized(normalized)) {
      return const LicenseRejected(LicenseRejection.salahKetik);
    }

    final ({Uint8List payload, Uint8List signature, int crc, int expectedCrc})?
    parts;
    try {
      parts = LicenseToken.split(normalized);
    } on FormatException {
      return const LicenseRejected(LicenseRejection.salahKetik);
    }
    if (parts.crc != parts.expectedCrc) {
      return const LicenseRejected(LicenseRejection.salahKetik);
    }

    final payloadBytes = parts.payload;
    final parsed = LicensePayload.parse(payloadBytes);
    if (parsed.version > LicensePayload.currentVersion) {
      return const LicenseRejected(LicenseRejection.versiTerlaluBaru);
    }
    final payload = parsed.payload;
    if (payload == null) {
      return const LicenseRejected(LicenseRejection.tidakSah);
    }

    // Petunjuk perangkat diperiksa SEBELUM tanda tangan: satu-satunya
    // gunanya adalah membedakan "kode untuk HP lain" dari "kode palsu".
    if (payload.deviceHint != DeviceCode.hint(deviceRaw)) {
      return const LicenseRejected(LicenseRejection.perangkatLain);
    }

    final message = LicenseToken.signedMessage(deviceRaw, payloadBytes);
    final signatureBytes = parts.signature.toList(growable: false);
    for (final keyBase64 in trustedPublicKeysBase64) {
      final List<int> keyBytes;
      try {
        keyBytes = base64Decode(keyBase64.trim());
      } on FormatException {
        continue;
      }
      if (keyBytes.length != 32) continue;
      final ok = await _algorithm.verify(
        message,
        signature: Signature(
          signatureBytes,
          publicKey: SimplePublicKey(keyBytes, type: KeyPairType.ed25519),
        ),
      );
      if (ok) {
        return LicenseAccepted(payload: payload, normalizedToken: normalized);
      }
    }
    return const LicenseRejected(LicenseRejection.tidakSah);
  }
}
