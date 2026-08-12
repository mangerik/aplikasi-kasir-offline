import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/app_user.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/access_denied_screen.dart';
import '../../features/auth/screens/login_screen.dart';
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

  /// Gerbang masuk multi-user (pilih nama → PIN) — di luar shell.
  static const String login = '/masuk';

  /// Penolakan akses untuk Kasir yang menabrak batas izin — di luar shell.
  static const String accessDenied = '/akses-ditolak';

  /// Rute yang HANYA boleh dibuka Pemilik (PRD v1.1 §8.3.C).
  ///
  /// Daftar ini adalah penjagaan sesungguhnya (AC-8.4): menyembunyikan
  /// tombol saja bisa dilewati lewat deep link, `go()` langsung, atau
  /// tautan dari layar lain — `redirect` berlaku untuk semua jalan masuk
  /// sekaligus.
  ///
  /// `/pengaturan` sengaja TIDAK di sini: Kasir tetap boleh membukanya
  /// untuk mengubah tema (§8.3.C "kecuali tema"); isi kartunya sendiri
  /// yang menyesuaikan peran.
  static bool isOwnerOnly(String location) {
    if (location == reports || location.startsWith('$reports/')) return true;
    // Tambah/ubah produk & harga — daftar produknya sendiri tetap terbuka
    // karena kasir butuh melihat barang untuk berjualan.
    if (location.startsWith('$products/')) return true;
    return false;
  }
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

/// Keadaan gerbang masuk & izin, dalam bentuk yang bisa dibaca `redirect`
/// secara **sinkron** (PRD v1.1 §8.6, AC-8.4).
@immutable
class AuthGateState {
  const AuthGateState({required this.needsLogin, required this.role});

  final bool needsLogin;
  final UserRole role;

  @override
  bool operator ==(Object other) =>
      other is AuthGateState &&
      other.needsLogin == needsLogin &&
      other.role == role;

  @override
  int get hashCode => Object.hash(needsLogin, role);
}

/// Gerbang MASUK & IZIN di lapisan router — jalan kedua setelah lisensi.
///
/// Urutan gerbangnya: **lisensi → masuk → izin peran → shell**.
///
/// Penjagaan izin sengaja ada di sini DAN di UI (§8.6). UI yang
/// menyembunyikan tombol menjaga pengalaman; `redirect` yang menolak rute
/// menjaga datanya — dan hanya yang kedua yang tidak bisa dilewati lewat
/// deep link atau navigasi langsung (AC-8.4).
String? authRedirect(AuthGateState gate, String location) {
  if (gate.needsLogin) {
    return location == AppRoutes.login ? null : AppRoutes.login;
  }
  if (location == AppRoutes.login) return AppRoutes.pos;

  if (!gate.role.isOwner && AppRoutes.isOwnerOnly(location)) {
    return AppRoutes.accessDenied;
  }
  // Pemilik tidak pernah perlu melihat layar penolakan (mis. setelah
  // "Masuk sebagai Pemilik" dari layar itu sendiri).
  if (location == AppRoutes.accessDenied && gate.role.isOwner) {
    return AppRoutes.pos;
  }
  return null;
}

/// Jembatan [SessionState] → `Listenable` untuk `GoRouter.refreshListenable`
/// — pola yang sama dengan `licenseGateProvider`.
final Provider<ValueNotifier<AuthGateState>> authGateProvider =
    Provider<ValueNotifier<AuthGateState>>((ref) {
  AuthGateState read(SessionState session) => AuthGateState(
        needsLogin: session.needsLogin,
        role: session.role,
      );
  final notifier = ValueNotifier<AuthGateState>(read(ref.read(sessionProvider)));
  ref.listen<SessionState>(sessionProvider, (previous, next) {
    notifier.value = read(next);
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

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
  final authGate = ref.watch(authGateProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.pos,
    refreshListenable: Listenable.merge([gate, authGate]),
    redirect: (context, state) {
      final location = state.matchedLocation;
      // Lisensi lebih dulu: aplikasi yang belum diaktifkan tidak boleh
      // menampilkan layar Masuk (dan sebaliknya, gerbang masuk tidak boleh
      // menyandera layar aktivasi).
      final licenseTarget = licenseRedirect(gate.value, location);
      if (licenseTarget != null) return licenseTarget;
      return authRedirect(authGate.value, location);
    },
    routes: [
      GoRoute(
        path: AppRoutes.activation,
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: AppRoutes.licenseExpired,
        builder: (context, state) => const LicenseExpiredScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessDenied,
        builder: (context, state) => const AccessDeniedScreen(),
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
