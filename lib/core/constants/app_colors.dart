import 'package:flutter/material.dart';

/// Palet warna dasar aplikasi Kasir Warung.
///
/// Warna dipilih agar kontras tinggi dan mudah dibaca di layar kecil
/// dengan pencahayaan beragam (dalam ruangan warung, siang hari, dll).
abstract final class AppColors {
  /// Warna utama (brand) — hijau, identik dengan uang & "aman/lunas".
  static const Color primary = Color(0xFF1B7A43);
  static const Color primaryDark = Color(0xFF0F5A2E);
  static const Color primaryLight = Color(0xFFE3F5EA);

  /// Warna sekunder — oranye, untuk aksen/aksi pelengkap.
  static const Color secondary = Color(0xFFE8720C);

  /// Status/semantik.
  static const Color success = Color(0xFF1B7A43);
  static const Color warning = Color(0xFFB8860B);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  /// Netral.
  static const Color background = Color(0xFFFAFAF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1C19);
  static const Color textSecondary = Color(0xFF52564F);
  static const Color border = Color(0xFFDADCD6);
}
