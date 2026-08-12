import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografi aplikasi — **satu keluarga huruf saja: Plus Jakarta Sans**.
///
/// Kenapa Plus Jakarta Sans: dirancang di Indonesia (Tokotype, awalnya untuk
/// identitas kota Jakarta), bentuk hurufnya geometris-humanis — modern tapi
/// ramah, dan angkanya lebar & jelas (krusial untuk harga di layar kasir).
/// Font di-*bundle* sebagai asset (`assets/fonts/`), BUKAN lewat
/// `google_fonts` yang mengunduh saat runtime — aplikasi ini wajib 100%
/// offline (PRD §1).
///
/// Disiplin pemakaian:
/// - Maksimal **4 ukuran** dan **2 bobot** dalam satu layar.
/// - Hierarki dibangun dari ukuran + bobot + warna, BUKAN dari semuanya
///   di-bold.
abstract final class AppTypography {
  /// Nama family sesuai deklarasi di `pubspec.yaml`.
  static const String fontFamily = 'Plus Jakarta Sans';

  /// Angka dengan lebar seragam — WAJIB untuk kolom harga/qty supaya
  /// digitnya sejajar antar baris dan tidak "goyang" saat berubah.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Skala tipografi lengkap. Semua ukuran dalam logical pixel.
  static TextTheme textTheme() {
    const c = AppColors.ink;
    return const TextTheme(
      // --- Display: angka besar (total belanja, kembalian). Jarang dipakai.
      displayLarge: TextStyle(
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: c,
      ),
      displayMedium: TextStyle(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: c,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: c,
      ),

      // --- Headline: judul hero di dalam konten.
      headlineLarge: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: c,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: c,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: c,
      ),

      // --- Title: judul AppBar, judul kartu, judul item list.
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: c,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: c,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: c,
      ),

      // --- Body: teks isi.
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: c,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: c,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: AppColors.inkSecondary,
      ),

      // --- Label: tombol, chip, nav, eyebrow.
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: c,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: c,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.inkSecondary,
      ),
    ).apply(fontFamily: fontFamily);
  }
}

/// Gaya teks siap pakai di luar skala Material — khusus kebutuhan kasir.
///
/// Pakai ini alih-alih menyusun [TextStyle] manual di layar.
abstract final class AppTextStyles {
  /// Label kecil di atas sebuah nilai/section ("RINGKASAN HARI INI").
  /// Tulis teksnya dalam huruf kapital.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 1,
    color: AppColors.inkSecondary,
  );

  /// Nominal uang di dalam list/kartu (harga produk, subtotal baris).
  static const TextStyle money = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.ink,
    fontFeatures: AppTypography.tabularFigures,
  );

  /// Nominal uang yang jadi fokus utama layar (total belanja, omzet).
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: AppColors.ink,
    fontFeatures: AppTypography.tabularFigures,
  );

  /// Nominal uang paling menonjol (layar sukses / kembalian).
  static const TextStyle moneyHero = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 40,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    color: AppColors.ink,
    fontFeatures: AppTypography.tabularFigures,
  );

  /// Angka non-uang yang perlu sejajar (qty, stok, jumlah transaksi).
  static const TextStyle numeric = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    fontFeatures: AppTypography.tabularFigures,
  );
}
