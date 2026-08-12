import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Token elevasi berbasis **shadow lembut bernada hangat**.
///
/// Aturan design language "Kertas & Daun":
/// - Tidak ada shadow keras/abu-abu murni. Di mode terang semua shadow
///   memakai cokelat hangat `#3B2E1F` dengan opacity rendah supaya menyatu
///   dengan kanvas kertas.
/// - Kedalaman dibangun dari **dua lapis**: satu shadow rapat (ambient) dan
///   satu shadow lebar (key light) — ini yang membuat kartu terasa "empuk"
///   bukan "ditempel".
/// - Kartu di dalam list cukup [level0] + garis `border`; shadow hanya untuk
///   elemen yang benar-benar mengambang.
///
/// **Mode gelap** (PRD v1.1 §5.4 aturan 2): di atas latar gelap shadow
/// praktis tak terlihat, sehingga hierarki dibawa oleh tangga permukaan
/// (`background < surface < surfaceAlt`) plus garis `border`. Varian gelap
/// karena itu memakai alpha jauh lebih rendah dan bersifat **dekoratif saja**
/// — ia hanya melembutkan tepi, bukan membangun kedalaman.
///
/// ```dart
/// final shadows = AppShadows.of(context);  // otomatis terang/gelap
/// BoxDecoration(boxShadow: shadows.level2)
/// ```
abstract final class AppShadows {
  /// Set shadow sesuai tema aktif.
  static AppShadowSet of(BuildContext context) =>
      context.palette.isDark ? dark : light;

  /// Set shadow mode terang (nilai v1.0, tidak berubah).
  static const AppShadowSet light = AppShadowSet(
    level1: _lightLevel1,
    level2: _lightLevel2,
    level3: _lightLevel3,
    primaryGlow: _lightGlow,
  );

  /// Set shadow mode gelap — alpha jauh lebih rendah, dekoratif saja.
  static const AppShadowSet dark = AppShadowSet(
    level1: [
      BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
    level2: [
      BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x2E000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    level3: [
      BoxShadow(color: Color(0x24000000), blurRadius: 6, offset: Offset(0, 2)),
      BoxShadow(
        color: Color(0x3D000000),
        blurRadius: 40,
        offset: Offset(0, 16),
      ),
    ],
    // Glow brand memakai hijau TERANG mode gelap, dengan alpha lebih rendah
    // supaya tidak jadi lampu neon di ruangan gelap.
    primaryGlow: [
      BoxShadow(color: Color(0x2E74CFA4), blurRadius: 20, offset: Offset(0, 8)),
    ],
  );

  /// Datar — kartu di dalam list panjang, tile produk. Andalkan border.
  /// Sama di kedua tema, jadi tetap boleh diakses langsung.
  static const List<BoxShadow> level0 = <BoxShadow>[];

  /// Angkat halus (palet terang). Kode baru pakai `AppShadows.of(context)`.
  @Deprecated('Tidak sadar tema — pakai AppShadows.of(context).level1')
  static const List<BoxShadow> level1 = _lightLevel1;

  /// Mengambang (palet terang). Kode baru pakai `AppShadows.of(context)`.
  @Deprecated('Tidak sadar tema — pakai AppShadows.of(context).level2')
  static const List<BoxShadow> level2 = _lightLevel2;

  /// Modal (palet terang). Kode baru pakai `AppShadows.of(context)`.
  @Deprecated('Tidak sadar tema — pakai AppShadows.of(context).level3')
  static const List<BoxShadow> level3 = _lightLevel3;

  /// Glow brand (palet terang). Kode baru pakai `AppShadows.of(context)`.
  @Deprecated('Tidak sadar tema — pakai AppShadows.of(context).primaryGlow')
  static const List<BoxShadow> primaryGlow = _lightGlow;

  static const List<BoxShadow> _lightLevel1 = [
    BoxShadow(color: Color(0x0A3B2E1F), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F3B2E1F), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> _lightLevel2 = [
    BoxShadow(color: Color(0x0D3B2E1F), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1A3B2E1F), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> _lightLevel3 = [
    BoxShadow(color: Color(0x143B2E1F), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x243B2E1F), blurRadius: 40, offset: Offset(0, 16)),
  ];
  static const List<BoxShadow> _lightGlow = [
    BoxShadow(color: Color(0x330D5D42), blurRadius: 20, offset: Offset(0, 8)),
  ];
}

/// Satu tangga elevasi lengkap untuk sebuah tema.
@immutable
class AppShadowSet {
  const AppShadowSet({
    required this.level1,
    required this.level2,
    required this.level3,
    required this.primaryGlow,
  });

  /// Datar — andalkan border.
  List<BoxShadow> get level0 => const <BoxShadow>[];

  /// Angkat halus — kartu ringkasan, kartu yang bisa ditekan.
  final List<BoxShadow> level1;

  /// Mengambang — dock navigasi, bar keranjang, kartu hero.
  final List<BoxShadow> level2;

  /// Modal — dialog, bottom sheet, menu.
  final List<BoxShadow> level3;

  /// Glow brand — HANYA di bawah CTA utama (tombol Bayar).
  final List<BoxShadow> primaryGlow;
}
