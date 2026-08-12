import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/services/receipt_service.dart';
import '../../../domain/entities/sale_result.dart';
import '../../settings/providers/settings_providers.dart';
import '../widgets/receipt_widget.dart';

/// Layar sukses transaksi (plan.md Milestone 2 poin 7): ringkasan + struk
/// digital (`ReceiptWidget`), share struk sebagai GAMBAR (capture
/// `RepaintBoundary` lewat `ReceiptService.shareAsImage`) maupun TEKS.
///
/// **Ini momen puncak aplikasi** (docs/ui-redesign-foundation.md §1):
/// centang hijau yang muncul dengan animasi singkat, lalu angka yang paling
/// dibutuhkan kasir saat itu juga — **kembalian** untuk tunai, **total**
/// untuk non-tunai/hutang — dalam `AppMoneySize.hero` (40pt). Layar lain
/// sengaja dibuat lebih tenang supaya tidak mencuri perhatian dari sini.
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
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transaksi Berhasil'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.spaceSm,
              AppSizes.screenPadding,
              AppSizes.spaceLg,
            ),
            children: [
              AppCard(
                elevated: true,
                padding: const EdgeInsets.all(AppSizes.spaceMl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: _SuccessMark()),
                    const SizedBox(height: AppSizes.spaceMd),
                    Text(
                      'Pembayaran berhasil disimpan',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSizes.spaceSm),
                    Center(
                      child: AppPill(
                        label: 'Struk ${sale.invoiceNumber}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceLg),
                    _HeroAmount(sale: sale),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spaceXl),
              const SectionHeader(
                title: 'Struk digital',
                subtitle: 'Bagikan ke pembeli lewat WhatsApp, atau simpan '
                    'sebagai gambar.',
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Center(
                  child: RepaintBoundary(
                    key: _receiptKey,
                    child: ReceiptWidget(sale: sale),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : _shareAsText,
                      icon: const Icon(Icons.text_snippet_outlined, size: AppSizes.iconSm),
                      label: const Text('Bagikan Teks'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : _shareAsImage,
                      icon: const Icon(Icons.image_outlined, size: AppSizes.iconSm),
                      label: const Text('Bagikan Gambar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceLg),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  boxShadow: AppShadows.of(context).primaryGlow,
                ),
                child: SizedBox(
                  height: AppSizes.buttonHeightLarge,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.point_of_sale_rounded, size: AppSizes.iconMd),
                    label: const Text('Transaksi Baru'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centang perayaan — muncul dengan skala+fade singkat (`AppDurations.slow`,
/// `easeOutCubic`). Sekali jalan, tanpa loop: perayaan yang terasa, bukan
/// yang menahan kasir.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(scale: 0.85 + (0.15 * value), child: child),
      ),
      child: const AppIconBadge(
        icon: Icons.check_rounded,
        tone: AppTone.success,
        size: AppIconBadgeSize.xl,
        filled: true,
      ),
    );
  }
}

/// Blok angka utama layar sukses. Yang ditonjolkan berbeda per metode:
/// tunai → **kembalian** (yang harus segera diserahkan), non-tunai & hutang
/// → **total**.
class _HeroAmount extends StatelessWidget {
  const _HeroAmount({required this.sale});

  final SaleResult sale;

  @override
  Widget build(BuildContext context) {
    final isCash = sale.paymentMethod == 'cash';
    final isDebt = sale.paymentMethod == 'debt';

    final heroLabel = isCash
        ? 'KEMBALIAN'
        : isDebt
        ? 'TOTAL HUTANG'
        : 'TOTAL DIBAYAR';
    final heroValue = isCash ? sale.changeAmount : sale.total;
    final heroColor = isCash
        ? context.palette.successText
        : isDebt
        ? context.palette.accentText
        : context.palette.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heroLabel, style: context.textStyles.eyebrow, textAlign: TextAlign.center),
        const SizedBox(height: AppSizes.spaceXs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AppMoneyText(
            CurrencyFormatter.format(heroValue),
            size: AppMoneySize.hero,
            color: heroColor,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMd),
        AppCard(
          color: context.palette.surfaceAlt,
          radius: AppSizes.radiusMd,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceMd,
            vertical: AppSizes.spaceSm,
          ),
          child: Column(
            children: [
              AppKeyValueRow(
                label: 'Total belanja',
                value: CurrencyFormatter.format(sale.total),
              ),
              if (isCash)
                AppKeyValueRow(
                  label: 'Uang diterima',
                  value: CurrencyFormatter.format(sale.paidAmount),
                ),
              if (isDebt)
                AppKeyValueRow(
                  label: 'Atas nama',
                  value: sale.customerName ?? '-',
                ),
            ],
          ),
        ),
        if (!isCash) ...[
          const SizedBox(height: AppSizes.spaceMs),
          Center(
            child: isDebt
                ? const AppPill(
                    label: 'Belum lunas',
                    tone: AppTone.accent,
                    icon: Icons.schedule_rounded,
                  )
                : const AppPill(
                    label: 'Non-tunai',
                    tone: AppTone.info,
                    icon: Icons.qr_code_2_rounded,
                  ),
          ),
        ],
      ],
    );
  }
}
