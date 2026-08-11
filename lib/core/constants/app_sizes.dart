/// Ukuran & spacing standar aplikasi.
///
/// Target sentuh minimal mengikuti kebutuhan non-fungsional PRD §6:
/// tombol & area sentuh >= 48dp agar mudah dipakai kasir yang terburu-buru.
abstract final class AppSizes {
  // Spacing.
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // Radius.
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  // Target sentuh minimum (Material & PRD: >= 48dp).
  static const double minTouchTarget = 48;

  // Breakpoint HP vs tablet (dipakai layar kasir adaptif, lihat architecture.md §5.1).
  static const double tabletBreakpoint = 600;
}
