import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/product_import.dart';

/// Satu baris pratinjau impor (PRD v1.1 §4.4 langkah 3).
///
/// Yang dilihat pengguna lebih dulu adalah **nasib barisnya** (pill kanan)
/// dan **nomor barisnya di Excel** — karena dua hal itulah yang dipakai
/// untuk memutuskan lanjut atau memperbaiki file dulu. Nilai hasil parsing
/// (harga, stok) ditampilkan APA ADANYA setelah normalisasi, bukan teks
/// aslinya, supaya kesalahan tafsir angka ("1.500" dibaca 1,5) ketahuan
/// sebelum data masuk (mitigasi risiko PRD §4.8).
class ImportPreviewRowTile extends StatelessWidget {
  const ImportPreviewRowTile({super.key, required this.planRow});

  final ProductImportPlanRow planRow;

  static ({String label, AppTone tone, IconData icon}) badgeFor(
    ProductImportAction action,
  ) {
    return switch (action) {
      ProductImportAction.create => (
        label: 'Baru',
        tone: AppTone.success,
        icon: Icons.add_rounded,
      ),
      ProductImportAction.update => (
        label: 'Diperbarui',
        tone: AppTone.info,
        icon: Icons.sync_rounded,
      ),
      ProductImportAction.skip => (
        label: 'Dilewati',
        tone: AppTone.neutral,
        icon: Icons.remove_rounded,
      ),
      ProductImportAction.error => (
        label: 'Bermasalah',
        tone: AppTone.danger,
        icon: Icons.error_outline_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final row = planRow.row;
    final badge = badgeFor(planRow.action);
    // Baris yang tetap masuk tapi perlu dilihat memakai nada peringatan,
    // bukan nada bahaya — bedanya penting supaya "perlu dicek" tidak
    // terbaca sebagai "gagal".
    final tone = planRow.hasWarning ? AppTone.warning : badge.tone;

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.spaceMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(
                icon: badge.icon,
                tone: tone,
                size: AppIconBadgeSize.sm,
              ),
              const SizedBox(width: AppSizes.spaceMs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.name.isEmpty ? '(nama kosong)' : row.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(row),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.inkSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppPill(
                    label: planRow.hasWarning && !planRow.hasError
                        ? '${badge.label} · perlu dicek'
                        : badge.label,
                    tone: tone,
                    dense: true,
                    maxWidth: 148,
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  AppMoneyText(
                    CurrencyFormatter.format(row.sellPrice),
                    size: AppMoneySize.sm,
                    color: planRow.hasError ? palette.inkTertiary : null,
                  ),
                ],
              ),
            ],
          ),
          if (planRow.issues.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSm),
            for (final issue in planRow.issues)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.spaceXs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      issue.isError
                          ? Icons.block_rounded
                          : Icons.info_outline_rounded,
                      size: AppSizes.iconSm,
                      color: (issue.isError ? AppTone.danger : AppTone.warning)
                          .colorsOf(context)
                          .fg,
                    ),
                    const SizedBox(width: AppSizes.spaceSm),
                    Expanded(
                      child: Text(
                        issue.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _subtitle(ProductImportRow row) {
    final parts = <String>['Baris ${row.excelRow}'];
    if (row.barcode != null) parts.add(row.barcode!);
    if (row.categoryName != null) parts.add(row.categoryName!);
    if (row.stock != null) parts.add('stok ${formatStock(row.stock!)}');
    return parts.join(' · ');
  }

  /// Stok boleh berpecahan (kg/liter) — `CurrencyFormatter` sengaja TIDAK
  /// dipakai di sini karena ia membulatkan ke bilangan bulat (uang tidak
  /// pernah berpecahan, stok bisa). Desimalnya ditulis dengan koma sesuai
  /// kebiasaan Indonesia.
  static String formatStock(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString().replaceAll('.', ',');
  }
}
