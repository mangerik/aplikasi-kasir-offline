import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../providers/held_cart_providers.dart';
import '../widgets/cart_panel.dart';
import '../widgets/cart_summary_bar.dart';
import '../widgets/product_grid.dart';
import 'held_carts_screen.dart';

/// Layar Kasir (POS) — adaptif HP/tablet (plan.md Milestone 2 poin 2 & 3,
/// architecture.md §5.1):
/// - **HP (portrait, < 600dp):** grid produk di atas, bar keranjang ringkas
///   menempel di bawah; tap bar membuka sheet keranjang penuh.
/// - **Tablet (>= 600dp):** dua panel berdampingan — grid produk kiri,
///   keranjang kanan (selalu terlihat).
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldCount = ref.watch(heldCartListProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Transaksi ditahan',
                icon: const Icon(Icons.pause_circle_outline),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const HeldCartsScreen())),
              ),
              if (heldCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$heldCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= AppSizes.tabletBreakpoint;
            if (isTablet) {
              return const Row(
                children: [
                  Expanded(flex: 3, child: ProductGrid()),
                  VerticalDivider(width: 1),
                  SizedBox(width: 400, child: CartPanel()),
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
    );
  }
}
