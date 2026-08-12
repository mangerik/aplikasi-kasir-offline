import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inventory/providers/stock_providers.dart';
import '../../features/transactions/utils/pin_gate.dart';
import '../constants/app_palette.dart';
import '../constants/app_shadows.dart';
import '../constants/app_sizes.dart';
import '../constants/app_typography.dart';

/// Kerangka navigasi utama: 5 tab (Kasir · Produk · Riwayat · Laporan ·
/// Setelan) yang tetap menjaga state tiap tab lewat
/// [StatefulShellRoute.indexedStack] (lihat `lib/core/router/app_router.dart`).
///
/// Navigasinya BUKAN [NavigationBar] bawaan Material, melainkan **dock
/// mengambang** khas aplikasi ini: kartu putih hangat dengan sudut 24,
/// shadow lembut bernada cokelat, dan kapsul hijau yang bergeser halus ke
/// tab aktif. Tujuannya dua: memberi identitas visual, dan memperbesar
/// target sentuh (tiap tab setinggi 46dp penuh, di zona jempol).
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Key kartu dock — dipakai widget test untuk menemukan navigasi tanpa
  /// bergantung pada tipe widget internal.
  static const Key dockKey = Key('mainNavDock');

  /// Index tab yang DILINDUNGI kunci PIN (plan.md Milestone 5 poin 6,
  /// architecture.md §5.4: "Mengunci akses ke: Laporan, Pengaturan").
  /// Kasir/Produk/Riwayat tetap terbuka tanpa PIN.
  static const Set<int> _pinProtectedIndexes = {3, 4};

  static const List<_NavSpec> _destinations = [
    _NavSpec(
      label: 'Kasir',
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale,
    ),
    _NavSpec(
      label: 'Produk',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
    ),
    _NavSpec(
      label: 'Riwayat',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
    ),
    _NavSpec(
      label: 'Laporan',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
    ),
    _NavSpec(
      label: 'Setelan',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  Future<void> _onDestinationSelected(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    if (index != navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
    }
    if (_pinProtectedIndexes.contains(index)) {
      final allowed = await checkPinGate(context, ref);
      if (!allowed) return;
    }
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
    final currentIndex = navigationShell.currentIndex;
    final palette = context.palette;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: palette.background),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spaceMs,
              AppSizes.spaceSm,
              AppSizes.spaceMs,
              AppSizes.spaceSm,
            ),
            child: Container(
              key: dockKey,
              height: AppSizes.navDockHeight,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                border: Border.all(color: palette.border),
                boxShadow: AppShadows.of(context).level2,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        spec: _destinations[i],
                        selected: i == currentIndex,
                        badgeCount: i == 1 ? lowStockCount : 0,
                        onTap: () => _onDestinationSelected(context, ref, i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deskripsi satu tab.
@immutable
class _NavSpec {
  const _NavSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Satu tab di dalam dock: kapsul hijau + ikon + label.
///
/// Transisi kapsul & warna dianimasikan ([AppDurations.fast]) supaya
/// perpindahan tab terasa responsif, bukan "loncat".
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.primary : palette.inkSecondary;

    Widget icon = AnimatedSwitcher(
      duration: AppDurations.fast,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        selected ? spec.activeIcon : spec.icon,
        key: ValueKey(selected),
        size: 21,
        color: color,
      ),
    );

    if (badgeCount > 0) {
      icon = Badge.count(count: badgeCount, child: icon);
    }

    return Semantics(
      selected: selected,
      button: true,
      label: spec.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        splashColor: palette.primary.withValues(alpha: 0.07),
        highlightColor: palette.primary.withValues(alpha: 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              height: 26,
              width: selected ? 44 : 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? palette.primary50 : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: icon,
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
              child: Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
