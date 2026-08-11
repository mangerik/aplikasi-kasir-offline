import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/sale_result.dart';
import '../../../domain/entities/store_profile.dart';
import '../../settings/providers/settings_providers.dart';

/// Widget struk digital — dirender dalam kotak putih lebar tetap (mirip
/// kertas struk kasir), dibungkus `RepaintBoundary` oleh pemanggil
/// (`checkout_success_screen.dart`) supaya bisa di-capture jadi gambar
/// untuk `share_plus` (plan.md Milestone 2 poin 7).
///
/// Sejak Milestone 5, nama/alamat/no. HP toko (`storeProfileProvider`,
/// diisi dari layar Pengaturan) tampil otomatis di kepala struk —
/// fallback ke `'KASIR WARUNG'` tanpa alamat/telp bila profil belum diisi
/// (perilaku identik dengan sebelum M5, tidak ada breaking change untuk
/// struk lama).
class ReceiptWidget extends ConsumerWidget {
  const ReceiptWidget({super.key, required this.sale});

  final SaleResult sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(storeProfileProvider).value ?? const StoreProfile();
    const monoStyle = TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black);
    return Container(
      width: 360,
      color: Colors.white,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          if (profile.hasAddress)
            Text(profile.address!.trim(), textAlign: TextAlign.center, style: monoStyle),
          if (profile.hasPhone)
            Text(profile.phone!.trim(), textAlign: TextAlign.center, style: monoStyle),
          const SizedBox(height: 4),
          Text(
            'No. Struk: ${sale.invoiceNumber}',
            textAlign: TextAlign.center,
            style: monoStyle,
          ),
          Text(
            DateFormatter.formatDateTime(sale.createdAt),
            textAlign: TextAlign.center,
            style: monoStyle,
          ),
          const SizedBox(height: AppSizes.spaceSm),
          const _DashedDivider(),
          for (final item in sale.items) ...[
            const SizedBox(height: 6),
            Text(item.name, style: monoStyle.copyWith(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatQty(item.qty)} ${item.unit} x ${CurrencyFormatter.format(item.sellPrice)}',
                    style: monoStyle,
                  ),
                ),
                Text(CurrencyFormatter.format(item.lineTotal), style: monoStyle),
              ],
            ),
            if (item.discount > 0)
              Text('  Diskon: -${CurrencyFormatter.format(item.discount)}', style: monoStyle),
          ],
          const SizedBox(height: AppSizes.spaceSm),
          const _DashedDivider(),
          const SizedBox(height: 6),
          _AmountRow(label: 'Subtotal', value: sale.subtotal, style: monoStyle),
          if (sale.discount > 0)
            _AmountRow(label: 'Diskon transaksi', value: -sale.discount, style: monoStyle),
          _AmountRow(label: 'Total', value: sale.total, style: monoStyle, bold: true),
          const SizedBox(height: 4),
          if (sale.paymentMethod == 'cash') ...[
            _AmountRow(label: 'Tunai', value: sale.paidAmount, style: monoStyle),
            _AmountRow(label: 'Kembalian', value: sale.changeAmount, style: monoStyle),
          ] else if (sale.paymentMethod == 'debt') ...[
            Text('Hutang atas nama: ${sale.customerName ?? '-'}', style: monoStyle),
          ] else ...[
            Text('Non-tunai', style: monoStyle),
          ],
          const SizedBox(height: AppSizes.spaceSm),
          const _DashedDivider(),
          const SizedBox(height: AppSizes.spaceSm),
          const Text(
            'Terima kasih telah berbelanja!',
            textAlign: TextAlign.center,
            style: monoStyle,
          ),
        ],
      ),
    );
  }

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    required this.style,
    this.bold = false,
  });

  final String label;
  final int value;
  final TextStyle style;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = bold ? style.copyWith(fontWeight: FontWeight.bold) : style;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: effectiveStyle),
        Text(CurrencyFormatter.format(value), style: effectiveStyle),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '--------------------------------',
      style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black),
    );
  }
}
