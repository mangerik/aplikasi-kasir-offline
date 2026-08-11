import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inventory/providers/stock_providers.dart';

/// Kerangka navigasi utama: 5 tab bawah (Kasir · Produk · Riwayat · Laporan ·
/// Pengaturan) yang tetap menjaga state tiap tab lewat
/// [StatefulShellRoute.indexedStack] (lihat `lib/app.dart`).
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tap ulang tab yang sedang aktif -> kembali ke root tab tsb.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Badge jumlah produk stok menipis di tab Produk (plan.md Milestone 4
    // poin 3) — stream reaktif, otomatis ter-update tiap ada perubahan stok.
    final lowStockCount = ref.watch(lowStockCountProvider).value ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: lowStockCount,
              isLabelVisible: lowStockCount > 0,
              child: const Icon(Icons.inventory_2_outlined),
            ),
            selectedIcon: Badge.count(
              count: lowStockCount,
              isLabelVisible: lowStockCount > 0,
              child: const Icon(Icons.inventory_2),
            ),
            label: 'Produk',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
