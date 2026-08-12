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
import 'package:kasir_warung/domain/entities/product_import.dart';
import 'package:kasir_warung/features/products/screens/product_import_screen.dart';
import 'package:kasir_warung/features/products/widgets/import_preview_row_tile.dart';
import 'package:kasir_warung/features/products/widgets/import_summary_card.dart';

/// Uji tampilan wizard impor (PRD v1.1 §4.4 & §4.7).
///
/// Dua hal yang dikejar:
/// 1. **Titik masuknya benar-benar bisa dicapai** dari layar Produk —
///    fitur yang tidak bisa dibuka sama saja tidak ada.
/// 2. **Status baris dibawa oleh LABEL, bukan hanya warna** (aturan yang
///    sama dengan AC-5.11 mode gelap), dan seluruh warnanya ikut tema.
void main() {
  late AppDatabase db;

  setUpAll(() async => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ProductImportPlanRow planRow({
    required String name,
    required ProductImportAction action,
    List<ProductImportIssue> issues = const [],
    String? barcode,
    int sellPrice = 12500,
    double? stock,
  }) {
    return ProductImportPlanRow(
      row: ProductImportRow(
        excelRow: 7,
        rawCells: const [],
        name: name,
        barcode: barcode,
        sellPrice: sellPrice,
        stock: stock,
        issues: issues,
      ),
      action: action,
      issues: issues,
    );
  }

  Widget wrap(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('titik masuk ganda (PRD §4.7)', () {
    testWidgets('menu ⋮ membuka wizard impor', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const KasirApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Pindah ke tab Produk.
      await tester.tap(find.text('Produk').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Impor dari Excel'), findsOneWidget);

      await tester.tap(find.text('Impor dari Excel'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductImportScreen), findsOneWidget);
      expect(find.text('Impor Produk dari Excel'), findsOneWidget);
      // Langkah 1: indikator langkah + dua jalan keluar (template & pilih file).
      expect(find.text('1 Pilih file'), findsOneWidget);
      expect(find.text('Unduh Template'), findsOneWidget);
      expect(find.text('Pilih File .xlsx'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('kartu Export Excel di Pengaturan membuka wizard yang SAMA', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const KasirApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Setelan').first);
      await tester.pumpAndSettle();

      final tombolImpor = find.text('Impor Produk dari Excel');
      await tester.dragUntilVisible(
        tombolImpor,
        find.byType(ListView).first,
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();

      await tester.tap(tombolImpor);
      await tester.pumpAndSettle();

      expect(find.byType(ProductImportScreen), findsOneWidget);
      expect(find.text('1 Pilih file'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });

  group('baris pratinjau', () {
    testWidgets('setiap status membawa LABEL, bukan hanya warna', (tester) async {
      const cases = {
        ProductImportAction.create: 'Baru',
        ProductImportAction.update: 'Diperbarui',
        ProductImportAction.skip: 'Dilewati',
        ProductImportAction.error: 'Bermasalah',
      };

      for (final entry in cases.entries) {
        await tester.pumpWidget(
          wrap(
            ImportPreviewRowTile(
              planRow: planRow(name: 'Kopi Sachet', action: entry.key),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: 'status ${entry.key} wajib punya label tertulis',
        );
      }
    });

    testWidgets('menampilkan nomor baris Excel, nilai HASIL PARSING, dan '
        'alasan masalahnya', (tester) async {
      await tester.pumpWidget(
        wrap(
          ImportPreviewRowTile(
            planRow: planRow(
              name: 'Beras Ramos',
              action: ProductImportAction.error,
              barcode: '899123',
              sellPrice: 68000,
              stock: 1.5,
              issues: const [
                ProductImportIssue.error('Barcode 899123 muncul di baris 7 dan 12.'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Baris 7'), findsOneWidget);
      expect(find.textContaining('899123'), findsWidgets);
      expect(find.textContaining('stok 1,5'), findsOneWidget);
      expect(find.text('Rp68.000'), findsOneWidget);
      expect(
        find.textContaining('muncul di baris 7 dan 12'),
        findsOneWidget,
        reason: 'alasan Bahasa Indonesia tampil langsung di pratinjau',
      );
    });

    testWidgets('baris berperingatan ditandai "perlu dicek", bukan '
        '"bermasalah"', (tester) async {
      await tester.pumpWidget(
        wrap(
          ImportPreviewRowTile(
            planRow: planRow(
              name: 'Minyak Goreng',
              action: ProductImportAction.create,
              issues: const [
                ProductImportIssue.warning('Harga modal lebih besar daripada harga jual.'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('perlu dicek'), findsOneWidget);
    });

    testWidgets('ikut tema gelap — tidak ada "pulau putih" (AC-5.6)', (tester) async {
      await tester.pumpWidget(
        wrap(
          ImportSummaryCard(
            eyebrow: 'PRATINJAU',
            title: 'produk.xlsx',
            stats: const [
              ImportStat(value: 84, label: 'Baru'),
              ImportStat(value: 30, label: 'Diperbarui'),
            ],
          ),
          theme: AppTheme.dark(),
        ),
      );
      await tester.pump();

      const dark = AppPalette.dark();
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ImportSummaryCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, dark.surface);
      // Angka tetap lebih menonjol daripada labelnya (fondasi §1).
      expect(find.text('84'), findsOneWidget);
      expect(find.text('Baru'), findsOneWidget);
    });
  });
}
