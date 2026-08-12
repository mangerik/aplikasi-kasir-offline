import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/license/license_status.dart';
import 'package:kasir_warung/core/router/app_router.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/core/widgets/main_shell.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/features/license/providers/license_providers.dart';
import 'package:kasir_warung/features/license/providers/license_store.dart';

import '../../fixtures/license_vectors.dart';

/// Gerbang lisensi di lapisan router (K-6.9, AC-6.1, AC-6.14).
///
/// Yang diuji di sini bukan "layarnya tampil", melainkan **penjagaan di
/// router**: menyembunyikan layar bisa dilewati lewat navigasi langsung,
/// `redirect` tidak.
void main() {
  late AppDatabase db;

  setUpAll(() async => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('licenseRedirect (fungsi murni)', () {
    const guarded = [
      AppRoutes.pos,
      AppRoutes.products,
      AppRoutes.transactions,
      AppRoutes.reports,
      AppRoutes.settings,
    ];

    test('belum aktif → SELURUH rute dialihkan ke /aktivasi (AC-6.1)', () {
      for (final route in guarded) {
        expect(
          licenseRedirect(LicenseState.belumAktif, route),
          AppRoutes.activation,
          reason: route,
        );
      }
      expect(
        licenseRedirect(LicenseState.belumAktif, AppRoutes.activation),
        isNull,
      );
    });

    test('trial habis → seluruh rute dialihkan ke /lisensi-berakhir, '
        'kecuali layar aktivasi', () {
      for (final route in guarded) {
        expect(
          licenseRedirect(LicenseState.kedaluwarsaTrial, route),
          AppRoutes.licenseExpired,
          reason: route,
        );
      }
      expect(
        licenseRedirect(
          LicenseState.kedaluwarsaTrial,
          AppRoutes.licenseExpired,
        ),
        isNull,
      );
      // `/aktivasi` pun dialihkan: layar aktivasi dibuka sebagai halaman
      // BERTUMPUK dari sana, bukan sebagai rute gerbang, supaya pembeli
      // selalu punya jalan kembali.
      expect(
        licenseRedirect(LicenseState.kedaluwarsaTrial, AppRoutes.activation),
        AppRoutes.licenseExpired,
      );
    });

    test('tahunan habis TIDAK mengunci rute mana pun — Riwayat, Laporan & '
        'Pengaturan tetap terbuka (AC-6.14)', () {
      for (final route in guarded) {
        expect(
          licenseRedirect(LicenseState.kedaluwarsaTahunan, route),
          isNull,
          reason: route,
        );
      }
    });

    test('aktif → layar gerbang tidak bisa "nyangkut"', () {
      for (final state in [
        LicenseState.aktif,
        LicenseState.akanBerakhir,
        LicenseState.masaTenggang,
      ]) {
        expect(licenseRedirect(state, AppRoutes.activation), AppRoutes.pos);
        expect(licenseRedirect(state, AppRoutes.licenseExpired), AppRoutes.pos);
        expect(licenseRedirect(state, AppRoutes.reports), isNull);
      }
    });
  });

  group('gerbang di aplikasi sungguhan', () {
    Widget buildApp({String? token}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          licenseStoreProvider.overrideWithValue(
            InMemoryLicenseStore(token: token),
          ),
          licenseBootstrapProvider.overrideWithValue(
            LicenseStatus.belumAktif(referenceTime: DateTime.now()),
          ),
        ],
        child: const KasirApp(),
      );
    }

    /// Layar gerbang lebih tinggi daripada viewport uji bawaan (800x600) dan
    /// `ListView` membangun anaknya secara malas — tanpa ini, tombol di
    /// bagian bawah layar belum pernah lahir saat test mencarinya.
    void useTallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    Future<void> disposeApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    }

    testWidgets('pemasangan baru: frame pertama sudah layar Aktivasi, dock '
        'navigasi TIDAK tampil', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Aktifkan Kasir Warung'), findsOneWidget);
      expect(find.byKey(MainShell.dockKey), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('navigasi langsung ke /laporan tetap dipulangkan ke '
        '/aktivasi (AC-6.1)', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Navigasi langsung lewat GoRouter, meniru deep link.
      final context = tester.element(find.text('Aktifkan Kasir Warung'));
      GoRouter.of(context).go(AppRoutes.reports);
      await tester.pumpAndSettle();

      expect(find.text('Aktifkan Kasir Warung'), findsOneWidget);
      expect(find.byKey(MainShell.dockKey), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('token lifetime tersimpan → aplikasi terbuka normal setelah '
        'evaluasi ulang', (tester) async {
      await tester.pumpWidget(buildApp(token: kVectorLifetime));
      // Evaluasi ulang pasca-frame-pertama (verifikasi Ed25519 asinkron).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(MainShell.dockKey), findsOneWidget);
      expect(find.text('Aktifkan Kasir Warung'), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('trial yang sudah habis → layar ajakan beli dengan tombol '
        '"Cadangkan Data" (AC-6.15)', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(buildApp(token: kVectorTrialExpired));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.text('Masa coba 3 hari sudah berakhir'), findsOneWidget);
      expect(find.text('Cadangkan Data'), findsOneWidget);
      expect(find.text('Masukkan Kode Aktivasi'), findsOneWidget);
      // Nada menenangkan, bukan menghukum.
      expect(find.textContaining('masih tersimpan aman'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('tahunan lewat tenggang → layar Kasir terkunci TAPI dock '
        'navigasi tetap ada & berfungsi (AC-6.14)', (tester) async {
      await tester.pumpWidget(buildApp(token: kVectorYearlyExpired));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(MainShell.dockKey), findsOneWidget);
      expect(find.text('Lisensi sudah berakhir'), findsWidgets);

      // Riwayat masih bisa dibuka — data tidak pernah disandera.
      await tester.tap(
        find.descendant(
          of: find.byKey(MainShell.dockKey),
          matching: find.text('Riwayat'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StatefulNavigationShell>(
              find.byType(StatefulNavigationShell),
            )
            .currentIndex,
        2,
      );

      await disposeApp(tester);
    });
  });
}
