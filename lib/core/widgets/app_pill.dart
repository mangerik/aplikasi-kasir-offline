import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// Label status kecil berbentuk pill (lunas, hutang, batal, stok menipis,
/// metode bayar, dst.).
///
/// Semua status di aplikasi WAJIB memakai widget ini — jangan membuat
/// `Container` + warna sendiri, supaya bahasa status seragam antar layar.
///
/// ```dart
/// const AppPill(label: 'Lunas', tone: AppTone.success);
/// const AppPill(label: 'Hutang', tone: AppTone.accent, icon: Icons.schedule);
/// const AppPill(label: 'Batal', tone: AppTone.danger, filled: true);
///
/// // Teks dinamis (nama pelanggan, nomor struk) — aman, otomatis dipotong
/// // dengan elipsis begitu ruangnya kurang:
/// AppPill(label: sale.customerName, tone: AppTone.accent);
/// ```
///
/// ### Perilaku teks panjang
/// Label SELALU satu baris dan dipotong dengan elipsis (`Lunas…`) — tidak
/// pernah melebar tak terkendali sampai memicu overflow. Aturannya:
/// - Kalau pill menerima lebar terbatas (di dalam [Wrap], `ListTile.trailing`,
///   [Flexible]/[Expanded], atau [Column]), pill menyusut sendiri mengikuti
///   ruang yang ada.
/// - Kalau pill jadi anak langsung sebuah [Row] (lebar tak terbatas), Row
///   TIDAK bisa memberi tahu ruang yang tersisa. Untuk label dinamis di
///   posisi itu, bungkus dengan `Flexible(child: AppPill(...))` **atau**
///   isi [maxWidth].
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
    this.filled = false,
    this.dense = false,
    this.maxWidth,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// `true` → latar pekat (warna [AppTone] penuh) untuk penekanan maksimal.
  /// Pakai hanya untuk status kritis (mis. "BATAL").
  final bool filled;

  /// Versi lebih rapat untuk dipakai di dalam list padat.
  final bool dense;

  /// Batas lebar eksplisit. Hanya perlu diisi kalau pill berlabel dinamis
  /// dipakai di tempat berlebar tak terbatas (anak langsung [Row], list
  /// horizontal). Pill tetap menciut ke lebar isinya kalau labelnya pendek —
  /// ini plafon, bukan lebar tetap.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = tone.colors;
    final fg = filled ? _onFilled(tone) : c.fg;
    final bg = filled ? c.fg : c.bg;

    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: fg,
        fontSize: dense ? 11 : 12,
        height: 1.1,
      ),
    );

    Widget pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSizes.spaceSm : AppSizes.spaceMs,
        vertical: dense ? 3 : AppSizes.spaceXs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: filled ? null : Border.all(color: c.border),
      ),
      // [LayoutBuilder] dipakai untuk mendeteksi apakah lebar yang diterima
      // pill terbatas atau tidak. [Flexible] WAJIB dihindari saat lebarnya
      // tak terbatas (mis. pill jadi anak langsung sebuah Row) karena
      // RenderFlex melempar assertion "children have non-zero flex but
      // incoming width constraints are unbounded".
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.maxWidth.isFinite;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 12 : 14, color: fg),
                const SizedBox(width: AppSizes.spaceXs + 2),
              ],
              // Loose fit: teks pendek tetap menciut ke lebar aslinya
              // (tampilan tidak berubah sama sekali), teks panjang menyusut
              // mengikuti ruang yang tersisa lalu dipotong elipsis.
              if (bounded) Flexible(child: text) else text,
            ],
          );
        },
      ),
    );

    if (maxWidth != null) {
      pill = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: pill,
      );
    }
    return pill;
  }

  static Color _onFilled(AppTone tone) =>
      tone == AppTone.neutral ? AppColors.surface : AppColors.onDark;
}

/// Ikon di dalam kotak bernada lembut (squircle).
///
/// Dipakai sebagai `leading` list item, ikon kategori, atau ilustrasi kecil
/// di kartu ringkasan — jauh lebih hidup daripada ikon telanjang.
///
/// ```dart
/// const AppIconBadge(icon: Icons.payments_outlined, tone: AppTone.success);
/// const AppIconBadge(icon: Icons.inventory_2_outlined, size: AppIconBadgeSize.lg);
/// ```
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.tone = AppTone.primary,
    this.size = AppIconBadgeSize.md,
    this.filled = false,
  });

  final IconData icon;
  final AppTone tone;
  final AppIconBadgeSize size;

  /// `true` → kotak berwarna pekat dengan ikon terang.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = tone.colors;
    final box = switch (size) {
      AppIconBadgeSize.sm => 32.0,
      AppIconBadgeSize.md => 40.0,
      AppIconBadgeSize.lg => 52.0,
      AppIconBadgeSize.xl => 72.0,
    };
    final iconSize = switch (size) {
      AppIconBadgeSize.sm => AppSizes.iconSm,
      AppIconBadgeSize.md => AppSizes.iconMd,
      AppIconBadgeSize.lg => AppSizes.iconLg,
      AppIconBadgeSize.xl => AppSizes.iconXl,
    };
    final radius = switch (size) {
      AppIconBadgeSize.sm => AppSizes.radiusSm,
      AppIconBadgeSize.md => AppSizes.radiusMd,
      AppIconBadgeSize.lg => AppSizes.radiusLg,
      AppIconBadgeSize.xl => AppSizes.radiusXl,
    };

    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: filled ? c.fg : c.bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: filled ? AppColors.onDark : c.fg,
      ),
    );
  }
}

enum AppIconBadgeSize { sm, md, lg, xl }
