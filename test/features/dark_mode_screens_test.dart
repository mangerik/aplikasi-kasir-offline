import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/constants/app_palette.dart';
import 'package:kasir_warung/core/constants/app_theme.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/repositories/customer_repository_impl.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/data/repositories/settings_repository_impl.dart';
import 'package:kasir_warung/data/repositories/user_repository_impl.dart';
import 'package:kasir_warung/domain/entities/app_user.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/entities/multi_user_settings.dart';
import 'package:kasir_warung/domain/entities/sale_result.dart';
import 'package:kasir_warung/features/auth/providers/session_store.dart';
import 'package:kasir_warung/features/auth/screens/access_denied_screen.dart';
import 'package:kasir_warung/features/auth/screens/recovery_code_screen.dart';
import 'package:kasir_warung/features/auth/screens/users_screen.dart';
import 'package:kasir_warung/features/customers/screens/customer_detail_screen.dart';
import 'package:kasir_warung/features/pos/screens/checkout_success_screen.dart';
import 'package:kasir_warung/features/pos/widgets/receipt_widget.dart';
import 'package:kasir_warung/features/products/screens/product_form_screen.dart';
import 'package:kasir_warung/features/settings/providers/theme_providers.dart';
import 'package:kasir_warung/features/settings/screens/pin_entry_screen.dart';
import 'package:kasir_warung/features/transactions/screens/sale_detail_screen.dart';
import 'package:kasir_warung/features/transactions/widgets/history_tile.dart';

/// Verifikasi mode gelap di tingkat layar (PRD v1.1 AC-5.7, AC-5.10,
/// AC-5.11).
///
/// Yang dikejar bukan "warnanya bagus" (itu urusan mata manusia), melainkan
/// tiga hal yang bisa salah diam-diam dan baru ketahuan di warung:
/// 1. **Pulau putih** — satu layar terlewat saat migrasi dan tetap memakai
///    kertas terang di tengah aplikasi gelap.
/// 2. **Struk ikut gelap** — struk keluar dari aplikasi (di-share sebagai
///    gambar, nanti dicetak); kertas tidak punya mode gelap.
/// 3. **Status hanya dibedakan warna** — pill wajib tetap membawa LABEL.
void main() {
  late AppDatabase db;

  const darkPalette = AppPalette.dark();

  setUpAll(() async => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> insertProduct(String name, int price) {
    final now = DateTime(2026, 8, 1).millisecondsSinceEpoch;
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            sellPrice: price,
            stock: const Value(50),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Widget buildApp({ThemeMode mode = ThemeMode.dark}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        themeModeStoreProvider.overrideWithValue(InMemoryThemeModeStore(mode)),
      ],
      child: const KasirApp(),
    );
  }

  /// Brightness tema yang berlaku DI DALAM struk — bukan di atasnya.
  /// `ReceiptWidget` memasang `Theme` sendiri, jadi `Theme.of` pada elemen
  /// widget-nya masih mengembalikan tema aplikasi.
  Brightness receiptBrightness(WidgetTester tester) {
    final theme = tester.widget<Theme>(
      find
          .descendant(
            of: find.byType(ReceiptWidget),
            matching: find.byType(Theme),
          )
          .first,
    );
    return theme.data.brightness;
  }

  /// Warna kanvas yang benar-benar dipakai layar teratas.
  Color scaffoldCanvas(WidgetTester tester, Finder screen) {
    final ctx = tester.element(
      find.descendant(of: screen, matching: find.byType(Scaffold)).first,
    );
    return Theme.of(ctx).scaffoldBackgroundColor;
  }

  /// Drift menjadwalkan Timer(Duration.zero) saat QueryStream di-cancel —
  /// sama seperti di `app_test.dart`, harus di-flush sebelum test berakhir.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('lima layar utama tampil bertema gelap tanpa "pulau putih" '
      '(AC-5.10)', (tester) async {
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await insertProduct('Teh Botol Sosro Kemasan', 5000);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    for (final tab in ['Kasir', 'Produk', 'Riwayat', 'Laporan', 'Setelan']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      expect(
        theme.brightness,
        Brightness.dark,
        reason: 'tab $tab tidak memakai tema gelap',
      );
      expect(
        theme.scaffoldBackgroundColor,
        darkPalette.background,
        reason: 'kanvas tab $tab bukan latar gelap "Kertas & Daun Malam"',
      );
      expect(
        theme.extension<AppPalette>()?.isDark,
        isTrue,
        reason: 'AppPalette gelap tidak terpasang di tab $tab',
      );
    }

    await disposeApp(tester);
  });

  testWidgets('kartu Tampilan mengubah seluruh aplikasi seketika, tanpa '
      'restart (AC-5.1)', (tester) async {
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(mode: ThemeMode.light));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Setelan').first);
    await tester.pumpAndSettle();

    expect(find.text('Tampilan'), findsOneWidget);
    // Tepat tiga pilihan, tidak lebih.
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Ikuti Sistem'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
      reason: 'memilih Gelap harus mengubah tema seketika',
    );

    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );

    await disposeApp(tester);
  });

  testWidgets('detail transaksi & pill status tetap berlabel di mode gelap '
      '(AC-5.10, AC-5.11)', (tester) async {
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final teh = await insertProduct('Teh Botol Sosro Kemasan', 5000);
    final repo = SaleRepositoryImpl(db);
    await repo.saveSale(
      items: [
        CartItem(
          key: 'p_$teh',
          productId: teh,
          name: 'Teh Botol Sosro Kemasan',
          unit: 'pcs',
          qty: 2,
          sellPrice: 5000,
        ),
      ],
      transactionDiscount: 0,
      paymentMethod: 'debt',
      paidAmount: 0,
      customerName: 'Bu Sri',
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat').first);
    await tester.pumpAndSettle();

    // Status dibedakan lewat LABEL, bukan cuma warna.
    expect(find.text('Hutang'), findsWidgets);

    await tester.tap(find.byType(HistoryTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(SaleDetailScreen), findsOneWidget);
    expect(
      scaffoldCanvas(tester, find.byType(SaleDetailScreen)),
      darkPalette.background,
    );

    // Pratinjau struk di dalam layar gelap TETAP kertas putih (AC-5.7).
    await tester.scrollUntilVisible(
      find.byType(ReceiptWidget),
      300,
      scrollable: find
          .descendant(
            of: find.byType(SaleDetailScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      receiptBrightness(tester),
      Brightness.light,
      reason: 'struk wajib dipaksa tema terang (K-5.3)',
    );

    await disposeApp(tester);
  });

  testWidgets('form produk & layar PIN tampil bertema gelap (AC-5.10)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produk').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(ProductFormScreen), findsOneWidget);
    expect(
      scaffoldCanvas(tester, find.byType(ProductFormScreen)),
      darkPalette.background,
    );

    await disposeApp(tester);
  });

  testWidgets('layar PIN memakai palet gelap (AC-5.10)', (tester) async {
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const PinEntryScreen(title: 'Masukkan PIN'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masukkan PIN'), findsOneWidget);
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, darkPalette.background);
  });

  testWidgets('layar sukses transaksi gelap, tapi struknya tetap kertas '
      'putih (AC-5.7, AC-5.10)', (tester) async {
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sale = SaleResult(
      saleId: 1,
      invoiceNumber: '20260812-0001',
      subtotal: 10000,
      discount: 0,
      total: 10000,
      paymentMethod: 'cash',
      paidAmount: 20000,
      changeAmount: 10000,
      createdAt: DateTime(2026, 8, 12, 10),
      items: const [
        SaleResultItem(
          productId: 1,
          name: 'Teh Botol',
          unit: 'pcs',
          qty: 2,
          sellPrice: 5000,
          discount: 0,
          lineTotal: 10000,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: CheckoutSuccessScreen(sale: sale),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      scaffoldCanvas(tester, find.byType(CheckoutSuccessScreen)),
      darkPalette.background,
    );

    await tester.scrollUntilVisible(
      find.byType(ReceiptWidget),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Struk: latar kertas putih & tinta hitam, tak peduli tema aplikasi.
    final paper = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ReceiptWidget),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(paper.color, ReceiptWidget.paper);
    expect(receiptBrightness(tester), Brightness.light);

    await disposeApp(tester);
  });

  testWidgets('struk identik di mode terang & gelap (AC-5.7)', (tester) async {
    Future<Color?> paperColorFor(ThemeMode mode) async {
      final sale = SaleResult(
        saleId: 1,
        invoiceNumber: '20260812-0001',
        subtotal: 5000,
        discount: 0,
        total: 5000,
        paymentMethod: 'cash',
        paidAmount: 5000,
        changeAmount: 0,
        createdAt: DateTime(2026, 8, 12, 10),
        items: const [
          SaleResultItem(
            productId: 1,
            name: 'Teh Botol',
            unit: 'pcs',
            qty: 1,
            sellPrice: 5000,
            discount: 0,
            lineTotal: 5000,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: SingleChildScrollView(child: ReceiptWidget(sale: sale)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<Container>(
            find
                .descendant(
                  of: find.byType(ReceiptWidget),
                  matching: find.byType(Container),
                )
                .first,
          )
          .color;
    }

    final terang = await paperColorFor(ThemeMode.light);
    final gelap = await paperColorFor(ThemeMode.dark);
    expect(gelap, terang);
    expect(gelap, ReceiptWidget.paper);

    await disposeApp(tester);
  });

  /// Sapu M15 — layar baru M12/M13 yang lahir SETELAH berkas ini ditulis dan
  /// karena itu tidak pernah ikut dijaga di sini. Tiga di antaranya hidup
  /// **di luar shell navigasi** (Masuk, Kode Pemulihan, Akses Ditolak): tidak
  /// ada AppBar bertema yang menutupi kesalahan, jadi satu warna terang yang
  /// tertinggal langsung menjadi "pulau putih" seukuran layar penuh.
  group('layar baru M12 & M13 di mode gelap (AC-5.10)', () {
    Widget wrapDark(Widget screen) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          themeModeStoreProvider.overrideWithValue(
            InMemoryThemeModeStore(ThemeMode.dark),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: screen,
        ),
      );
    }

    void setPhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(392, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    void expectDarkCanvas(WidgetTester tester) {
      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, darkPalette.background);
    }

    testWidgets('layar Masuk (M13) memakai palet gelap', (tester) async {
      setPhoneSize(tester);
      await SettingsRepositoryImpl(db).setValue(MultiUserSettings.keyEnabled, '1');
      await UserRepositoryImpl(db).createUser(
        name: 'Pak Budi',
        role: UserRole.owner,
        pin: '111111',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
            themeModeStoreProvider.overrideWithValue(
              InMemoryThemeModeStore(ThemeMode.dark),
            ),
          ],
          child: const KasirApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siapa yang bertugas?'), findsOneWidget);
      expectDarkCanvas(tester);

      await disposeApp(tester);
    });

    testWidgets('layar Kelola Pengguna (M13) memakai palet gelap', (tester) async {
      setPhoneSize(tester);
      await UserRepositoryImpl(db).createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '222222',
      );

      await tester.pumpWidget(wrapDark(const UsersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ani'), findsOneWidget);
      expectDarkCanvas(tester);

      await disposeApp(tester);
    });

    testWidgets('layar Kode Pemulihan (M13) memakai palet gelap', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(wrapDark(const RecoveryCodeScreen(code: 'ABCD2345')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ABCD'), findsWidgets);
      expectDarkCanvas(tester);

      await disposeApp(tester);
    });

    testWidgets('layar Akses Ditolak (M13) memakai palet gelap', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(wrapDark(const AccessDeniedScreen()));
      await tester.pumpAndSettle();

      expectDarkCanvas(tester);

      await disposeApp(tester);
    });

    testWidgets('detail Pelanggan (M12) memakai palet gelap', (tester) async {
      setPhoneSize(tester);
      final pelanggan = await CustomerRepositoryImpl(db).create(name: 'Bu Ani');

      await tester.pumpWidget(
        wrapDark(CustomerDetailScreen(customerId: pelanggan.id)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bu Ani'), findsWidgets);
      expectDarkCanvas(tester);

      await disposeApp(tester);
    });
  });
}
