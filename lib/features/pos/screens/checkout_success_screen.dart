import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/services/receipt_service.dart';
import '../../../domain/entities/sale_result.dart';
import '../../settings/providers/settings_providers.dart';
import '../widgets/receipt_widget.dart';

/// Layar sukses transaksi (plan.md Milestone 2 poin 7): ringkasan + struk
/// digital (`ReceiptWidget`), share struk sebagai GAMBAR (capture
/// `RepaintBoundary` lewat `ReceiptService.shareAsImage`) maupun TEKS.
class CheckoutSuccessScreen extends ConsumerStatefulWidget {
  const CheckoutSuccessScreen({super.key, required this.sale});

  final SaleResult sale;

  @override
  ConsumerState<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends ConsumerState<CheckoutSuccessScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharing = false;

  Future<Uint8List?> _captureReceipt() async {
    final boundary =
        _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) return;
      await ReceiptService.shareAsImage(bytes, invoiceNumber: widget.sale.invoiceNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: ${AppErrorMessage.from(e)}')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareAsText() async {
    setState(() => _sharing = true);
    try {
      final profile = await ref.read(storeProfileProvider.future);
      await ReceiptService.shareAsText(widget.sale, profile: profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: ${AppErrorMessage.from(e)}')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Transaksi Berhasil')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.spaceMd),
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 72),
              const SizedBox(height: AppSizes.spaceSm),
              Center(
                child: Text(
                  'Pembayaran berhasil disimpan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSizes.spaceSm),
              Center(
                child: Text(
                  'No. Struk: ${sale.invoiceNumber}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSizes.spaceLg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.spaceMd),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Total belanja', value: sale.total),
                      if (sale.paymentMethod == 'cash') ...[
                        _SummaryRow(label: 'Uang diterima', value: sale.paidAmount),
                        _SummaryRow(label: 'Kembalian', value: sale.changeAmount),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spaceLg),
              Center(
                child: RepaintBoundary(
                  key: _receiptKey,
                  child: ReceiptWidget(sale: sale),
                ),
              ),
              const SizedBox(height: AppSizes.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : _shareAsText,
                      icon: const Icon(Icons.text_snippet_outlined),
                      label: const Text('Bagikan Teks'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : _shareAsImage,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Bagikan Gambar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceMd),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Transaksi Baru'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSizes.spaceSm),
          Text(
            CurrencyFormatter.format(value),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
