import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../license/providers/license_providers.dart';
import '../../license/widgets/license_banner.dart';
import '../providers/held_cart_providers.dart';
import '../widgets/cart_panel.dart';
import '../widgets/cart_summary_bar.dart';
import '../widgets/product_grid.dart';
import 'held_carts_screen.dart';

/// Layar Kasir (POS) — adaptif HP/tablet (plan.md Milestone 2 poin 2 & 3,
/// architecture.md §5.1):
/// - **HP (portrait, < 600dp):** grid produk di atas, bar keranjang
///   mengambang menempel di bawah (zona jempol); tap bar membuka sheet
///   keranjang penuh.
/// - **Tablet (>= 600dp):** dua panel berdampingan — grid produk kiri,
///   keranjang kanan di atas permukaan `surface` (selalu terlihat).
///
/// Desain mengikuti `docs/ui-redesign-foundation.md`: aksi utama (Bayar)
/// selalu di sepertiga bawah layar, nominal memakai `AppMoneyText`, dan
/// transaksi ditahan tampil sebagai pil aksen — bukan badge titik kecil
/// yang mudah terlewat.
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  /// Lebar panel keranjang di tablet — cukup untuk nama produk + stepper
  /// qty + nominal tanpa membuat grid produk sempit.
  static const double _cartPanelWidth = 380;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldCount = ref.watch(heldCartListProvider).value?.length ?? 0;
    // Lisensi tahunan yang lewat masa tenggang mengunci KEMAMPUAN BERJUALAN,
    // bukan datanya (PRD v1.1 §6.3.E, AC-6.14). Gerbangnya sengaja di sini,
    // bukan di `SaveSaleUsecase`: sheet pembayaran hidup di route DI ATAS
    // layar ini, sehingga transaksi yang sedang berjalan tetap boleh
    // diselesaikan sampai tersimpan — K-6.10, AC-6.18.
    final canSell = ref.watch(licenseStatusProvider).state.canSell;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          _HeldCartsAction(count: heldCount),
          const SizedBox(width: AppSizes.spaceMd),
        ],
      ),
      body: SafeArea(
        top: false,
        child: canSell ? const _PosBody() : const PosLockedView(),
      ),
    );
  }
}

/// Isi layar Kasir saat lisensi masih mengizinkan berjualan.
class _PosBody extends StatelessWidget {
  const _PosBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LicenseBanner(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet =
                  constraints.maxWidth >= AppSizes.tabletBreakpoint;
              if (isTablet) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: ProductGrid()),
                    VerticalDivider(width: AppSizes.hairline),
                    SizedBox(
                      width: PosScreen._cartPanelWidth,
                      child: ColoredBox(
                        color: context.palette.surface,
                        child: CartPanel(),
                      ),
                    ),
                  ],
                );
              }
              return const Column(
                children: [
                  Expanded(child: ProductGrid()),
                  CartSummaryBar(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pintasan ke daftar transaksi ditahan.
///
/// Saat ada transaksi diparkir, tombol berubah jadi **pil aksen berlabel
/// angka** (bukan sekadar ikon + titik) supaya kasir langsung tahu ada
/// pekerjaan yang menunggu — satu-satunya elemen aksen di layar ini
/// (fondasi §2.2: aksen dipakai hemat).
class _HeldCartsAction extends StatelessWidget {
  const _HeldCartsAction({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HeldCartsScreen()));

    if (count == 0) {
      return IconButton(
        tooltip: 'Transaksi ditahan',
        icon: const Icon(Icons.pause_circle_outline),
        onPressed: open,
      );
    }

    return Tooltip(
      message: 'Transaksi ditahan',
      child: SizedBox(
        height: AppSizes.minTouchTarget - 4,
        child: AppCard(
          onTap: open,
          radius: AppSizes.radiusPill,
          color: context.palette.accent50,
          borderColor: context.palette.accent100,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceMs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pause_circle_filled_rounded,
                size: AppSizes.iconSm,
                color: context.palette.accentText,
              ),
              const SizedBox(width: AppSizes.spaceXs + 2),
              Text(
                '$count ditahan',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.palette.accentText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
