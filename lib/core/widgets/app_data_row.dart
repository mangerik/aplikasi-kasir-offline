import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

/// Baris "label kiri — nilai kanan".
///
/// Dipakai di ringkasan keranjang, detail transaksi, struk, dan kartu
/// laporan. Nilai selalu lebih tebal daripada labelnya (di aplikasi kasir
/// yang dibaca adalah angkanya, bukan namanya).
///
/// ```dart
/// AppKeyValueRow(label: 'Subtotal', value: CurrencyFormatter.format(sub)),
/// AppKeyValueRow(
///   label: 'Total',
///   value: CurrencyFormatter.format(total),
///   emphasized: true,
/// ),
/// AppKeyValueRow(label: 'Diskon', value: '-Rp2.000', valueColor: AppColors.dangerText),
/// ```
class AppKeyValueRow extends StatelessWidget {
  const AppKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
    this.icon,
    this.padding = const EdgeInsets.symmetric(vertical: AppSizes.spaceXs + 2),
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Baris total/kesimpulan — teks lebih besar & tebal.
  final bool emphasized;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = emphasized
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkSecondary);
    final valueStyle =
        (emphasized ? AppTextStyles.moneyLarge : AppTextStyles.money).copyWith(
          fontSize: emphasized ? 22 : 15,
          color: valueColor ?? AppColors.ink,
        );

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconSm, color: AppColors.inkSecondary),
            const SizedBox(width: AppSizes.spaceSm),
          ],
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: AppSizes.spaceMs),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

/// Teks nominal rupiah dengan angka rata (tabular figures).
///
/// Pakai untuk SEMUA nominal uang supaya digit antar baris sejajar dan
/// tidak "goyang" saat nilainya berubah.
///
/// ```dart
/// AppMoneyText(CurrencyFormatter.format(product.price));
/// AppMoneyText(CurrencyFormatter.format(total), size: AppMoneySize.hero);
/// ```
class AppMoneyText extends StatelessWidget {
  const AppMoneyText(
    this.text, {
    super.key,
    this.size = AppMoneySize.md,
    this.color,
    this.strikethrough = false,
  });

  final String text;
  final AppMoneySize size;
  final Color? color;

  /// Untuk harga sebelum diskon.
  final bool strikethrough;

  @override
  Widget build(BuildContext context) {
    final base = switch (size) {
      AppMoneySize.sm => AppTextStyles.money.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      AppMoneySize.md => AppTextStyles.money,
      AppMoneySize.lg => AppTextStyles.moneyLarge,
      AppMoneySize.hero => AppTextStyles.moneyHero,
    };

    return Text(
      text,
      style: base.copyWith(
        color: color ?? (strikethrough ? AppColors.inkTertiary : base.color),
        decoration: strikethrough ? TextDecoration.lineThrough : null,
        decorationColor: AppColors.inkTertiary,
      ),
    );
  }
}

enum AppMoneySize { sm, md, lg, hero }
