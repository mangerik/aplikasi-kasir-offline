import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/constants/app_palette.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/repositories/customer_repository_impl.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/data/repositories/settings_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/entities/points_settings.dart';
import 'package:kasir_warung/features/customers/screens/customer_detail_screen.dart';
import 'package:kasir_warung/features/customers/screens/customers_screen.dart';
import 'package:kasir_warung/core/constants/app_theme.dart';
import 'package:kasir_warung/features/settings/providers/theme_providers.dart';

/// Smoke test layar Pelanggan & detailnya (PRD v1.1 §7.3.A, §7.6).
///
/// Fokusnya sama dengan smoke test area lain: layar benar-benar ter-render
/// di HP sempit (392dp) dengan data nyata, TANPA overflow — dan elemen
/// poin benar-benar hilang saat programnya mati (AC-7.6).
void main() {
  late AppDatabase db;

  setUpAll(() async => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Widget buildScreen(Widget screen, {ThemeMode mode = ThemeMode.light}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        themeModeStoreProvider.overrideWithValue(InMemoryThemeModeStore(mode)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: screen,
      ),
    );
  }

  Future<void> seed({required bool pointsEnabled}) async {
    final customers = CustomerRepositoryImpl(db);
    final sales = SaleRepositoryImpl(db);
    final settings = SettingsRepositoryImpl(db);

    if (pointsEnabled) {
      await settings.setValue(PointsSettings.keyEnabled, '1');
    }

    final ani = await customers.create(
      name: 'Bu Sri Rahayu Wijayanti',
      phone: '081234567890',
    );
    await customers.create(name: 'Pak Joko');

    await sales.saveSale(
      items: [
        const CartItem(
          key: 'bebas',
          name: 'Beras 5kg Premium Cap Bunga',
          unit: 'sak',
          qty: 1,
          sellPrice: 125000,
        ),
      ],
      transactionDiscount: 0,
      paymentMethod: 'debt',
      paidAmount: 0,
      customerName: 'Bu Sri Rahayu Wijayanti',
      customerId: ani.id,
      points: pointsEnabled
          ? const PointsSettings(enabled: true)
          : const PointsSettings(),
    );
  }

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('daftar pelanggan & filter "Punya hutang" ter-render di HP',
      (tester) async {
    setPhoneSize(tester);
    await seed(pointsEnabled: true);

    await tester.pumpWidget(buildScreen(const CustomersScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(CustomersScreen), findsOneWidget);
    expect(find.text('Bu Sri Rahayu Wijayanti'), findsOneWidget);
    expect(find.text('Pak Joko'), findsOneWidget);
    // Saldo poin tampil karena programnya menyala.
    expect(find.textContaining('poin'), findsWidgets);

    await tester.tap(find.text('Punya hutang'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL HUTANG BERJALAN'), findsOneWidget);
    expect(find.text('Pak Joko'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('AC-7.6: program poin mati → tidak ada elemen poin di layar '
      'Pelanggan maupun detailnya', (tester) async {
    setPhoneSize(tester);
    await seed(pointsEnabled: false);

    await tester.pumpWidget(buildScreen(const CustomersScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('poin'), findsNothing);
    expect(find.textContaining('Poin'), findsNothing);

    await tester.tap(find.text('Bu Sri Rahayu Wijayanti'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerDetailScreen), findsOneWidget);
    expect(find.text('SALDO POIN'), findsNothing);
    expect(find.text('Buku Besar Poin'), findsNothing);
    // Ringkasan non-poin tetap ada.
    expect(find.text('TOTAL BELANJA'), findsOneWidget);
    expect(find.text('SISA HUTANG'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('detail pelanggan menampilkan ringkasan, riwayat belanja, '
      'dan buku besar poin saat program menyala', (tester) async {
    setPhoneSize(tester);
    await seed(pointsEnabled: true);

    await tester.pumpWidget(buildScreen(const CustomersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu Sri Rahayu Wijayanti'));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL BELANJA'), findsOneWidget);
    expect(find.text('JUMLAH TRANSAKSI'), findsOneWidget);
    expect(find.text('SALDO POIN'), findsOneWidget);
    expect(find.text('Buku Besar Poin'), findsOneWidget);
    expect(find.text('Dapat poin'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('layar Pelanggan memakai palet gelap saat mode gelap (AC-5.6)',
      (tester) async {
    setPhoneSize(tester);
    await seed(pointsEnabled: true);

    await tester.pumpWidget(
      buildScreen(const CustomersScreen(), mode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    final ctx = tester.element(
      find
          .descendant(
            of: find.byType(CustomersScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(
      Theme.of(ctx).scaffoldBackgroundColor,
      const AppPalette.dark().background,
    );

    await disposeApp(tester);
  });
}
