import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/core/widgets/main_shell.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:go_router/go_router.dart';

/// Tab ke-N di dalam dock navigasi kustom.
Finder _navTab(String label) => find.descendant(
  of: find.byKey(MainShell.dockKey),
  matching: find.text(label),
);

int _currentIndex(WidgetTester tester) => tester
    .widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell))
    .currentIndex;

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

  // Milestone 1 menambah provider berbasis stream Drift (productListProvider
  // dkk) di tab Produk. Drift menjadwalkan Timer(Duration.zero) internal saat
  // sebuah QueryStream di-cancel (lihat paket drift, stream_queries.dart) —
  // di widget test ini perlu di-"flush" secara eksplisit (bukan cuma
  // pumpAndSettle, yang hanya menunggu *frame* terjadwal, bukan Timer polos)
  // sebelum test berakhir, agar tidak kena assertion internal flutter_test
  // "A Timer is still pending even after the widget tree was disposed."
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // `pump()` tanpa argumen HANYA flush microtasks — Timer (walau
    // Duration.zero) baru diproses saat fake clock benar-benar di-"elapse",
    // makanya durasi eksplisit (bukan null) wajib di sini.
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'menampilkan 5 tab navigasi bawah berlabel Bahasa Indonesia sesuai plan.md',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Navigasi utama kini berupa dock kustom (lihat
      // docs/ui-redesign-foundation.md §6), bukan NavigationBar Material.
      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(MainShell.dockKey),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();

      expect(labels, ['Kasir', 'Produk', 'Riwayat', 'Laporan', 'Setelan']);

      await disposeApp(tester);
    },
  );

  testWidgets('layar awal adalah tab Kasir', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(_currentIndex(tester), 0);

    await disposeApp(tester);
  });

  testWidgets('tap tab Produk berpindah selectedIndex ke 1', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(_navTab('Produk'));
    await tester.pumpAndSettle();

    expect(_currentIndex(tester), 1);

    await disposeApp(tester);
  });

  testWidgets('tap tab Setelan berpindah selectedIndex ke 4', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(_navTab('Setelan'));
    await tester.pumpAndSettle();

    expect(_currentIndex(tester), 4);

    await disposeApp(tester);
  });
}
