import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/constants/app_theme.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/core/widgets/app_bar_chart.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/features/reports/providers/report_providers.dart';
import 'package:kasir_warung/features/reports/screens/reports_screen.dart';
import 'package:kasir_warung/features/transactions/providers/history_providers.dart';
import 'package:kasir_warung/features/transactions/screens/transactions_screen.dart';

/// Grafik penjualan di dashboard Laporan (PRD v1.1 §9, M14).
///
/// Yang diuji: keempat grafik benar-benar ter-render di layar HP 5 inci
/// **di kedua tema** (AC-9.9, AC-9.12), tap batang memunculkan angka
/// persisnya (AC-9.8), peralih Omzet/Laba bekerja tanpa memuat ulang layar
/// (AC-9.6), rentang kosong memunculkan `EmptyState` alih-alih grafik
/// kosong (AC-9.11), dan "Lihat transaksi" benar-benar membuka Riwayat
/// yang sudah terfilter.
void main() {
  late AppDatabase db;

  setUpAll(() async => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> insertProduct(String name, int price, int cost) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.into(db.products).insert(
          ProductsCompanion.insert(
            name: name,
            sellPrice: price,
            costPrice: Value(cost),
            stock: const Value(500),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Data hari ini: tiga transaksi dengan tiga metode bayar berbeda supaya
  /// keempat grafik punya isi.
  Future<void> seedToday() async {
    final repo = SaleRepositoryImpl(db);
    final teh = await insertProduct('Teh Botol Sosro Kemasan Kotak', 5000, 3000);
    final gula = await insertProduct('Gula Pasir Curah', 15000, 12000);

    await repo.saveSale(
      items: [
        CartItem(
          key: 'p_$teh',
          productId: teh,
          name: 'Teh Botol Sosro Kemasan Kotak',
          unit: 'pcs',
          qty: 4,
          sellPrice: 5000,
          costPrice: 3000,
        ),
      ],
      transactionDiscount: 0,
      paymentMethod: 'cash',
      paidAmount: 20000,
    );
    await repo.saveSale(
      items: [
        CartItem(
          key: 'p_$gula',
          productId: gula,
          name: 'Gula Pasir Curah',
          unit: 'kg',
          qty: 2,
          sellPrice: 15000,
          costPrice: 12000,
        ),
      ],
      transactionDiscount: 0,
      paymentMethod: 'noncash',
      paidAmount: 30000,
    );
    await repo.saveSale(
      items: [
        CartItem(
          key: 'p_$teh',
          productId: teh,
          name: 'Teh Botol Sosro Kemasan Kotak',
          unit: 'pcs',
          qty: 1,
          sellPrice: 5000,
          costPrice: 3000,
        ),
      ],
      transactionDiscount: 0,
      paymentMethod: 'debt',
      paidAmount: 0,
      customerName: 'Bu Ani',
    );
  }

  Widget standalone(Brightness brightness) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          home: const ReportsScreen(),
        ),
      );

  Finder reportScrollable() => find
      .descendant(
        of: find.byType(ReportsScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 250, scrollable: reportScrollable());
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.light ? 'terang' : 'gelap';

    testWidgets('keempat grafik ter-render di HP 5 inci — mode $themeName '
        '(AC-9.9, AC-9.12)', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await seedToday();
      await tester.pumpWidget(standalone(brightness));
      await tester.pumpAndSettle();

      // Grafik 1 — tren penjualan (ember per jam untuk rentang "Hari ini").
      await scrollTo(tester, find.text('Tren Penjualan'));
      expect(find.text('Satu batang = satu jam'), findsOneWidget);
      expect(find.text('OMZET PERIODE'), findsOneWidget);

      // Grafik 2 — jam ramai.
      await scrollTo(tester, find.text('Jam Ramai'));
      expect(find.text('PALING RAMAI'), findsOneWidget);

      // Grafik 3 — komposisi pembayaran (batang bertumpuk + legenda teks).
      await scrollTo(tester, find.text('Komposisi Pembayaran'));
      expect(find.byType(AppStackedBar), findsOneWidget);
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('Non-tunai'), findsOneWidget);
      expect(find.text('Hutang'), findsOneWidget);

      // Grafik 4 — produk terlaris sebagai batang horizontal.
      await scrollTo(tester, find.text('Produk Terlaris'));
      expect(find.byType(AppHorizontalBarChart), findsOneWidget);
      expect(find.text('Teh Botol Sosro Kemasan Kotak'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tap batang menampilkan angka persis batang itu (AC-9.8)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seedToday();
    await tester.pumpWidget(standalone(Brightness.light));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Tren Penjualan'));
    expect(find.text('Sentuh batang untuk melihat angka persisnya.'),
        findsOneWidget);

    // Batang jam sekarang: seluruh omzet hari ini menumpuk di sana.
    final chart = find.byType(AppBarChart).first;
    final rect = tester.getRect(chart);
    final slot = (rect.width - AppBarChart.axisWidth) / 24;
    final hour = DateTime.now().hour;
    await tester.tapAt(
      Offset(
        rect.left + AppBarChart.axisWidth + slot * (hour + 0.5),
        rect.top + AppBarChart.plotHeight / 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rp55.000'), findsWidgets, reason: '20.000 + 30.000 + 5.000');
    expect(find.text('3 transaksi'), findsOneWidget);
    expect(find.text('Lihat transaksi'), findsOneWidget);
  });

  testWidgets('peralih Omzet/Laba mengubah data grafik tanpa memuat ulang '
      'layar (AC-9.6)', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seedToday();
    await tester.pumpWidget(standalone(Brightness.light));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Tren Penjualan'));
    expect(find.text('OMZET PERIODE'), findsOneWidget);

    expect(find.byType(SegmentedButton<TrendMetric>), findsOneWidget);
    await tester.tap(find.text('Laba'));
    await tester.pumpAndSettle();

    expect(find.text('LABA KOTOR PERIODE'), findsOneWidget);
    // 4 x (5000-3000) + 2 x (15000-12000) + 1 x (5000-3000) = 16.000.
    expect(find.text('Rp16.000'), findsWidgets);
  });

  testWidgets('perbandingan dengan periode sebelumnya menampilkan tanda & '
      'persentase yang benar (AC-9.7)', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seedToday(); // Omzet hari ini = 55.000.
    // Kemarin sengaja 50.000 → +10%.
    await db.into(db.sales).insert(
          SalesCompanion.insert(
            invoiceNumber: 'KEMARIN-1',
            subtotal: 50000,
            total: 50000,
            paymentMethod: 'cash',
            status: 'completed',
            createdAt: DateFormatter.toEpochMillis(
              DateTime.now().subtract(const Duration(days: 1)),
            ),
          ),
        );

    await tester.pumpWidget(standalone(Brightness.light));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Tren Penjualan'));

    expect(find.text('+10% dari hari sebelumnya'), findsOneWidget);
  });

  testWidgets('rentang tanpa transaksi menampilkan EmptyState, bukan grafik '
      'kosong atau NaN (AC-9.11)', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seedToday();
    await tester.pumpWidget(standalone(Brightness.light));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kemarin'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Belum ada penjualan pada rentang ini'));
    expect(find.text('Belum ada penjualan pada rentang ini'), findsOneWidget);
    expect(find.text('Belum ada jam ramai'), findsOneWidget);
    expect(find.byType(AppBarChart), findsNothing);
    expect(tester.takeException(), isNull);

    // Sapu M15: grafik komposisi pembayaran dulu MENGHILANG seluruhnya pada
    // rentang kosong — judul section-nya sekalian — sehingga rentang tanpa
    // transaksi terasa seperti bug render, bukan jawaban. Sekarang ia
    // menjelaskan diri sendiri seperti dua grafik di atasnya.
    await scrollTo(tester, find.text('Komposisi Pembayaran'));
    expect(find.text('Komposisi Pembayaran'), findsOneWidget);
    expect(find.text('Belum ada pembayaran pada rentang ini'), findsOneWidget);
  });

  testWidgets('"Lihat transaksi" membuka Riwayat dengan filter rentang '
      'batang yang disentuh', (tester) async {
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await seedToday();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const KasirApp();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laporan').first);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Tren Penjualan'));

    final rect = tester.getRect(find.byType(AppBarChart).first);
    final slot = (rect.width - AppBarChart.axisWidth) / 24;
    final hour = DateTime.now().hour;
    await tester.tapAt(
      Offset(
        rect.left + AppBarChart.axisWidth + slot * (hour + 0.5),
        rect.top + AppBarChart.plotHeight / 2,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lihat transaksi'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionsScreen), findsOneWidget);
    final filter = container.read(historyFilterProvider);
    expect(filter.isActive, isTrue);
    expect(filter.startDate!.hour, hour);
    expect(filter.endDate!.hour, hour);
    expect(filter.endDate!.minute, 59);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
