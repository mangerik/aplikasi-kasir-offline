import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/services/receipt_service.dart';
import '../../../domain/entities/sale_result.dart';
import '../../pos/providers/sale_providers.dart';
import '../../pos/widgets/receipt_widget.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/history_providers.dart';
import '../utils/pin_gate.dart';
import '../widgets/status_badge.dart';

/// Layar Detail Transaksi (plan.md Milestone 3 poin 3, 4 & 5): item, qty,
/// harga, diskon, total, pembayaran, kembalian (lewat `ReceiptWidget`,
/// reuse Milestone 2) + share ulang struk (`ReceiptService`), pelunasan
/// hutang, dan void transaksi.
class SaleDetailScreen extends ConsumerStatefulWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharing = false;
  bool _processing = false;

  Future<Uint8List?> _captureReceipt() async {
    final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareAsImage(SaleResult sale) async {
    setState(() => _sharing = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) return;
      await ReceiptService.shareAsImage(bytes, invoiceNumber: sale.invoiceNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _shareAsText(SaleResult sale) async {
    setState(() => _sharing = true);
    try {
      final profile = await ref.read(storeProfileProvider.future);
      await ReceiptService.shareAsText(sale, profile: profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _markPaid(SaleResult sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tandai Lunas?'),
        content: const Text(
          'Transaksi hutang ini akan ditandai sebagai sudah lunas. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tandai Lunas'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      await ref.read(markDebtPaidUsecaseProvider)(sale.saleId);
      ref.invalidate(saleDetailProvider(widget.saleId));
      await ref.read(historyListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaksi ditandai lunas.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _voidSale(SaleResult sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan Transaksi?'),
        content: const Text(
          'Stok barang yang terjual akan dikembalikan. Transaksi tetap '
          'tersimpan di riwayat dengan status "Batal". Tindakan ini tidak '
          'bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final pinOk = await checkPinGate(context, ref);
    if (!pinOk) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN salah. Void dibatalkan.')));
      }
      return;
    }

    setState(() => _processing = true);
    try {
      await ref.read(voidSaleUsecaseProvider)(sale.saleId);
      ref.invalidate(saleDetailProvider(widget.saleId));
      await ref.read(historyListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaksi dibatalkan, stok dikembalikan.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(saleDetailProvider(widget.saleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: detailAsync.when(
        data: _buildBody,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.spaceLg),
            child: Text('Gagal memuat detail: $error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SaleResult sale) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.spaceMd),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('No. Struk: ${sale.invoiceNumber}', style: theme.textTheme.titleMedium),
              ),
              StatusBadge(status: sale.status),
            ],
          ),
          if (sale.status == 'voided' && sale.voidedAt != null) ...[
            const SizedBox(height: AppSizes.spaceSm),
            _InfoBanner(
              color: AppColors.danger,
              icon: Icons.cancel_outlined,
              text: 'Transaksi dibatalkan pada ${DateFormatter.formatDateTime(sale.voidedAt!)}.'
                  ' Stok barang sudah dikembalikan.',
            ),
          ],
          if (sale.status == 'debt_unpaid') ...[
            const SizedBox(height: AppSizes.spaceSm),
            const _InfoBanner(
              color: AppColors.warning,
              icon: Icons.receipt_long_outlined,
              text: 'Transaksi hutang, belum lunas.',
            ),
          ],
          if (sale.status == 'completed' && sale.debtPaidAt != null) ...[
            const SizedBox(height: AppSizes.spaceSm),
            _InfoBanner(
              color: AppColors.success,
              icon: Icons.check_circle_outline,
              text: 'Hutang dilunasi pada ${DateFormatter.formatDateTime(sale.debtPaidAt!)}.',
            ),
          ],
          const SizedBox(height: AppSizes.spaceLg),
          Center(
            child: RepaintBoundary(key: _receiptKey, child: ReceiptWidget(sale: sale)),
          ),
          const SizedBox(height: AppSizes.spaceLg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sharing ? null : () => _shareAsText(sale),
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: const Text('Bagikan Teks'),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sharing ? null : () => _shareAsImage(sale),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Bagikan Gambar'),
                ),
              ),
            ],
          ),
          if (sale.status == 'debt_unpaid') ...[
            const SizedBox(height: AppSizes.spaceMd),
            FilledButton.icon(
              onPressed: _processing ? null : () => _markPaid(sale),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Tandai Lunas'),
            ),
          ],
          if (sale.status != 'voided') ...[
            const SizedBox(height: AppSizes.spaceSm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              onPressed: _processing ? null : () => _voidSale(sale),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Batalkan Transaksi'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSizes.spaceSm),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
