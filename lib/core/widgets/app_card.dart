import 'package:flutter/material.dart';

import '../constants/app_palette.dart';
import '../constants/app_shadows.dart';
import '../constants/app_sizes.dart';

/// Permukaan dasar seluruh aplikasi.
///
/// GANTI semua pemakaian [Card] / [Container] + [BoxDecoration] manual
/// dengan widget ini supaya radius, border, padding, dan efek tekan
/// seragam di semua layar.
///
/// ```dart
/// AppCard(
///   onTap: () => context.push('/produk/1'),
///   child: Row(children: [...]),
/// )
///
/// // Kartu ringkasan yang menonjol:
/// AppCard(elevated: true, padding: EdgeInsets.all(AppSizes.spaceMl), child: ...)
///
/// // Kartu dalam keadaan terpilih:
/// AppCard(selected: isSelected, onTap: ..., child: ...)
/// ```
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.spaceMd),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.radius = AppSizes.radiusLg,
    this.elevated = false,
    this.selected = false,
    this.width,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;

  /// Padding dalam. Default 16; pakai [AppSizes.spaceMl] (20) untuk kartu
  /// hero/ringkasan yang butuh lebih lega.
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Kalau diisi, kartu jadi bisa ditekan (ripple + target sentuh penuh).
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Override warna permukaan (mis. `context.palette.surfaceAlt` untuk
  /// sub-panel).
  final Color? color;
  final Color? borderColor;
  final double radius;

  /// `true` → memakai shadow level 1 (kartu terasa mengambang). Di mode
  /// gelap shadow-nya nyaris tak terlihat — kedalaman dibawa oleh tangga
  /// permukaan, sesuai PRD v1.1 §5.4.
  /// Pakai hemat: kartu di dalam list panjang sebaiknya tetap datar.
  final bool elevated;

  /// Keadaan terpilih: border & latar bernada brand.
  final bool selected;

  final double? width;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shadows = AppShadows.of(context);
    final borderRadius = BorderRadius.circular(radius);
    final effectiveBorder =
        borderColor ?? (selected ? palette.primary200 : palette.border);
    final effectiveColor =
        color ?? (selected ? palette.primary50 : palette.surface);

    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: effectiveBorder,
          width: selected ? 1.5 : AppSizes.hairline,
        ),
        boxShadow: elevated ? shadows.level1 : AppShadows.level0,
      ),
      clipBehavior: clipBehavior,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          splashColor: palette.primary.withValues(alpha: 0.06),
          highlightColor: palette.primary.withValues(alpha: 0.04),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
