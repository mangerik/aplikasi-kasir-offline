/// Token ukuran: spacing, radius, target sentuh, dan ikon.
///
/// **Grid 4pt.** Semua nilai kelipatan 4 (dengan 2 sebagai pengecualian
/// hairline). Jangan pernah menulis angka spacing mentah di layar — pakai
/// token di sini supaya ritme vertikal seluruh aplikasi seragam.
///
/// Target sentuh mengikuti PRD §6: tombol & area sentuh >= 48dp agar kasir
/// yang terburu-buru tidak salah pencet.
abstract final class AppSizes {
  // -------------------------------------------------------------------
  // SPACING — pakai aturan "relationship-based": elemen yang berhubungan
  // rapat ([spaceXs]/[spaceSm]), antar grup renggang ([spaceLg]/[spaceXl]).
  // -------------------------------------------------------------------

  /// 4 — jarak label ke nilainya, ikon ke teks kecil.
  static const double spaceXs = 4;

  /// 8 — antar elemen dalam satu baris/grup.
  static const double spaceSm = 8;

  /// 12 — jarak "setengah" antara item list yang padat.
  static const double spaceMs = 12;

  /// 16 — padding layar & padding dalam kartu default.
  static const double spaceMd = 16;

  /// 20 — padding dalam kartu yang lega (kartu ringkasan/hero).
  static const double spaceMl = 20;

  /// 24 — antar grup dalam satu section.
  static const double spaceLg = 24;

  /// 32 — antar section.
  static const double spaceXl = 32;

  /// 48 — jeda besar (empty state, sebelum footer).
  static const double space2xl = 48;

  /// 64 — jeda hero / ruang napas layar kosong.
  static const double space3xl = 64;

  /// Padding horizontal standar semua layar. Jangan pakai nilai lain.
  static const double screenPadding = spaceMd;

  /// Padding bawah ekstra pada scroll view supaya konten terakhir tidak
  /// tertutup dock navigasi / bar keranjang.
  static const double bottomSafePadding = 96;

  // -------------------------------------------------------------------
  // RADIUS — makin besar elemennya, makin besar radiusnya.
  // -------------------------------------------------------------------

  /// 6 — badge mungil, indikator.
  static const double radiusXs = 6;

  /// 10 — chip, field kecil, thumbnail.
  static const double radiusSm = 10;

  /// 14 — tombol, input field.
  static const double radiusMd = 14;

  /// 18 — kartu, tile produk.
  static const double radiusLg = 18;

  /// 24 — sheet, dialog, kartu hero, dock navigasi.
  static const double radiusXl = 24;

  /// 28 — bottom sheet besar.
  static const double radius2xl = 28;

  /// Pill penuh (chip status, tombol bulat).
  static const double radiusPill = 999;

  // -------------------------------------------------------------------
  // GARIS & TARGET SENTUH.
  // -------------------------------------------------------------------

  /// Ketebalan hairline (divider, outline kartu).
  static const double hairline = 1;

  /// Target sentuh minimum (Material & PRD: >= 48dp).
  static const double minTouchTarget = 48;

  /// Tinggi tombol utama (CTA) — lebih besar dari minimum karena dipakai
  /// sambil berdiri & terburu-buru.
  static const double buttonHeight = 52;

  /// Tinggi tombol utama versi "kasir" (Bayar/Simpan) di bar bawah.
  static const double buttonHeightLarge = 60;

  // -------------------------------------------------------------------
  // IKON.
  // -------------------------------------------------------------------

  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 40;

  // -------------------------------------------------------------------
  // LAYOUT.
  // -------------------------------------------------------------------

  /// Breakpoint HP vs tablet (layar kasir adaptif, architecture.md §5.1).
  static const double tabletBreakpoint = 600;

  /// Lebar maksimum kolom teks/form supaya tetap nyaman dibaca di tablet.
  static const double maxContentWidth = 560;

  /// Tinggi dock navigasi bawah (tanpa safe area).
  static const double navDockHeight = 62;
}

/// Durasi & kurva animasi standar.
///
/// Micro-interaction adalah sinyal kepercayaan: transisi harus cepat dan
/// konsisten, tidak pernah lebih lambat dari [slow].
abstract final class AppDurations {
  /// 120ms — feedback tekan, perubahan warna.
  static const Duration instant = Duration(milliseconds: 120);

  /// 200ms — transisi standar (indikator nav, expand chip).
  static const Duration fast = Duration(milliseconds: 200);

  /// 320ms — sheet, dialog, perubahan layout.
  static const Duration medium = Duration(milliseconds: 320);

  /// 500ms — animasi perayaan (checkout sukses).
  static const Duration slow = Duration(milliseconds: 500);
}
