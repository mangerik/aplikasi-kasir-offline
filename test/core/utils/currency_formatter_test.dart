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
}
