import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.format', () {
    test('memformat ribuan dengan pemisah titik dan prefix Rp', () {
      expect(CurrencyFormatter.format(12345), 'Rp12.345');
    });

    test('memformat jutaan', () {
      expect(CurrencyFormatter.format(1250000), 'Rp1.250.000');
    });

    test('memformat nol', () {
      expect(CurrencyFormatter.format(0), 'Rp0');
    });

    test('memformat angka kecil tanpa pemisah', () {
      expect(CurrencyFormatter.format(500), 'Rp500');
    });

    test('memformat nilai negatif dengan prefix minus sebelum Rp', () {
      expect(CurrencyFormatter.format(-5000), '-Rp5.000');
    });

    test('membulatkan nilai desimal', () {
      expect(CurrencyFormatter.format(12345.6), 'Rp12.346');
    });
  });

  group('CurrencyFormatter.formatNumber', () {
    test('memformat tanpa prefix Rp', () {
      expect(CurrencyFormatter.formatNumber(12345), '12.345');
    });
  });

  group('CurrencyFormatter.parse', () {
    test('parse string berformat Rp12.345 menjadi 12345', () {
      expect(CurrencyFormatter.parse('Rp12.345'), 12345);
    });

    test('parse string angka polos dengan pemisah titik', () {
      expect(CurrencyFormatter.parse('12.345'), 12345);
    });

    test('parse string kosong menjadi 0', () {
      expect(CurrencyFormatter.parse(''), 0);
    });

    test('parse string tidak valid menjadi 0', () {
      expect(CurrencyFormatter.parse('abc'), 0);
    });
  });

  /// Format ringkas label sumbu Y grafik (M14, PRD v1.1 §9.6).
  ///
  /// Ini satu-satunya tempat aplikasi menampilkan uang secara TIDAK persis,
  /// jadi aturannya harus terkunci: singkatan Bahasa Indonesia, koma
  /// desimal, dan tidak boleh ada bentuk aneh seperti "Rp1000rb".
  group('CurrencyFormatter.formatCompact', () {
    test('di bawah seribu ditampilkan utuh', () {
      expect(CurrencyFormatter.formatCompact(0), 'Rp0');
      expect(CurrencyFormatter.formatCompact(999), 'Rp999');
    });

    test('ribuan memakai singkatan "rb" dengan koma desimal', () {
      expect(CurrencyFormatter.formatCompact(1000), 'Rp1rb');
      expect(CurrencyFormatter.formatCompact(1500), 'Rp1,5rb');
      expect(CurrencyFormatter.formatCompact(45000), 'Rp45rb');
      expect(CurrencyFormatter.formatCompact(450500), 'Rp451rb');
    });

    test('jutaan & miliaran', () {
      expect(CurrencyFormatter.formatCompact(1240000), 'Rp1,2jt');
      expect(CurrencyFormatter.formatCompact(12000000), 'Rp12jt');
      expect(CurrencyFormatter.formatCompact(3400000000), 'Rp3,4m');
    });

    test('nilai tepat di bawah batas satuan dinaikkan, bukan jadi "1000rb"',
        () {
      expect(CurrencyFormatter.formatCompact(999999), 'Rp1jt');
      expect(CurrencyFormatter.formatCompact(999999999), 'Rp1m');
    });

    test('nilai negatif tetap terbaca sebagai negatif', () {
      expect(CurrencyFormatter.formatCompact(-1500000), '-Rp1,5jt');
    });
  });
}
