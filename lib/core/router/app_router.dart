import 'package:go_router/go_router.dart';

import '../../features/pos/screens/pos_screen.dart';
import '../../features/products/screens/product_form_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../widgets/main_shell.dart';

/// Path route level-atas, dipakai juga oleh navigasi bawah di [MainShell].
abstract final class AppRoutes {
  static const String pos = '/kasir';
  static const String products = '/produk';
  static const String transactions = '/riwayat';
  static const String reports = '/laporan';
  static const String settings = '/pengaturan';
}

/// Konfigurasi navigasi aplikasi: shell dengan 5 tab bawah
/// (Kasir · Produk · Riwayat · Laporan · Pengaturan), lihat architecture.md
/// §3 dan plan.md Milestone 0.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.pos,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.pos,
              builder: (context, state) => const PosScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.products,
              builder: (context, state) => const ProductsScreen(),
              routes: [
                GoRoute(
                  path: 'tambah',
                  builder: (context, state) => const ProductFormScreen(),
                ),
                GoRoute(
                  path: ':id/ubah',
                  builder: (context, state) => ProductFormScreen(
                    productId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.transactions,
              builder: (context, state) => const TransactionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.reports,
              builder: (context, state) => const ReportsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
