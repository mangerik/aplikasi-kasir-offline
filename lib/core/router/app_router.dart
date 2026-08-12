import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/license/providers/license_providers.dart';
import '../../features/license/screens/activation_screen.dart';
import '../../features/license/screens/license_expired_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/products/screens/product_form_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../license/license_status.dart';
import '../widgets/main_shell.dart';

/// Path route level-atas, dipakai juga oleh navigasi bawah di [MainShell].
abstract final class AppRoutes {
  static const String pos = '/kasir';
  static const String products = '/produk';
  static const String transactions = '/riwayat';
  static const String reports = '/laporan';
  static const String settings = '/pengaturan';

  /// Gerbang aktivasi — DI LUAR shell, navigasi bawah tidak tampil.
  static const String activation = '/aktivasi';

  /// Layar "masa coba berakhir" — juga di luar shell.
  static const String licenseExpired = '/lisensi-berakhir';
}

/// Gerbang lisensi di lapisan router (K-6.9, AC-6.1).
///
/// Sengaja **bukan** sekadar menyembunyikan layar: penjagaan di UI bisa
/// dilewati dengan navigasi langsung / deep link, sedangkan `redirect`
/// berlaku untuk semua jalan masuk sekaligus.
///
/// Kembalian `null` berarti "biarkan lewat".
///
/// Urutan gerbang bila §8 (multi-user) kelak aktif: **lisensi → masuk →
/// shell**; fungsi ini adalah gerbang pertamanya.
String? licenseRedirect(LicenseState state, String location) {
  switch (state) {
    case LicenseState.belumAktif:
      return location == AppRoutes.activation ? null : AppRoutes.activation;
    case LicenseState.kedaluwarsaTrial:
      // Rute `/aktivasi` sengaja IKUT dialihkan: layar aktivasi tetap bisa
      // dibuka dari sini, tapi lewat tombol "Masukkan Kode Aktivasi" yang
      // menumpuknya sebagai halaman biasa di atas layar ini. Dengan begitu
      // pembeli selalu punya jalan kembali, dan gerbangnya tidak bisa
      // "nyangkut" di layar aktivasi saat keadaan berubah.
      return location == AppRoutes.licenseExpired
          ? null
          : AppRoutes.licenseExpired;
    case LicenseState.aktif:
    case LicenseState.akanBerakhir:
    case LicenseState.masaTenggang:
    case LicenseState.kedaluwarsaTahunan:
      // Lisensi tahunan yang habis TIDAK mengunci seluruh aplikasi — hanya
      // layar Kasir (AC-6.14). Yang dikunci adalah kemampuan berjualan,
      // bukan datanya.
      if (location == AppRoutes.activation ||
          location == AppRoutes.licenseExpired) {
        return AppRoutes.pos;
      }
      return null;
  }
}

/// Konfigurasi navigasi aplikasi: gerbang lisensi di luar shell, lalu shell
/// dengan 5 tab bawah (Kasir · Produk · Riwayat · Laporan · Pengaturan),
/// lihat architecture.md §3 dan plan.md Milestone 0.
///
/// Dibuat lewat provider (bukan singleton top-level) supaya `redirect`
/// punya akses ke keadaan lisensi, dan supaya setiap `ProviderScope` —
/// termasuk tiap widget test — mendapat router bersih tanpa kebocoran
/// lokasi navigasi antar test.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final gate = ref.watch(licenseGateProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.pos,
    refreshListenable: gate,
    redirect: (context, state) =>
        licenseRedirect(gate.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.activation,
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: AppRoutes.licenseExpired,
        builder: (context, state) => const LicenseExpiredScreen(),
      ),
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
  ref.onDispose(router.dispose);
  return router;
});
