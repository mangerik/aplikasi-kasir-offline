import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/entities/sale_result.dart';

/// Render & share struk digital (architecture.md §3, plan.md Milestone 2
/// poin 7).
///
/// Widget struk itu sendiri (`ReceiptWidget`) ada di
/// `features/pos/widgets/receipt_widget.dart` — service ini hanya
/// bertanggung jawab MEMFORMAT teks struk dan MEMANGGIL `share_plus`
/// (baik untuk teks maupun gambar hasil `RepaintBoundary`).
abstract final class ReceiptService {
  /// Share struk sebagai TEKS polos (mis. untuk WhatsApp tanpa gambar).
  static Future<void> shareAsText(SaleResult sale) async {
    await SharePlus.instance.share(
      ShareParams(
        text: formatReceiptText(sale),
        subject: 'Struk ${sale.invoiceNumber}',
      ),
    );
  }

  /// Share struk sebagai GAMBAR — [pngBytes] adalah hasil capture
  /// `RepaintBoundary` (lihat `ReceiptWidget`/`CheckoutSuccessScreen`).
  /// File sementara ditulis ke folder cache lalu dibagikan lewat
  /// `share_plus`.
  static Future<void> shareAsImage(Uint8List pngBytes, {required String invoiceNumber}) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/struk_$invoiceNumber.png');
    await file.writeAsBytes(pngBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Struk $invoiceNumber',
      ),
    );
  }

  /// Format struk sebagai teks monospace sederhana — dipakai [shareAsText]
  /// dan bisa dipakai ulang untuk pratinjau di layar sukses transaksi.
  static String formatReceiptText(SaleResult sale) {
    final buffer = StringBuffer()
      ..writeln('KASIR WARUNG')
      ..writeln('No. Struk: ${sale.invoiceNumber}')
      ..writeln(DateFormatter.formatDateTime(sale.createdAt))
      ..writeln('------------------------------');

    for (final item in sale.items) {
      buffer.writeln(item.name);
      final qtyLabel = _formatQty(item.qty);
      buffer.writeln(
        '  $qtyLabel ${item.unit} x ${CurrencyFormatter.format(item.sellPrice)}'
        ' = ${CurrencyFormatter.format(item.lineTotal)}',
      );
      if (item.discount > 0) {
        buffer.writeln('  Diskon: -${CurrencyFormatter.format(item.discount)}');
      }
    }

    buffer
      ..writeln('------------------------------')
      ..writeln('Subtotal: ${CurrencyFormatter.format(sale.subtotal)}');
    if (sale.discount > 0) {
      buffer.writeln('Diskon transaksi: -${CurrencyFormatter.format(sale.discount)}');
    }
    buffer.writeln('Total: ${CurrencyFormatter.format(sale.total)}');

    if (sale.paymentMethod == 'cash') {
      buffer
        ..writeln('Tunai: ${CurrencyFormatter.format(sale.paidAmount)}')
        ..writeln('Kembalian: ${CurrencyFormatter.format(sale.changeAmount)}');
    } else if (sale.paymentMethod == 'debt') {
      buffer.writeln('Hutang atas nama: ${sale.customerName ?? '-'}');
    } else {
      buffer.writeln('Non-tunai');
    }

    buffer
      ..writeln('------------------------------')
      ..writeln('Terima kasih telah berbelanja!');

    return buffer.toString();
  }

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }
}
