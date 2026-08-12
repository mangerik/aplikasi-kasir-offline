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

  /// Format **ringkas** untuk ruang sempit: `Rp900`, `Rp1,5rb`, `Rp1,2jt`,
  /// `Rp3,4m` (miliar), `Rp2,1t` (triliun).
  ///
  /// Dibuat untuk label sumbu Y grafik (PRD v1.1 §9.6: "Sumbu Y hanya
  /// menampilkan maksimum dan nol") — `Rp12.480.000` memakan sepertiga
  /// lebar layar HP 5 inci dan mendorong area grafik menjadi tidak
  /// terbaca. Nilai persisnya tetap tersedia lewat tap batang (AC-9.8),
  /// jadi tidak ada angka yang hilang, hanya dipindah tempat.
  ///
  /// Singkatannya sengaja Bahasa Indonesia (`rb`/`jt`/`m`/`t`), bukan
  /// `K`/`M`/`B` — pemilik warung membaca "1,2jt", bukan "1.2M".
  static String formatCompact(num amount) {
    final value = amount.round();
    final sign = value < 0 ? '-' : '';
    var magnitude = value.abs().toDouble();

    const units = ['', 'rb', 'jt', 'm', 't'];
    var unit = 0;
    // Pembulatan diperiksa SEBELUM naik satuan supaya 999.999 tidak
    // ditampilkan sebagai "Rp1000rb" melainkan "Rp1jt".
    while (unit < units.length - 1 && _roundTo1(magnitude) >= 1000) {
      magnitude /= 1000;
      unit++;
    }

    final digits = unit == 0
        ? magnitude.round().toString()
        : _compactDigits(magnitude);
    return '${sign}Rp$digits${units[unit]}';
  }

  static double _roundTo1(double value) => (value * 10).round() / 10;

  /// ≥100 → bulat (`120jt`); di bawah itu satu desimal koma (`1,2jt`),
  /// dan desimal nol dibuang (`5jt`, bukan `5,0jt`).
  static String _compactDigits(double value) {
    final rounded = _roundTo1(value);
    if (rounded >= 100) return rounded.round().toString();
    if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
    return rounded.toStringAsFixed(1).replaceAll('.', ',');
  }

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
