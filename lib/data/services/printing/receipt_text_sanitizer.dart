/// Sanitasi teks struk ke **ASCII murni** sebelum byte ESC/POS dibentuk
/// (PRD v1.1 K-3.7, AC-3.4).
///
/// Printer thermal 58mm kelas warung memakai codepage **CP437**. Bahasa
/// Indonesia sendiri murni ASCII, jadi masalahnya bukan bahasa melainkan
/// **karakter yang menyelinap** dari UI, dari data yang diketik pengguna
/// (nama produk hasil salin-tempel), dan — yang paling licik — dari
/// `intl`: `NumberFormat` locale `id_ID` bisa menghasilkan **spasi
/// tak-putus** (U+00A0) di antara angka. Karakter itu tidak tampak beda
/// sama sekali di layar, tapi tercetak sebagai sampah di kertas.
///
/// Karena itu sanitasi di sini **tidak boleh** dilewati dan tidak boleh
/// "pintar": aturannya sederhana dan bisa dibaca ulang orang lain —
/// 1. karakter yang punya padanan ASCII wajar dipetakan ([_replacements]),
/// 2. huruf latin beraksen diturunkan ke huruf dasarnya (`é` → `e`),
/// 3. sisanya (emoji, aksara non-latin, simbol eksotis) diganti **spasi**,
///    bukan dibuang — supaya lebar kolom yang sudah dihitung tidak bergeser.
///
/// Murni Dart, tanpa satu pun import — bisa diuji unit penuh tanpa
/// perangkat maupun binding Flutter (K-3.2).
abstract final class ReceiptTextSanitizer {
  /// Batas atas ASCII yang boleh lewat: 0x20 (spasi) sampai 0x7E (`~`).
  static const int _minPrintable = 0x20;
  static const int _maxPrintable = 0x7E;

  /// Padanan aman untuk karakter yang sering muncul di data nyata.
  ///
  /// Sengaja per-karakter (bukan regex) supaya daftarnya bisa dibaca dan
  /// diuji satu-satu.
  static const Map<int, String> _replacements = <int, String>{
    0x00A0: ' ', // NBSP — jebakan utama keluaran `intl` locale id_ID
    0x2007: ' ', // figure space
    0x2009: ' ', // thin space
    0x202F: ' ', // narrow no-break space
    0x200B: '', // zero-width space: benar-benar tak berlebar, boleh dibuang
    0x200C: '',
    0x200D: '',
    0xFEFF: '', // BOM
    0x00D7: 'x', // × — sering dipakai untuk "2 × 3.500"
    0x00F7: '/', // ÷
    0x2013: '-', // – en dash
    0x2014: '-', // — em dash
    0x2212: '-', // − minus matematis
    0x2010: '-',
    0x2011: '-',
    0x2018: "'", // ‘
    0x2019: "'", // ’ — apostrof "cerdas" dari Word/WhatsApp
    0x201A: "'",
    0x201B: "'",
    0x201C: '"', // “
    0x201D: '"', // ”
    0x2026: '...', // …
    0x2022: '*', // •
    0x00B7: '.', // ·
    0x2192: '-', // → (disebut eksplisit di AC-3.4)
    0x2190: '-',
    0x00B0: ' ', // °
    0x00A9: '(c)',
    0x00AE: '(r)',
    0x2122: '(tm)',
    0x20AC: 'EUR',
    0x00A3: 'GBP',
    0x00A5: 'JPY',
    0x00BD: '1/2',
    0x00BC: '1/4',
    0x00BE: '3/4',
  };

  /// Huruf latin beraksen → huruf dasar. Dipakai untuk nama produk/toko
  /// yang memuat kata serapan ("Café", "Crème").
  static const Map<String, String> _accentFolding = <String, String>{
    'àáâãäåāăą': 'a',
    'ÀÁÂÃÄÅĀĂĄ': 'A',
    'çćĉċč': 'c',
    'ÇĆĈĊČ': 'C',
    'ďđ': 'd',
    'ĎĐ': 'D',
    'èéêëēĕėęě': 'e',
    'ÈÉÊËĒĔĖĘĚ': 'E',
    'ĝğġģ': 'g',
    'ĜĞĠĢ': 'G',
    'ìíîïĩīĭįı': 'i',
    'ÌÍÎÏĨĪĬĮİ': 'I',
    'ñńņňŉ': 'n',
    'ÑŃŅŇ': 'N',
    'òóôõöøōŏő': 'o',
    'ÒÓÔÕÖØŌŎŐ': 'O',
    'ŕŗř': 'r',
    'ŔŖŘ': 'R',
    'śŝşš': 's',
    'ŚŜŞŠ': 'S',
    'ţťŧ': 't',
    'ŢŤŦ': 'T',
    'ùúûüũūŭůűų': 'u',
    'ÙÚÛÜŨŪŬŮŰŲ': 'U',
    'ýÿŷ': 'y',
    'ÝŸŶ': 'Y',
    'źżž': 'z',
    'ŹŻŽ': 'Z',
  };

  static final Map<int, String> _foldingByCodeUnit = _buildFoldingIndex();

  static Map<int, String> _buildFoldingIndex() {
    final index = <int, String>{};
    for (final entry in _accentFolding.entries) {
      for (final unit in entry.key.codeUnits) {
        index[unit] = entry.value;
      }
    }
    return index;
  }

  /// Ubah [input] menjadi teks ASCII yang aman dikirim ke printer.
  ///
  /// Panjang teks BISA berubah (mis. `…` → `...`), karena itu sanitasi
  /// harus dijalankan **sebelum** perataan kolom dihitung — lihat
  /// `EscPosReceiptBuilder`.
  static String sanitize(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      // Baris baru & tab tidak pernah boleh lewat: struk dibentuk baris per
      // baris, dan tab tidak konsisten antar firmware printer (PRD §3.3.D).
      if (unit == 0x0A || unit == 0x0D || unit == 0x09) {
        buffer.write(' ');
        continue;
      }
      if (unit >= _minPrintable && unit <= _maxPrintable) {
        buffer.writeCharCode(unit);
        continue;
      }
      final replacement = _replacements[unit];
      if (replacement != null) {
        buffer.write(replacement);
        continue;
      }
      final folded = _foldingByCodeUnit[unit];
      if (folded != null) {
        buffer.write(folded);
        continue;
      }
      // Sisanya (emoji, aksara non-latin, simbol tak dikenal) → spasi.
      // Diganti, BUKAN dibuang: mengubah panjang teks diam-diam akan
      // menggeser kolom nominal yang sudah dihitung.
      buffer.write(' ');
    }
    return buffer.toString();
  }

  /// `true` bila [text] sudah aman dikirim apa adanya. Dipakai test &
  /// assertion, bukan jalur produksi.
  static bool isPureAscii(String text) {
    for (final unit in text.runes) {
      if (unit < _minPrintable || unit > _maxPrintable) return false;
    }
    return true;
  }

  /// Byte ASCII dari [text] yang SUDAH disanitasi. Aman memakai
  /// `codeUnits` karena seluruh nilainya dijamin ≤ 0x7E.
  static List<int> toBytes(String text) => sanitize(text).codeUnits;
}
