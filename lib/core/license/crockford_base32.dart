import 'dart:typed_data';

/// Crockford Base32 — alfabet tanpa karakter kembar (PRD v1.1 §6.3.D).
///
/// Alfabetnya membuang `I`, `L`, `O`, dan `U`: tiga yang pertama karena
/// mudah tertukar dengan `1`/`0` di layar retak maupun tulisan tangan, yang
/// terakhir supaya kode acak tidak pernah membentuk kata yang tidak pantas.
///
/// Saat MEMBACA masukan pengguna, encoder ini sengaja jauh lebih pemaaf
/// daripada saat MENULIS: huruf kecil dinaikkan, `I`/`l` diterima sebagai
/// `1`, `O` sebagai `0`, dan seluruh tanda hubung/spasi diabaikan (AC-6.9).
/// Pemaaf di sini bukan kelonggaran keamanan — tanda tangan tetap yang
/// memutuskan sah/tidak; ini semata-mata menghapus satu kelas keluhan
/// "kode saya ditolak padahal sudah benar".
///
/// **Murni Dart**: berkas ini (dan seluruh `lib/core/license/`) tidak boleh
/// mengimpor `package:flutter/*` supaya `tool/license_generator.dart` bisa
/// memakai jalur kode yang sama persis dengan aplikasi (K-6.12).
abstract final class CrockfordBase32 {
  /// 32 karakter: 0-9 lalu A-Z tanpa `I`, `L`, `O`, `U`.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// Naikkan huruf, buang pemisah, dan satukan karakter kembar.
  ///
  /// Tidak memvalidasi apa pun — karakter asing dibiarkan lewat supaya
  /// [decode]/[decodeChar] yang memberi pesan kesalahannya.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.toUpperCase().runes) {
      final ch = String.fromCharCode(rune);
      switch (ch) {
        case '-':
        case ' ':
        case '\t':
        case '\n':
        case '\r':
        case '_':
        case '.':
          continue;
        case 'I':
        case 'L':
          buffer.write('1');
        case 'O':
          buffer.write('0');
        default:
          buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// Nilai 0..31 sebuah karakter yang SUDAH dinormalkan, atau `null` bila
  /// karakter itu bukan anggota alfabet.
  static int? decodeChar(String ch) {
    final index = alphabet.indexOf(ch);
    return index < 0 ? null : index;
  }

  /// `true` bila seluruh karakter [normalized] ada di dalam alfabet.
  static bool isValidNormalized(String normalized) {
    for (var i = 0; i < normalized.length; i++) {
      if (decodeChar(normalized[i]) == null) return false;
    }
    return true;
  }

  /// Byte → teks, bit dikemas dari yang paling berarti (MSB-first).
  ///
  /// Panjang keluaran dibulatkan ke atas; sisa bit di karakter terakhir
  /// diisi nol. Untuk 75 byte (600 bit) hasilnya pas 120 karakter tanpa
  /// bit sisa sama sekali.
  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xFF);
      bits += 8;
      while (bits >= 5) {
        out.write(alphabet[(buffer >> (bits - 5)) & 0x1F]);
        bits -= 5;
      }
    }
    if (bits > 0) {
      out.write(alphabet[(buffer << (5 - bits)) & 0x1F]);
    }
    return out.toString();
  }

  /// Teks (mentah atau sudah dinormalkan) → byte.
  ///
  /// Melempar [FormatException] bila ada karakter di luar alfabet atau
  /// jumlah bitnya bukan kelipatan 8.
  static Uint8List decode(String text) {
    final normalized = normalize(text);
    final out = BytesBuilder(copy: false);
    var buffer = 0;
    var bits = 0;
    for (var i = 0; i < normalized.length; i++) {
      final value = decodeChar(normalized[i]);
      if (value == null) {
        throw FormatException(
          'Karakter "${normalized[i]}" bukan bagian dari alfabet kode.',
          normalized,
          i,
        );
      }
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        out.addByte((buffer >> (bits - 8)) & 0xFF);
        bits -= 8;
      }
    }
    // Bit sisa WAJIB nol: kalau tidak, teksnya bukan hasil [encode] yang sah.
    if (bits > 0 && (buffer & ((1 << bits) - 1)) != 0) {
      throw FormatException('Panjang kode tidak pas.', normalized);
    }
    return out.takeBytes();
  }

  /// Bilangan bulat [value] sepanjang [chars] karakter (5 bit per karakter),
  /// MSB-first. Dipakai kode perangkat (45 bit → 9 karakter).
  static String encodeInt(int value, int chars) {
    final out = StringBuffer();
    for (var i = chars - 1; i >= 0; i--) {
      out.write(alphabet[(value >> (5 * i)) & 0x1F]);
    }
    return out.toString();
  }

  /// Pisah [text] menjadi kelompok berisi [size] karakter, dipisah `-`.
  ///
  /// Kode 120 karakter tanpa pengelompokan mustahil dilacak mata saat
  /// diketik ulang; kelompok lima adalah panjang yang masih bisa diingat
  /// sekali lihat.
  static String group(String text, {int size = 5, String separator = '-'}) {
    if (text.isEmpty) return text;
    final parts = <String>[];
    for (var i = 0; i < text.length; i += size) {
      parts.add(
        text.substring(i, i + size > text.length ? text.length : i + size),
      );
    }
    return parts.join(separator);
  }
}
