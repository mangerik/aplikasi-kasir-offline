import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/router/app_router.dart';
import 'package:kasir_warung/domain/entities/app_user.dart';

/// Gerbang MASUK & IZIN di lapisan router (PRD v1.1 §8.6, AC-8.4).
///
/// Diuji sebagai fungsi murni supaya setiap rute bisa dicoba satu per satu
/// — termasuk rute yang TIDAK punya tombol di UI Kasir. Justru rute
/// semacam itulah yang harus dibuktikan tertutup: menyembunyikan tombol
/// bukan penjagaan.
void main() {
  const owner = AuthGateState(needsLogin: false, role: UserRole.owner);
  const cashier = AuthGateState(needsLogin: false, role: UserRole.cashier);
  const loggedOut = AuthGateState(needsLogin: true, role: UserRole.cashier);

  group('gerbang masuk', () {
    test('belum masuk → seluruh rute dialihkan ke layar Masuk', () {
      for (final location in [
        AppRoutes.pos,
        AppRoutes.products,
        AppRoutes.transactions,
        AppRoutes.reports,
        AppRoutes.settings,
        '${AppRoutes.products}/tambah',
      ]) {
        expect(authRedirect(loggedOut, location), AppRoutes.login);
      }
    });

    test('layar Masuk sendiri tidak dialihkan (tidak "nyangkut")', () {
      expect(authRedirect(loggedOut, AppRoutes.login), isNull);
    });

    test('sudah masuk → layar Masuk dikembalikan ke Kasir', () {
      expect(authRedirect(owner, AppRoutes.login), AppRoutes.pos);
      expect(authRedirect(cashier, AppRoutes.login), AppRoutes.pos);
    });
  });

  group('AC-8.4: rute Pemilik ditolak untuk Kasir', () {
    test('Laporan ditolak walau dibuka langsung (deep link)', () {
      expect(authRedirect(cashier, AppRoutes.reports), AppRoutes.accessDenied);
      expect(
        authRedirect(cashier, '${AppRoutes.reports}/detail'),
        AppRoutes.accessDenied,
      );
    });

    test('tambah/ubah produk ditolak, daftar produk tetap terbuka', () {
      expect(
        authRedirect(cashier, '${AppRoutes.products}/tambah'),
        AppRoutes.accessDenied,
      );
      expect(
        authRedirect(cashier, '${AppRoutes.products}/7/ubah'),
        AppRoutes.accessDenied,
      );
      expect(authRedirect(cashier, AppRoutes.products), isNull);
    });

    test('pekerjaan harian Kasir tidak pernah dihalangi', () {
      for (final location in [
        AppRoutes.pos,
        AppRoutes.products,
        AppRoutes.transactions,
        // Pengaturan tetap terbuka untuk tema (§8.3.C "kecuali tema");
        // isinya yang menyesuaikan peran.
        AppRoutes.settings,
      ]) {
        expect(authRedirect(cashier, location), isNull, reason: location);
      }
    });

    test('Pemilik tidak pernah ditolak', () {
      for (final location in [
        AppRoutes.pos,
        AppRoutes.products,
        '${AppRoutes.products}/tambah',
        AppRoutes.transactions,
        AppRoutes.reports,
        AppRoutes.settings,
      ]) {
        expect(authRedirect(owner, location), isNull, reason: location);
      }
    });

    test('layar penolakan bisa dibuka Kasir, tapi tidak menahan Pemilik', () {
      expect(authRedirect(cashier, AppRoutes.accessDenied), isNull);
      expect(authRedirect(owner, AppRoutes.accessDenied), AppRoutes.pos);
    });
  });

  group('matriks izin §8.3.C (K-8.1: tetap, tidak bisa dikustomisasi)', () {
    test('Pemilik boleh semuanya', () {
      const role = UserRole.owner;
      expect(role.canViewReports, isTrue);
      expect(role.canSeeProfit, isTrue);
      expect(role.canVoidSale, isTrue);
      expect(role.canManageProducts, isTrue);
      expect(role.canManageData, isTrue);
      expect(role.canManageSettings, isTrue);
      expect(role.canSeeAllHistory, isTrue);
      expect(role.canSell, isTrue);
      expect(role.canAdjustStock, isTrue);
    });

    test('Kasir: jualan penuh, uang & pengaturan tertutup', () {
      const role = UserRole.cashier;
      expect(role.canSell, isTrue);
      expect(role.canAdjustStock, isTrue, reason: 'tercatat atas namanya');
      expect(role.canViewReports, isFalse);
      expect(role.canSeeProfit, isFalse);
      expect(role.canVoidSale, isFalse);
      expect(role.canManageProducts, isFalse);
      expect(role.canManageData, isFalse);
      expect(role.canManageSettings, isFalse);
      expect(role.canSeeAllHistory, isFalse);
    });

    test('peran asing di database diperlakukan sebagai Kasir (paling '
        'terbatas)', () {
      expect(UserRole.fromDb('supervisor'), UserRole.cashier);
      expect(UserRole.fromDb(null), UserRole.cashier);
      expect(UserRole.fromDb('owner'), UserRole.owner);
    });
  });

  group('AppUser', () {
    AppUser user(String name) => AppUser(
          id: 1,
          name: name,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('inisial maksimal dua huruf', () {
      expect(user('Bu Ani').initials, 'BA');
      expect(user('Pemilik').initials, 'P');
      expect(user('ani suryani wati').initials, 'AS');
    });

    test('nama pendek untuk chip AppBar', () {
      expect(user('Pemilik').shortName, 'Pemilik');
      expect(user('Ani Suryani').shortName, 'Ani S.');
    });
  });
}
