import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hash PIN (SHA-256 + salt, sesuai architecture.md §5.4).
///
/// HOOK dasarnya (hash tanpa salt) disiapkan di Milestone 3 untuk gerbang
/// PIN sebelum void transaksi. Milestone 5 (layar set/ubah/hapus PIN
/// penuh) menambah [generateSalt] dan parameter [salt] opsional di [hash]
/// — DEFAULT `''` supaya panggilan lama `PinHasher.hash(pin)` (satu
/// argumen) TETAP menghasilkan nilai yang sama persis seperti sebelumnya,
/// tidak ada migrasi nilai lama yang diperlukan.
///
/// PIN yang dibuat lewat layar Pengaturan M5 SELALU disertai salt acak
/// (disimpan di `settings.pin_salt`), sehingga hash `settings.pin_hash`
/// tidak bisa dicocokkan lewat rainbow table PIN 6 digit (hanya 10^6
/// kombinasi).
abstract final class PinHasher {
  /// Menghasilkan salt acak (base64url, aman secara kriptografis) untuk
  /// PIN baru.
  static String generateSalt({int length = 16}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hash `salt:pin` dengan SHA-256. [salt] kosong (default) menghasilkan
  /// hash yang SAMA seperti versi Milestone 3 (tanpa salt) — dipakai untuk
  /// kompatibilitas mundur saat memverifikasi PIN yang disimpan tanpa
  /// `pin_salt`.
  static String hash(String pin, [String salt = '']) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
