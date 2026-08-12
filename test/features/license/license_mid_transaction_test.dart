import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/license/license_status.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/features/license/providers/license_providers.dart';
import 'package:kasir_warung/features/license/providers/license_store.dart';

import '../../fixtures/license_vectors.dart';

/// **Lisensi tidak pernah mengunci di tengah transaksi** (K-6.10, AC-6.18).
///
/// Ini aturan yang paling mahal kalau dilanggar: uang pembeli sudah di
/// tangan kasir, antrian masih panjang, lalu aplikasi menolak menyimpan.
/// Satu hari lisensi tidak sebanding dengan kerusakan itu — jadi gerbangnya
/// sengaja dipasang di **build layar Kasir**, bukan di `SaveSaleUsecase`:
/// sheet pembayaran hidup di route DI ATAS layar Kasir, sehingga transaksi
/// yang sudah berjalan selesai apa adanya dan kunci baru berlaku setelahnya.
void main() {
  late AppDatabase db;
  late InMemoryLicenseStore store;

  setUpAll(() async => DateFormatter.init());
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InMemoryLicenseStore(token: kVectorLifetime);
  });
  tearDown(() async => db.close());

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(392, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      licenseStoreProvider.overrideWithValue(store),
      licenseBootstrapProvider.overrideWithValue(
        LicenseStatus.belumAktif(referenceTime: DateTime.now()),
      ),
    ],
    child: const KasirApp(),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('lisensi berakhir saat keranjang berisi → transaksi berjalan '
      'TETAP tersimpan, kunci baru berlaku setelahnya (AC-6.18)', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 1).millisecondsSinceEpoch;
    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: 'Teh Botol',
            sellPrice: 3000,
            stock: const Value(10),
            createdAt: now,
            updatedAt: now,
          ),
        );

    setPhoneSize(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);

    // Kasir melayani pembeli seperti biasa.
    await tester.tap(find.text('Teh Botol'));
    await tester.pump();
    await tester.tap(find.text('Bayar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar').last);
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran'), findsOneWidget);

    // …dan PERSIS pada saat itu lisensinya berakhir (mis. aplikasi menginap
    // semalam melewati tanggal kedaluwarsa, lalu di-resume).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await store.writeToken(kVectorYearlyExpired, DateTime.now());
    await container.read(licenseStatusProvider.notifier).revalidate();
    await tester.pump();
    expect(
      container.read(licenseStatusProvider).state,
      LicenseState.kedaluwarsaTahunan,
    );

    // Transaksi yang sedang berjalan tetap bisa diselesaikan.
    await tester.tap(find.text('Rp10.000'));
    await tester.pump();
    await tester.tap(find.text('Selesaikan Pembayaran'));
    await tester.pumpAndSettle();

    expect(find.text('Transaksi Berhasil'), findsOneWidget);
    final sales = await db.select(db.sales).get();
    expect(sales, hasLength(1));
    expect(sales.single.total, 3000);

    // Baru SETELAH itu layar Kasir terkunci.
    await tester.tap(find.text('Transaksi Baru'));
    await settle(tester);
    expect(find.text('Lisensi sudah berakhir'), findsWidgets);
    expect(find.text('Masukkan Kode Baru'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
