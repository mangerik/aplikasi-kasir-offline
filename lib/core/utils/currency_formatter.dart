import 'package:intl/intl.dart';

/// Formatter mata uang Rupiah.
///
/// Sesuai PRD §3.1.F & §8: uang hanya Rupiah, tanpa desimal, format
/// tampilan `Rp12.345` (pemisah ribuan titik, tanpa spasi setelah "Rp").
abstract final class CurrencyFormatter {
  static final NumberFormat _decimalFormat = NumberFormat.decimalPattern('id_ID');

  /// Format nilai rupiah (integer, tanpa desimal) menjadi `Rp12.345`.
  ///
  /// Nilai negatif ditampilkan sebagai `-Rp12.345`.
  static String format(num amount) {
    final rounded = amount.round();
    final isNegative = rounded < 0;
    final digits = _decimalFormat.format(rounded.abs());
    return '${isNegative ? '-' : ''}Rp$digits';
  }

  /// Format tanpa prefix "Rp", contoh `12.345`.
  static String formatNumber(num amount) => _decimalFormat.format(amount.round());

  /// Parse string hasil input pengguna (mis. dari TextField) menjadi angka.
  ///
  /// Menerima format dengan atau tanpa prefix `Rp` dan pemisah ribuan `.`.
  /// Mengembalikan `0` jika input tidak valid/kosong.
  static int parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9-]'), '');
    if (cleaned.isEmpty) return 0;
    return int.tryParse(cleaned) ?? 0;
  }
}
