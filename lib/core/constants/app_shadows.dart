import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Token elevasi berbasis **shadow lembut bernada hangat**.
///
/// Aturan design language "Kertas & Daun":
/// - Tidak ada shadow keras/abu-abu murni. Semua shadow memakai
///   [AppColors.shadowBase] (cokelat hangat) dengan opacity rendah supaya
///   menyatu dengan kanvas kertas.
/// - Kedalaman dibangun dari **dua lapis**: satu shadow rapat (ambient) dan
///   satu shadow lebar (key light) — ini yang membuat kartu terasa "empuk"
///   bukan "ditempel".
/// - Kartu di dalam list cukup [level0] + garis [AppColors.border];
///   shadow hanya untuk elemen yang benar-benar mengambang.
abstract final class AppShadows {
  /// Datar — kartu di dalam list panjang, tile produk. Andalkan border.
  static const List<BoxShadow> level0 = <BoxShadow>[];

  /// Angkat halus — kartu ringkasan, kartu yang bisa ditekan.
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0A3B2E1F),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F3B2E1F),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Mengambang — dock navigasi, bar keranjang, kartu hero.
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x0D3B2E1F),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x1A3B2E1F),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Modal — dialog, bottom sheet, menu.
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x143B2E1F),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x243B2E1F),
      blurRadius: 40,
      offset: Offset(0, 16),
    ),
  ];

  /// Glow brand — dipakai HANYA di bawah CTA utama (tombol Bayar) untuk
  /// menariknya keluar dari halaman. Jangan dipakai di elemen lain.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x330D5D42),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}
