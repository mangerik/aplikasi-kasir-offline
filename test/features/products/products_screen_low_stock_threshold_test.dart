import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';

/// Widget test end-to-end Milestone 6 — Tugas A poin 1: membuktikan
/// threshold stok menipis GLOBAL (`settings.low_stock_default`, diisi lewat
/// layar Pengaturan Milestone 5) benar-benar ter-*wire* ke badge & indikator
/// "Stok menipis" di tab Produk — bukan cuma dipakai di query SQL
/// (`watchLowStock`/`watchLowStockCount`, sudah teruji sejak M4), tapi juga
/// dipakai widget tampilan (`ProductListTile`, sebelumnya memakai
/// `Product.isLowStock` yang hardcode 5 — lihat catatan keputusan M5 §3.1 &
/// M4 §5 di plan.md/laporan-m5.md yang menandai ini SEBAGAI belum diwire).
///
/// Skenario: satu produk stok 8, TANPA threshold per-produk (null).
/// `low_stock_default` diisi '10' -> 8 <= 10 harus dianggap MENIPIS, padahal
/// hardcode lama (`Product.defaultLowStockThreshold = 5`) akan bilang AMAN
/// (8 > 5) — kalau widget masih pakai nilai hardcode lama, test ini gagal.
void main() {
  late AppDatabase db;

  setUpAll(() async {
    await DateFormatter.init();
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KasirApp(),
    );
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'badge & indikator "Stok menipis" tab Produk memakai settings.low_stock_default, '
    'bukan nilai hardcode Product.defaultLowStockThreshold',
    (tester) async {
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Gula Pasir',
              sellPrice: 15000,
              stock: const Value(8),
              // lowStockThreshold per-produk SENGAJA kosong -> harus fallback
              // ke threshold GLOBAL dari settings, bukan hardcode 5.
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'low_stock_default', value: '10'));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Produk').first);
      await tester.pumpAndSettle();

      // Badge jumlah di tab Produk (bottom nav) harus menghitung 1 produk
      // menipis (8 <= 10), bukan 0 (yang terjadi kalau masih hardcode 5).
      expect(find.text('1'), findsWidgets);
      // Indikator per-baris produk juga harus muncul.
      expect(find.text('Stok menipis'), findsOneWidget);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'produk TIDAK dianggap menipis bila stok di atas threshold global, '
    'walau di bawah hardcode lama tidak relevan di sini',
    (tester) async {
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: 'Beras 5kg',
              sellPrice: 65000,
              stock: const Value(20),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'low_stock_default', value: '10'));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Produk').first);
      await tester.pumpAndSettle();

      expect(find.text('Stok menipis'), findsNothing);

      await disposeApp(tester);
    },
  );
}
