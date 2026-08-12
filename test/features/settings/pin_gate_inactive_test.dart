import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:go_router/go_router.dart';

/// Widget test terpisah dari `pin_gate_active_test.dart` — `appRouter`
/// (`lib/core/router/app_router.dart`) adalah singleton top-level yang
/// mempertahankan lokasi navigasi terakhir ANTAR `testWidgets` dalam SATU
/// file/proses yang sama (beda file test = beda isolate = state fresh).
/// Memisahkan skenario "PIN nonaktif" dan "PIN aktif" ke file berbeda
/// menghindari kebocoran state tersebut.
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

  testWidgets('tab Laporan tetap terbuka tanpa PIN saat kunci nonaktif', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const KasirApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laporan').first);
    await tester.pumpAndSettle();

    // Navigasi utama kini dock kustom (docs/ui-redesign-foundation.md §6):
    // index tab dibaca langsung dari StatefulNavigationShell.
    expect(
      tester
          .widget<StatefulNavigationShell>(
            find.byType(StatefulNavigationShell),
          )
          .currentIndex,
      3,
    );
    expect(find.text('Verifikasi PIN'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
