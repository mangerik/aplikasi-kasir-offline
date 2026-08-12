import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'device_code.dart';
import 'license_payload.dart';
import 'license_token.dart';

/// Sisi PENERBIT: membuat pasangan kunci & menandatangani muatan.
///
/// Berkas ini hidup di `lib/` bersama verifier — bukan di `tool/` — karena
/// K-6.12 mewajibkan penerbit dan verifikator memakai **jalur kode yang
/// sama persis**. Kalau format muatan pernah ditafsirkan berbeda oleh dua
/// implementasi, gejalanya adalah "lisensi sah ditolak aplikasi", yaitu
/// kerusakan terparah dari seluruh fitur ini (PRD v1.1 §6.7.3).
///
/// Ikut masuk APK, dan itu tidak berbahaya: menandatangani butuh **kunci
/// privat**, yang tidak pernah ada di dalam aplikasi maupun di repositori.
class LicenseIssuer {
  const LicenseIssuer(this.privateKeySeed);

  /// Benih (seed) 32 byte kunci privat Ed25519.
  final List<int> privateKeySeed;

  static final Ed25519 _algorithm = Ed25519();

  /// Buat pasangan kunci baru. Kembalian: benih privat + kunci publik,
  /// keduanya 32 byte.
  static Future<({Uint8List privateSeed, Uint8List publicKey})>
  generateKeyPair() async {
    final pair = await _algorithm.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final publicKey = await pair.extractPublicKey();
    return (
      privateSeed: Uint8List.fromList(seed),
      publicKey: Uint8List.fromList(publicKey.bytes),
    );
  }

  /// Kunci publik base64 dari benih privat — dipakai `--buat-kunci` untuk
  /// mencetak nilai siap tempel ke `license_keys.dart`.
  Future<String> publicKeyBase64() async {
    final pair = await _algorithm.newKeyPairFromSeed(privateKeySeed);
    final publicKey = await pair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Terbitkan kode aktivasi 120 karakter untuk [deviceRaw].
  ///
  /// [issuedAt] menentukan tanggal terbit; masa berlaku dihitung dari sana
  /// (K-6.14 — perpanjangan TIDAK ditumpuk pada sisa lama).
  Future<String> issue({
    required String deviceRaw,
    required LicenseType type,
    required DateTime issuedAt,
    int? durationDays,
    int? graceDays,
  }) async {
    final issuedDay = LicensePayload.dateToDay(issuedAt);
    final effectiveDuration = durationDays ?? type.defaultDurationDays;
    final expiryDay = effectiveDuration == null
        ? LicensePayload.noExpiry
        : issuedDay + effectiveDuration;
    if (expiryDay > LicensePayload.noExpiry) {
      throw ArgumentError('Masa berlaku melewati batas format (uint16).');
    }
    final payload = LicensePayload(
      version: LicensePayload.currentVersion,
      type: type,
      issuedDay: issuedDay,
      expiryDay: expiryDay,
      graceDays: graceDays ?? type.defaultGraceDays,
      deviceHint: DeviceCode.hint(deviceRaw),
    );
    return issueFromPayload(deviceRaw: deviceRaw, payload: payload);
  }

  /// Varian tingkat rendah — dipakai vektor uji untuk menyusun muatan yang
  /// ganjil dengan sengaja (versi masa depan, kedaluwarsa di masa lalu).
  Future<String> issueFromPayload({
    required String deviceRaw,
    required LicensePayload payload,
  }) async {
    final payloadBytes = payload.toBytes();
    final message = LicenseToken.signedMessage(deviceRaw, payloadBytes);
    final pair = await _algorithm.newKeyPairFromSeed(privateKeySeed);
    final signature = await _algorithm.sign(message, keyPair: pair);
    return LicenseToken.encode(payloadBytes, signature.bytes);
  }
}
