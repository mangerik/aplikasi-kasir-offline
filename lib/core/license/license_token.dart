import 'dart:typed_data';

import 'crc16.dart';
import 'crockford_base32.dart';
import 'license_payload.dart';

/// Bentuk kode aktivasi yang diketik/dipindai (PRD v1.1 §6.3.D).
///
/// ```
/// token = muatan(9) || tanda tangan(64) || CRC-16(2)      = 75 byte
/// teks  = "KW1-" + Crockford-Base32(token)                = 120 karakter
/// ```
///
/// Kode perangkat **ikut ditandatangani tapi tidak ikut dikirim** (K-6.4):
/// aplikasi menyusun ulang pesannya memakai kode perangkatnya sendiri.
/// Akibatnya kode yang diterbitkan untuk perangkat lain tidak akan pernah
/// lolos, tanpa memboroskan satu karakter pun untuk mengangkut kode
/// perangkat.
abstract final class LicenseToken {
  /// Panjang tanda tangan Ed25519 — tetap, tidak bisa dipotong (K-6.3).
  static const int signatureLength = 64;

  /// 9 + 64 + 2.
  static const int tokenLengthInBytes =
      LicensePayload.lengthInBytes + signatureLength + 2;

  /// 75 byte × 8 / 5 = 120 karakter, tanpa bit sisa.
  static const int textLength = 120;

  /// Awalan penanda versi format. Boleh ada atau tidak saat dimasukkan;
  /// keberadaannya memudahkan format v2 kelak dikenali sekilas.
  static const String prefix = 'KW1-';

  /// Pesan yang ditandatangani — **bukan** yang dikirim.
  static const String signaturePrefix = 'KASIRWARUNG-LICENSE-v1';

  /// `"KASIRWARUNG-LICENSE-v1" || 0x00 || deviceId(10) || muatan(9)`.
  static Uint8List signedMessage(String deviceRaw, List<int> payloadBytes) {
    final builder = BytesBuilder(copy: false)
      ..add(signaturePrefix.codeUnits)
      ..addByte(0x00)
      ..add(deviceRaw.codeUnits)
      ..add(payloadBytes);
    return builder.takeBytes();
  }

  /// Rakit token lengkap (muatan + tanda tangan + CRC) menjadi teks 120
  /// karakter tanpa pengelompokan.
  static String encode(List<int> payloadBytes, List<int> signature) {
    if (payloadBytes.length != LicensePayload.lengthInBytes) {
      throw ArgumentError('Muatan wajib ${LicensePayload.lengthInBytes} byte.');
    }
    if (signature.length != signatureLength) {
      throw ArgumentError('Tanda tangan Ed25519 wajib $signatureLength byte.');
    }
    final body = BytesBuilder(copy: false)
      ..add(payloadBytes)
      ..add(signature);
    final bytes = body.takeBytes();
    final crc = Crc16.compute(bytes);
    final full = BytesBuilder(copy: false)
      ..add(bytes)
      ..addByte((crc >> 8) & 0xFF)
      ..addByte(crc & 0xFF);
    return CrockfordBase32.encode(full.takeBytes());
  }

  /// Bentuk siap kirim ke pembeli: berawalan & dikelompokkan lima.
  static String format(String text) =>
      '$prefix${CrockfordBase32.group(normalize(text))}';

  /// Buang awalan `KW1-`, naikkan huruf, satukan karakter kembar, buang
  /// pemisah (AC-6.9).
  static String normalize(String raw) {
    var normalized = CrockfordBase32.normalize(raw);
    // Awalan "KW1" ikut lolos normalisasi sebagai teks biasa.
    if (normalized.length == textLength + 3 && normalized.startsWith('KW1')) {
      normalized = normalized.substring(3);
    }
    return normalized;
  }

  /// Bongkar teks menjadi bagian-bagiannya. Melempar [FormatException] bila
  /// panjang/alfabetnya tidak sah — pemanggil menerjemahkannya menjadi
  /// "salah ketik", bukan "kode palsu".
  static ({Uint8List payload, Uint8List signature, int crc, int expectedCrc})
  split(String normalized) {
    final bytes = CrockfordBase32.decode(normalized);
    if (bytes.length != tokenLengthInBytes) {
      throw FormatException('Panjang kode tidak pas.', normalized);
    }
    final payload = Uint8List.sublistView(
      bytes,
      0,
      LicensePayload.lengthInBytes,
    );
    final signature = Uint8List.sublistView(
      bytes,
      LicensePayload.lengthInBytes,
      LicensePayload.lengthInBytes + signatureLength,
    );
    final crc =
        (bytes[tokenLengthInBytes - 2] << 8) | bytes[tokenLengthInBytes - 1];
    final expected = Crc16.compute(
      Uint8List.sublistView(bytes, 0, tokenLengthInBytes - 2),
    );
    return (
      payload: payload,
      signature: signature,
      crc: crc,
      expectedCrc: expected,
    );
  }
}
