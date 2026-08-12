import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Palet warna **sadar-konteks** aplikasi Kasir Warung (PRD v1.1 §5.5,
/// keputusan K-5.1).
///
/// Masalah yang dipecahkan: [AppColors] berisi `static const Color`, dan
/// nilai `const` tidak bisa berubah menurut tema. [AppPalette] memindahkan
/// seluruh token yang sama menjadi **field instance** pada sebuah
/// [ThemeExtension], sehingga satu token (`primary`, `ink`, `successSoft`,
/// …) punya dua nilai — terang & gelap — dan widget yang membacanya lewat
/// `context.palette` otomatis ikut berubah saat tema berganti.
///
/// ```dart
/// final p = context.palette;
/// Container(color: p.surface, child: Text('Rp10.000', style: TextStyle(color: p.ink)));
/// ```
///
/// Dua konstruktor:
/// - [AppPalette.light] — nilai **persis sama** dengan [AppColors] v1.0,
///   supaya tidak ada satu piksel pun yang berubah di mode terang (AC-5.12).
/// - [AppPalette.dark] — palet **"Kertas & Daun Malam"** (PRD §5.4): bukan
///   pembalikan warna, tapi pemindahan metafora — kertas di bawah lampu
///   malam. Tidak ada hitam murni, kedalaman datang dari tangga permukaan
///   (`background < surface < surfaceAlt`) bukan dari shadow, dan warna
///   brand dibalik perannya (hijau terang + tinta gelap di atasnya).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceDark,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.onDark,
    required this.border,
    required this.borderStrong,
    required this.scrim,
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.primary200,
    required this.primary100,
    required this.primary50,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.accent100,
    required this.accent50,
    required this.success,
    required this.successSoft,
    required this.successText,
    required this.warning,
    required this.warningSoft,
    required this.warningText,
    required this.danger,
    required this.dangerSoft,
    required this.dangerText,
    required this.dangerBorder,
    required this.info,
    required this.infoSoft,
    required this.infoText,
    required this.infoBorder,
    required this.shadowBase,
  });

  /// Palet terang — **sumber nilainya tetap [AppColors]** supaya mode terang
  /// tidak berubah sedikit pun dibanding v1.0 (AC-5.12).
  const AppPalette.light()
    : brightness = Brightness.light,
      background = AppColors.background,
      surface = AppColors.surface,
      surfaceAlt = AppColors.surfaceAlt,
      surfaceDark = AppColors.surfaceDark,
      ink = AppColors.ink,
      inkSecondary = AppColors.inkSecondary,
      inkTertiary = AppColors.inkTertiary,
      onDark = AppColors.onDark,
      border = AppColors.border,
      borderStrong = AppColors.borderStrong,
      scrim = AppColors.scrim,
      primary = AppColors.primary,
      onPrimary = AppColors.onDark,
      primaryDark = AppColors.primaryDark,
      primaryDeep = AppColors.primaryDeep,
      primary200 = AppColors.primary200,
      primary100 = AppColors.primary100,
      primary50 = AppColors.primary50,
      accent = AppColors.accent,
      onAccent = AppColors.ink,
      accentText = AppColors.accentText,
      accent100 = AppColors.accent100,
      accent50 = AppColors.accent50,
      success = AppColors.success,
      successSoft = AppColors.successSoft,
      successText = AppColors.successText,
      warning = AppColors.warning,
      warningSoft = AppColors.warningSoft,
      warningText = AppColors.warningText,
      danger = AppColors.danger,
      dangerSoft = AppColors.dangerSoft,
      dangerText = AppColors.dangerText,
      dangerBorder = const Color(0xFFF3C9C5),
      info = AppColors.info,
      infoSoft = AppColors.infoSoft,
      infoText = AppColors.infoText,
      infoBorder = const Color(0xFFC3DAEA),
      shadowBase = AppColors.shadowBase;

  /// Palet gelap **"Kertas & Daun Malam"** (PRD §5.4).
  ///
  /// Nilai diverifikasi otomatis oleh uji kontras
  /// (`test/core/constants/app_palette_contrast_test.dart`, AC-5.8) — bukan
  /// dinilai dengan mata.
  const AppPalette.dark()
    : brightness = Brightness.dark,
      background = const Color(0xFF141613),
      surface = const Color(0xFF1C1F1B),
      surfaceAlt = const Color(0xFF232722),
      // Permukaan INVERSI (SnackBar/tooltip) — di mode gelap justru terang.
      surfaceDark = const Color(0xFFEDEAE1),
      ink = const Color(0xFFEDEAE0),
      inkSecondary = const Color(0xFFA7ADA4),
      inkTertiary = const Color(0xFF7A8078),
      // Teks di atas permukaan hijau TUA (primaryDeep) — tetap terang.
      onDark = const Color(0xFFF6F8F5),
      border = const Color(0xFF2E332C),
      borderStrong = const Color(0xFF3D433B),
      scrim = const Color(0x99000000),
      // Hijau daun TERANG: hijau tua #0D5D42 tidak terbaca di atas latar
      // gelap. Teks di atasnya jadi gelap (#06281B), bukan putih — pola
      // standar Material 3 yang menjaga kontras >= 4.5:1.
      primary = const Color(0xFF74CFA4),
      onPrimary = const Color(0xFF06281B),
      primaryDark = const Color(0xFF5FBB90),
      primaryDeep = const Color(0xFF0E3A2A),
      primary200 = const Color(0xFF3E7C61),
      primary100 = const Color(0xFF2A5C46),
      primary50 = const Color(0xFF123128),
      accent = const Color(0xFFE9A25A),
      onAccent = const Color(0xFF2A1A06),
      accentText = const Color(0xFFEDB279),
      accent100 = const Color(0xFF4A3316),
      accent50 = const Color(0xFF33240F),
      success = const Color(0xFF5FC98F),
      successSoft = const Color(0xFF12291D),
      successText = const Color(0xFF8FE0B4),
      warning = const Color(0xFFD9A441),
      warningSoft = const Color(0xFF31260D),
      warningText = const Color(0xFFF0C475),
      danger = const Color(0xFFE0645B),
      dangerSoft = const Color(0xFF3A1512),
      dangerText = const Color(0xFFF2B4AE),
      dangerBorder = const Color(0xFF5C2621),
      info = const Color(0xFF5AA7DA),
      infoSoft = const Color(0xFF0F2836),
      infoText = const Color(0xFF8FC7E8),
      infoBorder = const Color(0xFF1E4A66),
      // Di mode gelap shadow praktis tak terlihat; dasarnya hitam murni
      // supaya yang sedikit terlihat tidak "mengabu".
      shadowBase = const Color(0xFF000000);

  /// Terang/gelap — dipakai widget yang perlu memutuskan perilaku, bukan
  /// sekadar warna (mis. alpha shadow, gambar, `SystemUiOverlayStyle`).
  final Brightness brightness;

  // ---------------------------------------------------------------------
  // NETRAL — kertas & tinta.
  // ---------------------------------------------------------------------

  /// Kanvas layar (Scaffold).
  final Color background;

  /// Kartu, sheet, dialog, dock nav.
  final Color surface;

  /// Sub-panel, baris zebra, field non-aktif.
  final Color surfaceAlt;

  /// Permukaan **inversi** (SnackBar/tooltip): gelap di tema terang, terang
  /// di tema gelap. Teks di atasnya = [onSurfaceDark].
  final Color surfaceDark;

  /// Teks utama & ikon penting.
  final Color ink;

  /// Teks sekunder (label, keterangan). Wajib tetap >= 4.5:1.
  final Color inkSecondary;

  /// Teks tersier — HANYA hint/placeholder & teks >= 18px.
  final Color inkTertiary;

  /// Teks/ikon di atas permukaan hijau TUA ([primaryDeep]) — terang di
  /// kedua tema.
  final Color onDark;

  /// Garis kartu & divider.
  final Color border;

  /// Outline field input & tombol outlined.
  final Color borderStrong;

  /// Barrier dialog / bottom sheet.
  final Color scrim;

  // ---------------------------------------------------------------------
  // BRAND & AKSEN.
  // ---------------------------------------------------------------------

  /// Warna aksi utama. Hijau tua di terang, hijau terang di gelap.
  final Color primary;

  /// Teks/ikon di atas [primary]. **Selalu pakai ini**, jangan
  /// `Colors.white` — di mode gelap teksnya justru gelap.
  final Color onPrimary;

  /// Status pressed/hover tombol utama.
  final Color primaryDark;

  /// Permukaan brand pekat (panel total, header khusus) — gelap di kedua
  /// tema; teks di atasnya [onDark].
  final Color primaryDeep;

  /// Border kartu terpilih.
  final Color primary200;

  /// Track progress, border tonal.
  final Color primary100;

  /// Latar lembut brand (chip aktif, kapsul nav aktif).
  final Color primary50;

  /// Isi penanda aksen (gula aren). Teks di atasnya [onAccent].
  final Color accent;

  /// Teks/ikon di atas [accent].
  final Color onAccent;

  /// Teks/ikon aksen di atas latar biasa.
  final Color accentText;

  /// Border tonal aksen.
  final Color accent100;

  /// Latar lembut aksen (badge "Hutang").
  final Color accent50;

  // ---------------------------------------------------------------------
  // SEMANTIK — trio isi / soft / text per status.
  // ---------------------------------------------------------------------

  final Color success;
  final Color successSoft;
  final Color successText;

  final Color warning;
  final Color warningSoft;
  final Color warningText;

  final Color danger;
  final Color dangerSoft;
  final Color dangerText;

  /// Garis tepi latar lembut [dangerSoft].
  final Color dangerBorder;

  final Color info;
  final Color infoSoft;
  final Color infoText;

  /// Garis tepi latar lembut [infoSoft].
  final Color infoBorder;

  /// Warna dasar shadow.
  final Color shadowBase;

  // ---------------------------------------------------------------------
  // TURUNAN & ALIAS DOMAIN — makna tetap sama seperti v1.0.
  // ---------------------------------------------------------------------

  /// Teks/ikon di atas [surfaceDark] (permukaan inversi).
  ///
  /// Ikut terbalik: di tema terang permukaannya gelap sehingga teksnya
  /// terang, di tema gelap permukaannya justru terang sehingga teksnya
  /// gelap. Memakai [ink] di sini adalah bug klasik — di tema gelap [ink]
  /// juga terang, jadi SnackBar-nya jadi terang-di-atas-terang.
  Color get onSurfaceDark =>
      brightness == Brightness.light ? onDark : const Color(0xFF1B211D);

  /// Pembayaran tunai.
  Color get tunai => success;

  /// Pembayaran non-tunai (QRIS/transfer).
  Color get nonTunai => info;

  /// Hutang / bon belum lunas.
  Color get hutang => accentText;

  /// Alias lama — latar lembut brand.
  Color get primaryLight => primary50;

  /// Alias lama.
  Color get textPrimary => ink;
  Color get textSecondary => inkSecondary;
  Color get secondary => accent;

  bool get isDark => brightness == Brightness.dark;

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceDark,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? onDark,
    Color? border,
    Color? borderStrong,
    Color? scrim,
    Color? primary,
    Color? onPrimary,
    Color? primaryDark,
    Color? primaryDeep,
    Color? primary200,
    Color? primary100,
    Color? primary50,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? accent100,
    Color? accent50,
    Color? success,
    Color? successSoft,
    Color? successText,
    Color? warning,
    Color? warningSoft,
    Color? warningText,
    Color? danger,
    Color? dangerSoft,
    Color? dangerText,
    Color? dangerBorder,
    Color? info,
    Color? infoSoft,
    Color? infoText,
    Color? infoBorder,
    Color? shadowBase,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceDark: surfaceDark ?? this.surfaceDark,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      onDark: onDark ?? this.onDark,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      scrim: scrim ?? this.scrim,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      primary200: primary200 ?? this.primary200,
      primary100: primary100 ?? this.primary100,
      primary50: primary50 ?? this.primary50,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      accent100: accent100 ?? this.accent100,
      accent50: accent50 ?? this.accent50,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      successText: successText ?? this.successText,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      warningText: warningText ?? this.warningText,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerText: dangerText ?? this.dangerText,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      infoText: infoText ?? this.infoText,
      infoBorder: infoBorder ?? this.infoBorder,
      shadowBase: shadowBase ?? this.shadowBase,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      surfaceDark: c(surfaceDark, other.surfaceDark),
      ink: c(ink, other.ink),
      inkSecondary: c(inkSecondary, other.inkSecondary),
      inkTertiary: c(inkTertiary, other.inkTertiary),
      onDark: c(onDark, other.onDark),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      scrim: c(scrim, other.scrim),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryDark: c(primaryDark, other.primaryDark),
      primaryDeep: c(primaryDeep, other.primaryDeep),
      primary200: c(primary200, other.primary200),
      primary100: c(primary100, other.primary100),
      primary50: c(primary50, other.primary50),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentText: c(accentText, other.accentText),
      accent100: c(accent100, other.accent100),
      accent50: c(accent50, other.accent50),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      successText: c(successText, other.successText),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      warningText: c(warningText, other.warningText),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      dangerText: c(dangerText, other.dangerText),
      dangerBorder: c(dangerBorder, other.dangerBorder),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
      infoText: c(infoText, other.infoText),
      infoBorder: c(infoBorder, other.infoBorder),
      shadowBase: c(shadowBase, other.shadowBase),
    );
  }
}

/// Akses palet dari mana saja: `context.palette.ink`.
///
/// Sengaja dibuat **sependek mungkin** — migrasi ratusan pemakaian
/// `AppColors.*` tidak boleh menyakitkan (PRD §5.5).
///
/// Fallback ke [AppPalette.light] bila ekstensi belum terpasang (mis. widget
/// diuji dengan `ThemeData()` polos), supaya tidak pernah crash.
extension AppPaletteContextX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? const AppPalette.light();
}

/// Resolver trio warna [AppTone] yang **sadar tema** (PRD §5.5).
///
/// Menggantikan getter lama `tone.colors` yang selalu mengembalikan palet
/// terang:
///
/// ```dart
/// final c = tone.colorsOf(context);   // c.fg, c.bg, c.border
/// ```
extension AppToneColorsContextX on AppTone {
  AppToneColors colorsOf(BuildContext context) => resolve(context.palette);

  /// Versi tanpa [BuildContext] — dipakai kode yang sudah memegang palet
  /// (mis. builder dekorasi & uji kontras).
  AppToneColors resolve(AppPalette p) => switch (this) {
    AppTone.neutral => AppToneColors(
      fg: p.inkSecondary,
      bg: p.surfaceAlt,
      border: p.border,
    ),
    AppTone.primary => AppToneColors(
      fg: p.primary,
      bg: p.primary50,
      border: p.primary100,
    ),
    AppTone.accent => AppToneColors(
      fg: p.accentText,
      bg: p.accent50,
      border: p.accent100,
    ),
    AppTone.success => AppToneColors(
      fg: p.successText,
      bg: p.successSoft,
      border: p.primary100,
    ),
    AppTone.warning => AppToneColors(
      fg: p.warningText,
      bg: p.warningSoft,
      border: p.accent100,
    ),
    AppTone.danger => AppToneColors(
      fg: p.dangerText,
      bg: p.dangerSoft,
      border: p.dangerBorder,
    ),
    AppTone.info => AppToneColors(
      fg: p.infoText,
      bg: p.infoSoft,
      border: p.infoBorder,
    ),
  };

  /// Warna **isi pekat** nada ini (dipakai ikon/indikator solid, bukan latar
  /// lembut). Sadar tema.
  Color fillOf(BuildContext context) {
    final p = context.palette;
    return switch (this) {
      AppTone.neutral => p.inkSecondary,
      AppTone.primary => p.primary,
      AppTone.accent => p.accent,
      AppTone.success => p.success,
      AppTone.warning => p.warning,
      AppTone.danger => p.danger,
      AppTone.info => p.info,
    };
  }
}
