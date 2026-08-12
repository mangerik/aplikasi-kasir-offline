import 'dart:math';

/// Kode pemulihan offline 8 karakter (PRD v1.1 §8.3.A, K-8.4).
///
/// Satu-satunya jalan keluar bagi pemilik yang lupa PIN-nya sendiri pada
/// aplikasi yang **sengaja tidak punya akun online**: tidak ada pihak yang
/// bisa mereset dari luar, jadi kodenya harus ada sejak awal — ditampilkan
/// sekali, dicatat pengguna, dan disimpan hanya sebagai hash (AC-8.3).
///
/// Abjadnya memakai **Crockford Base32 tanpa huruf ambigu** (`I`, `L`,
/// `O`, `U` dibuang) — alasan yang sama dengan kode lisensi §6: kode ini
/// akan disalin dengan tangan ke kertas lalu diketik ulang berbulan-bulan
/// kemudian, jadi `0`/`O` dan `1`/`I` yang tertukar adalah kegagalan yang
/// bisa dicegah di tingkat abjad.
abstract final class RecoveryCode {
  /// Abjad 32 karakter tanpa `I`, `L`, `O`, `U`.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Panjang kode (tanpa tanda hubung).
  static const int length = 8;

  /// Bangkitkan kode acak kriptografis, mis. `7QK4-M2XB`.
  ///
  /// [random] hanya diisi di test supaya hasilnya bisa ditentukan; produksi
  /// selalu memakai `Random.secure()`.
  static String generate({Random? random}) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      if (i == 4) buffer.write('-');
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Normalisasi input pengguna sebelum dibandingkan: huruf besar, tanda
  /// hubung & spasi dibuang, lalu huruf yang MIRIP diseragamkan (`O` → `0`,
  /// `I`/`L` → `1`). Tanpa ini, kode yang benar-benar dicatat pengguna bisa
  /// ditolak hanya karena tulisan tangannya terbaca `O` alih-alih `0`.
  static String normalize(String raw) {
    final upper = raw.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    return upper
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('U', 'V');
  }

  /// `true` bila [raw] berbentuk kode yang mungkin (8 karakter abjad ini)
  /// — pemeriksaan bentuk, bukan kebenaran.
  static bool isWellFormed(String raw) {
    final normalized = normalize(raw);
    if (normalized.length != length) return false;
    return normalized.split('').every(alphabet.contains);
  }
}
