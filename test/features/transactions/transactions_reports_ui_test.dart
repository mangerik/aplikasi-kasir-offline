import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/features/reports/screens/debt_list_screen.dart';
import 'package:kasir_warung/features/reports/screens/reports_screen.dart';
import 'package:kasir_warung/features/transactions/screens/sale_detail_screen.dart';
import 'package:kasir_warung/features/transactions/widgets/history_tile.dart';

/// Smoke test tampilan area Transaksi & Laporan setelah redesign UI
/// (`docs/ui-redesign-transactions-reports.md`).
///
/// Fokusnya BUKAN logika bisnis (sudah ditutup test usecase/repository),
/// melainkan bahwa seluruh layar area ini benar-benar ter-render di layar
/// HP (392dp) dengan data nyata TANPA overflow/exception: daftar riwayat
/// berkelompok tanggal, sheet filter, detail transaksi (tunai & hutang,
/// sampai ke pratinjau struk di bagian bawah), dashboard laporan, daftar
/// hutang, dan detail hutang per pelanggan.
///
/// Layout kartu/nominal gampang overflow di HP sempit begitu nama produk
/// atau nama pelanggan panjang — karena itu data seed di sini sengaja
/// memakai nama panjang.
void main() {
  late AppDatabase db;

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

  /// Scrollable milik satu layar tertentu (di dalam shell ada beberapa
  /// scroll view sekaligus, jadi finder harus dipersempit).
  Finder scrollableOf(Type screen) => find
      .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
      .first;

  testWidgets(
    'riwayat -> detail -> laporan -> hutang ter-render tanpa overflow di layar HP',
    (tester) async {
      tester.view.physicalSize = const Size(392, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = SaleRepositoryImpl(db);
      final teh = await insertProduct('Teh Botol Sosro Kemasan', 5000);
      final gula = await insertProduct('Gula Pasir', 15000);

      // Tunai, 2 item, ada diskon item + diskon transaksi + kembalian.
      await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$teh',
            productId: teh,
            name: 'Teh Botol Sosro Kemasan',
            unit: 'pcs',
            qty: 3,
            sellPrice: 5000,
            costPrice: 3000,
          ),
          CartItem(
            key: 'p_$gula',
            productId: gula,
            name: 'Gula Pasir',
            unit: 'kg',
            qty: 2,
            sellPrice: 15000,
            costPrice: 12000,
            discount: 1000,
          ),
        ],
        transactionDiscount: 2000,
        paymentMethod: 'cash',
        paidAmount: 50000,
      );
      // Non-tunai.
      await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$gula',
            productId: gula,
            name: 'Gula Pasir',
            unit: 'kg',
            qty: 1,
            sellPrice: 15000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'noncash',
        paidAmount: 15000,
      );
      // Hutang dengan nama pelanggan panjang.
      await repo.saveSale(
        items: [
          CartItem(
            key: 'p_$teh',
            productId: teh,
            name: 'Teh Botol Sosro Kemasan',
            unit: 'pcs',
            qty: 10,
            sellPrice: 5000,
          ),
        ],
        transactionDiscount: 0,
        paymentMethod: 'debt',
        paidAmount: 0,
        customerName: 'Bu Sri Rahayu Wijayanti',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const KasirApp(),
        ),
      );
      await tester.pumpAndSettle();

      // --- Riwayat: 3 kartu transaksi, dikelompokkan di bawah "HARI INI".
      await tester.tap(find.text('Riwayat').first);
      await tester.pumpAndSettle();
      expect(find.byType(HistoryTile), findsNWidgets(3));
      expect(find.text('HARI INI'), findsOneWidget);

      // --- Sheet filter: rentang cepat -> terapkan -> banner filter aktif.
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Filter Riwayat'), findsOneWidget);
      await tester.tap(find.text('7 hari'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();
      expect(find.text('Filter aktif'), findsOneWidget);
      await tester.tap(find.text('Hapus filter'));
      await tester.pumpAndSettle();
      expect(find.text('Filter aktif'), findsNothing);

      // --- Detail transaksi hutang: ada CTA "Tandai Lunas", dan seluruh
      // isi (sampai pratinjau struk & tombol void) muat saat di-scroll.
      await tester.tap(find.byType(HistoryTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('Tandai Lunas'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Batalkan Transaksi'),
        300,
        scrollable: scrollableOf(SaleDetailScreen),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // --- Detail transaksi tunai (2 item + diskon + kembalian).
      await tester.tap(find.byType(HistoryTile).last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Batalkan Transaksi'),
        300,
        scrollable: scrollableOf(SaleDetailScreen),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // --- Laporan: kartu omzet + pintasan hutang berjalan.
      await tester.tap(find.text('Laporan').first);
      await tester.pumpAndSettle();
      expect(find.text('OMZET'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('PERLU DITAGIH'),
        300,
        scrollable: scrollableOf(ReportsScreen),
      );
      await tester.pumpAndSettle();
      expect(find.text('PERLU DITAGIH'), findsOneWidget);

      // --- Daftar hutang -> transaksi hutang satu pelanggan.
      await tester.tap(find.text('PERLU DITAGIH'));
      await tester.pumpAndSettle();
      expect(find.byType(DebtListScreen), findsOneWidget);
      expect(find.text('TOTAL HUTANG BERJALAN'), findsOneWidget);

      await tester.tap(find.text('Bu Sri Rahayu Wijayanti'));
      await tester.pumpAndSettle();
      expect(find.text('SISA HUTANG'), findsOneWidget);
      expect(find.byType(HistoryTile), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    },
  );
}
