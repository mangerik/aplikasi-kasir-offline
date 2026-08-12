import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/services/receipt_service.dart';
import '../../../domain/entities/sale_result.dart';
import '../../pos/providers/sale_providers.dart';
import '../../pos/widgets/receipt_widget.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/history_providers.dart';
import '../utils/pin_gate.dart';
import '../widgets/status_badge.dart';

/// Layar Detail Transaksi (plan.md Milestone 3 poin 3, 4 & 5): item, qty,
/// harga, diskon, total, pembayaran, kembalian + share ulang struk
/// (`ReceiptService`), pelunasan hutang, dan void transaksi.
///
/// Desain (docs/ui-redesign-foundation.md): disusun seperti struk premium —
/// kepala transaksi (no. struk, status, total), rincian item, ringkasan
/// pembayaran, lalu pratinjau struk digital yang akan dibagikan. Aksi
/// utama (bagikan / tandai lunas) ada di bar mengambang di zona jempol.
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
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: ${AppErrorMessage.from(e)}')));
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
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan struk: ${AppErrorMessage.from(e)}')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _markPaid(SaleResult sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tandai Lunas?'),
        content: const Text(
          'Transaksi hutang ini akan ditandai sebagai sudah lunas. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(e))));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _voidSale(SaleResult sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan Transaksi?'),
        content: const Text(
          'Stok barang yang terjual akan dikembalikan. Transaksi tetap '
          'tersimpan di riwayat dengan status "Batal". Tindakan ini tidak '
          'bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(e))));
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
        loading: () => const AppLoadingView(message: 'Memuat detail transaksi...'),
        error: (error, stack) => AppErrorView(
          title: 'Gagal memuat detail',
          message: AppErrorMessage.from(error),
          onRetry: () => ref.invalidate(saleDetailProvider(widget.saleId)),
        ),
      ),
    );
  }

  Widget _buildBody(SaleResult sale) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceMd,
              AppSizes.screenPadding,
              AppSizes.spaceLg,
            ),
            children: [
              _HeaderCard(sale: sale),
              ..._statusNotes(sale),
              const SizedBox(height: AppSizes.spaceLg),
              SectionHeader(
                title: 'Rincian Item',
                trailing: AppPill(label: '${sale.items.length} item', dense: true),
              ),
              _ItemsCard(sale: sale),
              const SizedBox(height: AppSizes.spaceMd),
              _SummaryCard(sale: sale),
              if (sale.note != null && sale.note!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSizes.spaceMd),
                AppCard(
                  color: context.palette.surfaceAlt,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: AppSizes.iconSm,
                        color: context.palette.inkSecondary,
                      ),
                      const SizedBox(width: AppSizes.spaceSm),
                      Expanded(
                        child: Text(
                          sale.note!.trim(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.spaceLg),
              SectionHeader(
                title: 'Struk Digital',
                subtitle: 'Tampilan yang dikirim ke pelanggan',
              ),
              AppCard(
                color: context.palette.surfaceAlt,
                padding: const EdgeInsets.all(AppSizes.spaceMs),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RepaintBoundary(
                      key: _receiptKey,
                      child: ReceiptWidget(sale: sale),
                    ),
                  ),
                ),
              ),
              if (sale.status != 'voided') ...[
                const SizedBox(height: AppSizes.spaceLg),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.dangerText,
                    side: BorderSide(color: context.palette.danger),
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  ),
                  onPressed: _processing ? null : () => _voidSale(sale),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Batalkan Transaksi'),
                ),
                const SizedBox(height: AppSizes.spaceSm),
                Text(
                  'Membatalkan transaksi akan mengembalikan stok barang dan '
                  'butuh PIN pemilik.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        _ActionBar(
          sale: sale,
          busy: _sharing || _processing,
          onShareText: () => _shareAsText(sale),
          onShareImage: () => _shareAsImage(sale),
          onMarkPaid: () => _markPaid(sale),
        ),
      ],
    );
  }

  /// Catatan kontekstual sesuai keadaan transaksi (void / hutang / lunas).
  List<Widget> _statusNotes(SaleResult sale) {
    final notes = <Widget>[];
    if (sale.status == 'voided' && sale.voidedAt != null) {
      notes.add(
        AppBanner(
          tone: AppTone.danger,
          icon: Icons.block_outlined,
          title: 'Transaksi dibatalkan',
          message:
              'Dibatalkan pada ${DateFormatter.formatDateTime(sale.voidedAt!)}. '
              'Stok barang sudah dikembalikan dan nilainya tidak dihitung di laporan.',
        ),
      );
    }
    if (sale.status == 'debt_unpaid') {
      notes.add(
        AppBanner(
          tone: AppTone.accent,
          icon: Icons.schedule_outlined,
          title: 'Belum lunas',
          message: sale.customerName != null
              ? '${sale.customerName} masih punya hutang sebesar '
                    '${CurrencyFormatter.format(sale.total)} dari transaksi ini.'
              : 'Hutang dari transaksi ini belum dilunasi.',
        ),
      );
    }
    if (sale.status == 'completed' && sale.debtPaidAt != null) {
      notes.add(
        AppBanner(
          tone: AppTone.success,
          icon: Icons.verified_outlined,
          title: 'Hutang sudah lunas',
          message: 'Dilunasi pada ${DateFormatter.formatDateTime(sale.debtPaidAt!)}.',
        ),
      );
    }
    return [
      for (final note in notes) ...[const SizedBox(height: AppSizes.spaceMs), note],
    ];
  }
}

/// Kepala transaksi: no. struk, status, dan total sebagai angka utama.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.sale});

  final SaleResult sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVoided = sale.status == 'voided';

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSizes.spaceMl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NO. STRUK', style: context.textStyles.eyebrow),
                    const SizedBox(height: AppSizes.spaceXs),
                    Text(sale.invoiceNumber, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.spaceSm),
              StatusBadge(status: sale.status),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMd),
          Text('TOTAL BELANJA', style: context.textStyles.eyebrow),
          const SizedBox(height: AppSizes.spaceXs),
          AppMoneyText(
            CurrencyFormatter.format(sale.total),
            size: AppMoneySize.lg,
            strikethrough: isVoided,
            color: isVoided ? null : context.palette.primary,
          ),
          const SizedBox(height: AppSizes.spaceMd),
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: AppSizes.iconSm,
                color: context.palette.inkSecondary,
              ),
              const SizedBox(width: AppSizes.spaceXs + 2),
              Expanded(
                child: Text(
                  DateFormatter.formatDateTime(sale.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMs),
          Row(
            children: [
              AppPill(
                label: paymentMethodLabel(sale.paymentMethod),
                tone: paymentMethodTone(sale.paymentMethod),
                icon: paymentMethodIcon(sale.paymentMethod),
              ),
              if (sale.customerName != null && sale.customerName!.trim().isNotEmpty) ...[
                const SizedBox(width: AppSizes.spaceMs),
                Icon(
                  Icons.person_outline,
                  size: AppSizes.iconSm,
                  color: context.palette.inkSecondary,
                ),
                const SizedBox(width: AppSizes.spaceXs),
                Flexible(
                  child: Text(
                    sale.customerName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Rincian item — satu baris per barang, nominal di kanan.
class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.sale});

  final SaleResult sale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceXs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < sale.items.length; i++) ...[
            if (i > 0) const Divider(height: AppSizes.spaceMs),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceMs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPill(label: '${_formatQty(sale.items[i].qty)}×', dense: true),
                  const SizedBox(width: AppSizes.spaceMs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sale.items[i].name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${CurrencyFormatter.format(sale.items[i].sellPrice)} '
                          '/ ${sale.items[i].unit}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (sale.items[i].discount > 0)
                          Text(
                            'Diskon ${CurrencyFormatter.format(sale.items[i].discount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.palette.accentText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSm),
                  AppMoneyText(CurrencyFormatter.format(sale.items[i].lineTotal)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}

/// Ringkasan uang: subtotal, diskon, total, lalu pembayaran & kembalian.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.sale});

  final SaleResult sale;

  @override
  Widget build(BuildContext context) {
    final showPayment = sale.paidAmount > 0 || sale.changeAmount > 0;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spaceMd,
        vertical: AppSizes.spaceSm,
      ),
      child: Column(
        children: [
          AppKeyValueRow(
            label: 'Subtotal',
            value: CurrencyFormatter.format(sale.subtotal),
          ),
          if (sale.discount > 0)
            AppKeyValueRow(
              label: 'Diskon transaksi',
              value: '-${CurrencyFormatter.format(sale.discount)}',
              valueColor: context.palette.accentText,
            ),
          const Divider(height: AppSizes.spaceMd),
          AppKeyValueRow(
            label: 'Total',
            value: CurrencyFormatter.format(sale.total),
            emphasized: true,
          ),
          if (showPayment) ...[
            const Divider(height: AppSizes.spaceMd),
            AppKeyValueRow(
              label: 'Dibayar',
              value: CurrencyFormatter.format(sale.paidAmount),
            ),
            AppKeyValueRow(
              label: 'Kembalian',
              value: CurrencyFormatter.format(sale.changeAmount),
              valueColor: context.palette.successText,
            ),
          ],
        ],
      ),
    );
  }
}

/// Bar aksi mengambang di zona jempol (foundation §7.1 poin 7).
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.sale,
    required this.busy,
    required this.onShareText,
    required this.onShareImage,
    required this.onMarkPaid,
  });

  final SaleResult sale;
  final bool busy;
  final VoidCallback onShareText;
  final VoidCallback onShareImage;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final isDebt = sale.status == 'debt_unpaid';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.spaceMs,
        ),
        child: Container(
          decoration: AppDecorations.floating(context),
          padding: const EdgeInsets.all(AppSizes.spaceMs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.spaceXs,
                  AppSizes.spaceXs,
                  AppSizes.spaceXs,
                  AppSizes.spaceSm,
                ),
                child: Text('BAGIKAN STRUK KE PELANGGAN', style: context.textStyles.eyebrow),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onShareText,
                      icon: const Icon(Icons.chat_outlined, size: AppSizes.iconSm),
                      label: const Text('Teks'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onShareImage,
                      icon: const Icon(Icons.image_outlined, size: AppSizes.iconSm),
                      label: const Text('Gambar'),
                    ),
                  ),
                ],
              ),
              if (isDebt) ...[
                const SizedBox(height: AppSizes.spaceSm),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeightLarge,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onMarkPaid,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Tandai Lunas'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
