import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';

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

  testWidgets(
    'menampilkan 5 tab navigasi bawah berlabel Bahasa Indonesia sesuai plan.md',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((d) => d.label)
          .toList();

      expect(labels, ['Kasir', 'Produk', 'Riwayat', 'Laporan', 'Pengaturan']);
    },
  );

  testWidgets('layar awal adalah tab Kasir', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);
  });

  testWidgets('tap tab Produk berpindah selectedIndex ke 1', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
  });

  testWidgets('tap tab Pengaturan berpindah selectedIndex ke 4', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 4);
  });
}
