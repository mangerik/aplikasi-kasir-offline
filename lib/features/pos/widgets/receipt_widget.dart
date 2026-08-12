import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/sale_result.dart';
import '../../../domain/entities/store_profile.dart';
import '../../settings/providers/settings_providers.dart';

/// Widget struk digital — dirender dalam kotak putih lebar tetap (mirip
/// kertas struk kasir 58mm), dibungkus `RepaintBoundary` oleh pemanggil
/// (`checkout_success_screen.dart`) supaya bisa di-capture jadi gambar
/// untuk `share_plus` (plan.md Milestone 2 poin 7).
///
/// **Sengaja monokrom & monospace**, di luar palet "Kertas & Daun": struk
/// ini ikut dicetak/di-share sebagai gambar dan harus tetap terbaca di
/// printer termal hitam-putih 58mm. Yang dirapikan hanya ritme tipografinya
/// (hierarki ukuran, jarak antar blok, garis putus-putus yang mengikuti
/// lebar), bukan warnanya.
///
/// Sejak Milestone 5, nama/alamat/no. HP toko (`storeProfileProvider`,
/// diisi dari layar Pengaturan) tampil otomatis di kepala struk —
/// fallback ke `'KASIR WARUNG'` tanpa alamat/telp bila profil belum diisi
/// (perilaku identik dengan sebelum M5, tidak ada breaking change untuk
/// struk lama).
class ReceiptWidget extends ConsumerWidget {
  const ReceiptWidget({super.key, required this.sale});

  final SaleResult sale;

  /// Lebar render struk. 340 (bukan lebar penuh) supaya proporsinya mirip
  /// kertas 58mm dan tetap muat di dalam kartu layar sukses pada HP 360dp.
  static const double width = 340;

  static const TextStyle _body = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.45,
    color: Colors.black,
  );
  static const TextStyle _bold = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
  static const TextStyle _title = TextStyle(
    fontFamily: 'monospace',
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
    color: Colors.black,
  );
  static const TextStyle _total = TextStyle(
    fontFamily: 'monospace',
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(storeProfileProvider).value ?? const StoreProfile();

    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceMl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            profile.displayName.toUpperCase(),
            textAlign: TextAlign.center,
            style: _title,
          ),
          if (profile.hasAddress)
            Text(profile.address!.trim(), textAlign: TextAlign.center, style: _body),
          if (profile.hasPhone)
            Text(profile.phone!.trim(), textAlign: TextAlign.center, style: _body),
          const SizedBox(height: AppSizes.spaceSm),
          Text('No. Struk: ${sale.invoiceNumber}', textAlign: TextAlign.center, style: _body),
          Text(
            DateFormatter.formatDateTime(sale.createdAt),
            textAlign: TextAlign.center,
            style: _body,
          ),
          const SizedBox(height: AppSizes.spaceSm),
          const _ReceiptDivider(),
          const SizedBox(height: AppSizes.spaceXs),
          for (final item in sale.items) ...[
            const SizedBox(height: AppSizes.spaceXs + 2),
            Text(item.name, style: _bold),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatQty(item.qty)} ${item.unit} x '
                    '${CurrencyFormatter.format(item.sellPrice)}',
                    style: _body,
                  ),
                ),
                Text(CurrencyFormatter.format(item.lineTotal), style: _body),
              ],
            ),
            if (item.discount > 0)
              Text(
                '  diskon -${CurrencyFormatter.format(item.discount)}',
                style: _body,
              ),
          ],
          const SizedBox(height: AppSizes.spaceMs),
          const _ReceiptDivider(),
          const SizedBox(height: AppSizes.spaceXs + 2),
          _AmountRow(label: 'Subtotal', value: sale.subtotal, style: _body),
          if (sale.discount > 0)
            _AmountRow(label: 'Diskon transaksi', value: -sale.discount, style: _body),
          const SizedBox(height: AppSizes.spaceXs),
          _AmountRow(label: 'TOTAL', value: sale.total, style: _total),
          const SizedBox(height: AppSizes.spaceXs),
          if (sale.paymentMethod == 'cash') ...[
            _AmountRow(label: 'Tunai', value: sale.paidAmount, style: _body),
            _AmountRow(label: 'Kembalian', value: sale.changeAmount, style: _body),
          ] else if (sale.paymentMethod == 'debt') ...[
            Text('HUTANG atas nama:', style: _body),
            Text(sale.customerName ?? '-', style: _bold),
          ] else ...[
            Text('Non-tunai', style: _body),
          ],
          const SizedBox(height: AppSizes.spaceMs),
          const _ReceiptDivider(),
          const SizedBox(height: AppSizes.spaceMs),
          Text(
            'Terima kasih telah berbelanja!',
            textAlign: TextAlign.center,
            style: _body,
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
  });

  final String label;
  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: style)),
        Text(CurrencyFormatter.format(value), style: style),
      ],
    );
  }
}

/// Garis putus-putus yang mengisi lebar struk apa pun ukurannya — tetap
/// satu baris, tidak pernah membungkus.
class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Lebar karakter monospace 12pt kira-kira 7.2px.
        final dashCount = (constraints.maxWidth / 7.2).floor().clamp(8, 80);
        return Text(
          '-' * dashCount,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: ReceiptWidget._body,
        );
      },
    );
  }
}
