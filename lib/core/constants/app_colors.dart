import 'package:flutter/material.dart';

/// Palet warna aplikasi Kasir Warung — design language **"Kertas & Daun"**.
///
/// Arah desain: kehangatan warung Indonesia (kertas struk, beras, gula aren)
/// dipadu ketegasan profesional (hijau daun tua yang pekat). BUKAN biru
/// Material default — identitasnya hijau-daun + aksen gula aren di atas
/// kanvas kertas hangat.
///
/// Aturan 60/30/10:
/// - **60%** [background] / [surface] — kanvas kertas hangat.
/// - **30%** [ink] / [inkSecondary] + struktur (border, ikon netral).
/// - **10%** [primary] & [accent] — CTA, indikator, angka penting saja.
///
/// Semua warna teks di sini sudah dicek kontras >= 4.5:1 di atas
/// [background]/[surface] (WCAG AA, PRD §6), kecuali yang ditandai
/// "hanya untuk teks besar / dekoratif".
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // BRAND — Hijau Daun (pandan tua). Dipakai untuk aksi utama & identitas.
  // ---------------------------------------------------------------------

  /// Tint paling terang — latar chip/section terpilih, highlight lembut.
  static const Color primary50 = Color(0xFFE9F2ED);

  /// Tint — latar ikon tonal, badge, indikator nav aktif.
  static const Color primary100 = Color(0xFFCCE3D8);

  /// Border/outline versi brand (mis. kartu terpilih).
  static const Color primary200 = Color(0xFF9AC7AE);

  /// **Warna utama** — tombol utama, ikon aktif, angka uang penting.
  /// Kontras 7.9:1 di atas putih → aman untuk teks & ikon.
  static const Color primary = Color(0xFF0D5D42);

  /// Status pressed/hover tombol utama.
  static const Color primaryDark = Color(0xFF0A4A35);

  /// Permukaan gelap brand (header khusus, panel total, splash).
  static const Color primaryDeep = Color(0xFF063124);

  /// Alias lama (dipakai layar existing) — latar lembut brand.
  static const Color primaryLight = primary50;

  // ---------------------------------------------------------------------
  // AKSEN — Gula Aren (amber-terracotta). Untuk penanda & aksi sekunder.
  // Pakai HEMAT: maksimal 1 elemen aksen menonjol per layar.
  // ---------------------------------------------------------------------

  /// Latar lembut aksen (badge hutang, banner info hangat).
  static const Color accent50 = Color(0xFFFCF0DF);

  static const Color accent100 = Color(0xFFF6DDB9);

  /// **Aksen isi** — FAB sekunder, highlight. Kontras 3.0:1 di atas putih →
  /// JANGAN dipakai sebagai warna teks di atas putih; pakai [accentText].
  /// Teks di ATAS warna ini harus [ink] (kontras 5.5:1), bukan putih.
  static const Color accent = Color(0xFFD97E27);

  /// Versi gelap aksen — aman sebagai warna TEKS/ikon di atas latar terang
  /// (kontras 6.8:1).
  static const Color accentText = Color(0xFF8A4A08);

  /// Alias lama (dipakai layar existing) — sama dengan [accent].
  static const Color secondary = accent;

  // ---------------------------------------------------------------------
  // NETRAL — kertas hangat & tinta.
  // ---------------------------------------------------------------------

  /// Kanvas layar (Scaffold). Kertas hangat, bukan putih steril.
  static const Color background = Color(0xFFF5F2EA);

  /// Permukaan kartu/sheet/AppBar. Putih hangat, sedikit lebih terang dari
  /// [background] supaya kartu "mengambang" tanpa perlu shadow berat.
  static const Color surface = Color(0xFFFFFDFA);

  /// Permukaan alternatif — baris zebra, field non-aktif, latar sub-panel
  /// di dalam kartu.
  static const Color surfaceAlt = Color(0xFFFAF7F0);

  /// Permukaan gelap (panel total, tooltip, snackbar).
  static const Color surfaceDark = Color(0xFF1F2723);

  /// Teks utama & ikon penting. Kontras 15.7:1 di atas [surface].
  static const Color ink = Color(0xFF191D1A);

  /// Teks sekunder (label, keterangan). Kontras 5.6:1 di atas [background].
  static const Color inkSecondary = Color(0xFF5A625C);

  /// Teks tersier — HANYA untuk hint, placeholder, dan teks >= 18px.
  /// Kontras ~3.0:1 → JANGAN untuk teks kecil yang penting.
  static const Color inkTertiary = Color(0xFF8A928B);

  /// Teks/ikon di atas permukaan gelap ([primary], [surfaceDark]).
  static const Color onDark = Color(0xFFF6F8F5);

  /// Alias lama (dipakai layar existing).
  static const Color textPrimary = ink;
  static const Color textSecondary = inkSecondary;

  /// Garis pemisah tipis (divider, outline kartu). Sangat halus.
  static const Color border = Color(0xFFE6E0D4);

  /// Outline lebih tegas — field input, tombol outlined.
  static const Color borderStrong = Color(0xFFD5CDBD);

  // ---------------------------------------------------------------------
  // SEMANTIK — status transaksi & stok.
  // Tiap status punya trio: [x] (isi/ikon), [x]Soft (latar), [x]Text (teks).
  // ---------------------------------------------------------------------

  /// Lunas, stok aman, laba positif.
  static const Color success = Color(0xFF14764C);
  static const Color successSoft = Color(0xFFE6F3EC);
  static const Color successText = Color(0xFF0B5233);

  /// Stok menipis, transaksi ditahan, perlu perhatian.
  static const Color warning = Color(0xFF8A5B08);
  static const Color warningSoft = Color(0xFFFBF0D8);
  static const Color warningText = Color(0xFF6E4806);

  /// Batal/void, stok habis, aksi merusak.
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerSoft = Color(0xFFFBE9E7);
  static const Color dangerText = Color(0xFF8C1D18);

  /// Informasi netral, pembayaran non-tunai (QRIS/transfer).
  static const Color info = Color(0xFF175F8F);
  static const Color infoSoft = Color(0xFFE5EFF6);
  static const Color infoText = Color(0xFF124D74);

  // ---------------------------------------------------------------------
  // SEMANTIK DOMAIN — dipakai konsisten di seluruh layar kasir.
  // ---------------------------------------------------------------------

  /// Pembayaran tunai.
  static const Color tunai = success;

  /// Pembayaran non-tunai (QRIS/transfer).
  static const Color nonTunai = info;

  /// Hutang / bon belum lunas.
  static const Color hutang = accentText;

  // ---------------------------------------------------------------------
  // OVERLAY & SHADOW.
  // ---------------------------------------------------------------------

  /// Warna dasar shadow — cokelat hangat, BUKAN hitam murni, supaya
  /// menyatu dengan kanvas kertas.
  static const Color shadowBase = Color(0xFF3B2E1F);

  /// Barrier dialog / bottom sheet.
  static const Color scrim = Color(0x66101410);
}

/// Nada warna semantik yang dipakai komponen bersama
/// ([AppPill], [AppIconBadge], [AppCard], dst).
///
/// Alih-alih tiap layar memilih warna sendiri, layar cukup memilih *nada*
/// dan sistem yang menentukan trio warnanya. Ini yang menjaga konsistensi
/// antar layar.
enum AppTone {
  /// Netral abu — informasi tanpa penekanan.
  neutral,

  /// Brand hijau — status utama/aktif.
  primary,

  /// Gula aren — hutang, ditahan, perlu tindak lanjut.
  accent,

  /// Hijau sukses — lunas, stok aman.
  success,

  /// Amber — stok menipis, peringatan ringan.
  warning,

  /// Merah — batal, error, aksi merusak.
  danger,

  /// Biru — non-tunai, info netral.
  info,
}

/// Resolver trio warna untuk sebuah [AppTone] — **versi palet terang saja**.
///
/// Dipertahankan selama masa migrasi mode gelap (PRD v1.1 K-5.6) supaya kode
/// lama tetap terkompilasi. Kode baru WAJIB memakai `tone.colorsOf(context)`
/// dari `app_palette.dart` yang mengikuti tema aktif.
extension AppToneColorsX on AppTone {
  @Deprecated(
    'Tidak sadar tema — selalu mengembalikan palet terang. '
    'Pakai tone.colorsOf(context) dari app_palette.dart.',
  )
  AppToneColors get colors => switch (this) {
    AppTone.neutral => const AppToneColors(
      fg: AppColors.inkSecondary,
      bg: AppColors.surfaceAlt,
      border: AppColors.border,
    ),
    AppTone.primary => const AppToneColors(
      fg: AppColors.primary,
      bg: AppColors.primary50,
      border: AppColors.primary100,
    ),
    AppTone.accent => const AppToneColors(
      fg: AppColors.accentText,
      bg: AppColors.accent50,
      border: AppColors.accent100,
    ),
    AppTone.success => const AppToneColors(
      fg: AppColors.successText,
      bg: AppColors.successSoft,
      border: AppColors.primary100,
    ),
    AppTone.warning => const AppToneColors(
      fg: AppColors.warningText,
      bg: AppColors.warningSoft,
      border: AppColors.accent100,
    ),
    AppTone.danger => const AppToneColors(
      fg: AppColors.dangerText,
      bg: AppColors.dangerSoft,
      border: Color(0xFFF3C9C5),
    ),
    AppTone.info => const AppToneColors(
      fg: AppColors.infoText,
      bg: AppColors.infoSoft,
      border: Color(0xFFC3DAEA),
    ),
  };
}

/// Trio warna sebuah nada: teks/ikon, latar lembut, dan garis tepi.
@immutable
class AppToneColors {
  const AppToneColors({
    required this.fg,
    required this.bg,
    required this.border,
  });

  /// Warna teks & ikon (kontras AA di atas [bg] dan di atas kertas).
  final Color fg;

  /// Latar lembut (chip, badge, ikon tonal).
  final Color bg;

  /// Garis tepi opsional.
  final Color border;
}
