import 'package:crypto/crypto.dart';

import 'crockford_base32.dart';

/// Kode perangkat `KW-XXXXX-XXXXX` (PRD v1.1 §6.3.C, K-6.5).
///
/// Yang beredar di WhatsApp BUKAN SSAID mentah, melainkan turunannya:
///
/// ```
/// kode = crockford32( SHA-256("kasirwarung.device.v1|" + SSAID)[0..45 bit] )
///        + 1 karakter cek
/// ```
///
/// Tiga alasan tidak menampilkan SSAID apa adanya: 16 karakter heksadesimal
/// jauh lebih rawan salah ketik dan tidak punya karakter cek; SSAID adalah
/// pengenal perangkat yang tidak perlu beredar di grup obrolan; dan 45 bit
/// (±3,5 × 10¹³ kemungkinan) sudah jauh lebih dari cukup untuk basis
/// pelanggan UMKM.
abstract final class DeviceCode {
  /// Pemisah domain: mengunci turunan ini ke aplikasi & versi format ini,
  /// sehingga hash yang sama tidak pernah bermakna ganda di tempat lain.
  static const String hashPrefix = 'kasirwarung.device.v1|';

  /// Awalan yang ditampilkan ke pengguna.
  static const String displayPrefix = 'KW-';

  /// Jumlah karakter data (45 bit / 5 bit per karakter).
  static const int dataChars = 9;

  /// Panjang kode tanpa awalan & tanda hubung: 9 data + 1 karakter cek.
  static const int rawLength = dataChars + 1;

  /// Nilai SSAID cacat yang terkenal: sejumlah perangkat lama (dan beberapa
  /// emulator) mengembalikan konstanta ini untuk SEMUA aplikasi, sehingga ia
  /// sama sekali tidak membedakan perangkat.
  static const String brokenSsaid = '9774d56d682e549c';

  /// `true` bila [ssaid] tidak bisa dipakai sebagai sumber kode perangkat.
  static bool isUnusableSsaid(String? ssaid) {
    if (ssaid == null) return true;
    final trimmed = ssaid.trim().toLowerCase();
    if (trimmed.isEmpty) return true;
    if (trimmed == brokenSsaid) return true;
    // Sebagian perangkat mengembalikan nol semua saat SSAID belum siap.
    if (RegExp(r'^0+$').hasMatch(trimmed)) return true;
    return false;
  }

  /// SSAID (atau pengenal cadangan) → 10 karakter kode perangkat TANPA
  /// awalan & tanda hubung. Ini bentuk yang ikut ditandatangani (§6.3.D).
  static String fromSeed(String seed) {
    final digest = sha256.convert('$hashPrefix$seed'.codeUnits).bytes;
    // 6 byte pertama = 48 bit; buang 3 bit terbawah supaya tersisa 45 bit
    // yang pas untuk 9 karakter Crockford Base32.
    var value = 0;
    for (var i = 0; i < 6; i++) {
      value = (value << 8) | digest[i];
    }
    value >>= 3;
    final data = CrockfordBase32.encodeInt(value, dataChars);
    return '$data${checkChar(data)}';
  }

  /// Karakter cek berbobot posisi.
  ///
  /// Bobotnya ganjil dan naik dua-dua (1, 3, 5, …). Konsekuensi yang
  /// diinginkan: **setiap** salah ketik satu karakter pasti tertangkap
  /// (bobot ganjil × selisih ≠ 0 mod 32 selama selisihnya bukan nol), dan
  /// tertukarnya dua karakter bersebelahan tertangkap kecuali bila kedua
  /// karakter itu kebetulan berselisih tepat 16 pada alfabet — batas
  /// matematis skema linier modulo 32, dan sisa risikonya ditutup oleh
  /// verifikasi tanda tangan di sisi penjual (`--verifikasi`).
  static String checkChar(String data) {
    var sum = 0;
    for (var i = 0; i < data.length; i++) {
      final value = CrockfordBase32.decodeChar(data[i]);
      if (value == null) {
        throw FormatException(
          'Karakter "${data[i]}" bukan alfabet kode.',
          data,
          i,
        );
      }
      sum += value * (2 * i + 1);
    }
    // Bobot karakter cek sendiri (19 untuk 9 karakter data) ikut ganjil,
    // sehingga salah ketik pada karakter cek pun tertangkap.
    final checkWeight = 2 * data.length + 1;
    // Cari c sehingga (sum + c*checkWeight) % 32 == 0. checkWeight ganjil →
    // punya invers modulo 32, jadi solusinya selalu ada dan tunggal.
    final inverse = _inverseMod32(checkWeight);
    final c = ((32 - (sum % 32)) % 32) * inverse % 32;
    return CrockfordBase32.alphabet[c];
  }

  static int _inverseMod32(int value) {
    for (var i = 1; i < 32; i += 2) {
      if ((value * i) % 32 == 1) return i;
    }
    throw StateError('Bobot karakter cek wajib ganjil.');
  }

  /// `true` bila 10 karakter [raw] konsisten dengan karakter ceknya.
  static bool isValidRaw(String raw) {
    if (raw.length != rawLength) return false;
    if (!CrockfordBase32.isValidNormalized(raw)) return false;
    return checkChar(raw.substring(0, dataChars)) == raw[dataChars];
  }

  /// Terima bentuk apa pun yang diketik penjual (`KW-4T7QP-9M2XK`,
  /// `kw4t7qp9m2xk`, dengan/ tanpa spasi) → 10 karakter mentah, atau `null`
  /// bila panjang/karakter ceknya tidak sah.
  static String? tryParse(String input) {
    var normalized = CrockfordBase32.normalize(input);
    // Awalan "KW" ikut dinormalkan jadi bagian teks; buang bila ada.
    if (normalized.length == rawLength + 2 && normalized.startsWith('KW')) {
      normalized = normalized.substring(2);
    }
    if (!isValidRaw(normalized)) return null;
    return normalized;
  }

  /// 10 karakter mentah → bentuk tampil `KW-XXXXX-XXXXX`.
  static String format(String raw) =>
      '$displayPrefix${raw.substring(0, 5)}-${raw.substring(5)}';

  /// 16 bit pertama SHA-256 kode perangkat — "petunjuk perangkat" di muatan
  /// (§6.3.D byte 7–8).
  ///
  /// Petunjuk ini **bukan** pengaman: pengamannya adalah kode perangkat yang
  /// ikut ditandatangani. Gunanya semata-mata agar aplikasi bisa berkata
  /// "kode ini diterbitkan untuk perangkat lain" alih-alih "kode tidak sah".
  static int hint(String raw) {
    final digest = sha256.convert(raw.codeUnits).bytes;
    return (digest[0] << 8) | digest[1];
  }
}
