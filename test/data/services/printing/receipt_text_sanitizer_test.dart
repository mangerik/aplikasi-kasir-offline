import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kasir_warung/core/utils/currency_formatter.dart';
import 'package:kasir_warung/data/services/printing/receipt_text_sanitizer.dart';

/// Gerbang K-3.7 / AC-3.4.
///
/// Ini bukan test kosmetik: satu karakter non-ASCII yang lolos ke printer
/// thermal tidak "tampil kurang rapi" — ia keluar sebagai simbol acak, dan
/// pada sebagian firmware klon murah membuat sisa baris ikut kacau.
void main() {
  group('ReceiptTextSanitizer', () {
    test('teks ASCII biasa tidak berubah sama sekali', () {
      const input = 'Indomie Goreng 2 pcs x 3.500 = 7.000 (diskon 10%)';
      expect(ReceiptTextSanitizer.sanitize(input), input);
    });

    test('spasi tak-putus U+00A0 jadi spasi biasa', () {
      expect(ReceiptTextSanitizer.sanitize('Rp 12.000'), 'Rp 12.000');
    });

    test('karakter yang disebut K-3.7 dipetakan ke padanan amannya', () {
      expect(ReceiptTextSanitizer.sanitize('2 × 3'), '2 x 3');
      expect(ReceiptTextSanitizer.sanitize('a – b'), 'a - b');
      expect(ReceiptTextSanitizer.sanitize('a — b'), 'a - b');
      expect(ReceiptTextSanitizer.sanitize('Bu’ Ani'), "Bu' Ani");
    });

    test('panah -> jadi tanda hubung (AC-3.4)', () {
      expect(ReceiptTextSanitizer.sanitize('Stok 5 → 3'), 'Stok 5 - 3');
    });

    test('emoji & aksara non-latin diganti SPASI, bukan dibuang', () {
      // Diganti (bukan dibuang) supaya panjang teks tidak berubah diam-diam
      // dan perataan kolom nominal tetap sesuai perhitungan.
      final result = ReceiptTextSanitizer.sanitize('Teh Botol 中');
      expect(result, 'Teh Botol  ');
      expect(result.length, 'Teh Botol 中'.length);
    });

    test('huruf beraksen diturunkan ke huruf dasar', () {
      expect(ReceiptTextSanitizer.sanitize('Café Crème'), 'Cafe Creme');
    });

    test('baris baru & tab jadi spasi — struk dibentuk baris per baris', () {
      expect(ReceiptTextSanitizer.sanitize('a\nb\tc'), 'a b c');
    });

    test('hasil sanitasi SELALU ASCII murni', () {
      const nasty = 'Ka fé — 2× “spesial” → ✅ 中';
      final clean = ReceiptTextSanitizer.sanitize(nasty);
      expect(ReceiptTextSanitizer.isPureAscii(clean), isTrue);
      expect(ReceiptTextSanitizer.isPureAscii(nasty), isFalse);
    });

    test('byte hasil toBytes semuanya <= 0x7E', () {
      final bytes = ReceiptTextSanitizer.toBytes('Total 14.000 → lunas');
      expect(bytes.every((b) => b >= 0x20 && b <= 0x7E), isTrue);
    });
  });

  group('keluaran intl locale id_ID (jebakan nyata K-3.7)', () {
    test('CurrencyFormatter.formatNumber lolos sanitasi tanpa berubah arti', () {
      for (final value in <int>[0, 1000, 12345, 1500000, -2500]) {
        final formatted = CurrencyFormatter.formatNumber(value);
        final clean = ReceiptTextSanitizer.sanitize(formatted);
        expect(
          ReceiptTextSanitizer.isPureAscii(clean),
          isTrue,
          reason: 'formatNumber($value) = "$formatted" tidak ASCII setelah sanitasi',
        );
        // Digit & pemisah ribuannya tidak boleh ikut hilang.
        expect(clean.replaceAll(RegExp(r'[^0-9]'), ''), value.abs().toString());
      }
    });

    test('CurrencyFormatter.format (dengan prefiks Rp) juga aman', () {
      final clean = ReceiptTextSanitizer.sanitize(CurrencyFormatter.format(1234567));
      expect(ReceiptTextSanitizer.isPureAscii(clean), isTrue);
    });

    test('NumberFormat locale lain yang MEMANG memakai NBSP tetap dijinakkan', () {
      // Bukti bahwa sanitasi memang menangkap kasusnya, bukan kebetulan
      // lolos karena id_ID hari ini tidak memakai NBSP. Locale `fr` memakai
      // spasi tak-putus sebagai pemisah ribuan.
      final french = NumberFormat.decimalPattern('fr').format(1234567);
      final clean = ReceiptTextSanitizer.sanitize(french);
      expect(ReceiptTextSanitizer.isPureAscii(french), isFalse);
      expect(ReceiptTextSanitizer.isPureAscii(clean), isTrue);
      expect(clean.length, french.length);
    });
  });
}
