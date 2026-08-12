import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/license/device_code.dart';
import 'package:kasir_warung/core/license/license_status.dart';
import 'package:kasir_warung/core/license/license_token.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/core/widgets/main_shell.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/features/license/providers/license_providers.dart';
import 'package:kasir_warung/features/license/providers/license_store.dart';
import 'package:kasir_warung/features/license/widgets/license_code_field.dart';

import '../../fixtures/license_vectors.dart';

/// Alur aktivasi ujung-ke-ujung: kode yang diterbitkan tool penjual
/// dimasukkan di layar Aktivasi dan membuka aplikasi (AC-6.2, AC-6.4,
/// AC-6.5, AC-6.6, AC-6.12).
void main() {
  late AppDatabase db;
  late InMemoryLicenseStore store;

  setUpAll(() async => DateFormatter.init());
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InMemoryLicenseStore();
  });
  tearDown(() async => db.close());

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

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  /// Layar Aktivasi lebih tinggi daripada viewport uji bawaan (800x600),
  /// sedangkan `ListView` membangun anaknya secara malas — tanpa viewport
  /// yang lebih tinggi, kolom kode belum pernah lahir saat test mencarinya.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byKey(LicenseCodeField.fieldKey), code);
    await tester.pump();
  }

  testWidgets('kode perangkat yang tampil sama dengan turunan benih '
      'perangkat (AC-6.2)', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text(DeviceCode.format(kVectorDeviceRaw)), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('kode SAH → aplikasi terbuka, token tersimpan (AC-6.4)', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);

    // Bentuk yang benar-benar diterima pembeli lewat WhatsApp: berawalan &
    // terkelompok lima.
    await enterCode(tester, LicenseToken.format(kVectorLifetime));
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);

    expect(find.byKey(MainShell.dockKey), findsOneWidget);
    expect(store.readToken(), kVectorLifetime);
    expect(store.readActivatedAt(), isNotNull);

    await disposeApp(tester);
  });

  testWidgets('kode untuk perangkat lain → pesan SPESIFIK, bukan generik '
      '(AC-6.5)', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await enterCode(tester, kVectorOtherDevice);
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);

    expect(find.text('Perangkat lain'), findsOneWidget);
    expect(
      find.textContaining('diterbitkan untuk perangkat lain'),
      findsOneWidget,
    );
    // Tetap di layar Aktivasi, token tidak tersimpan.
    expect(find.text('AKTIFKAN'), findsOneWidget);
    expect(store.readToken(), isNull);

    await disposeApp(tester);
  });

  testWidgets('satu karakter salah ketik → "Kode salah ketik", BUKAN '
      '"kode tidak sah" (AC-6.6)', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);

    final typo = kVectorLifetime.replaceRange(
      60,
      61,
      kVectorLifetime[60] == '0' ? '2' : '0',
    );
    await enterCode(tester, typo);
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);

    expect(find.text('Kode salah ketik'), findsOneWidget);
    expect(find.text('Kode tidak sah'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('kode versi lebih baru → "Perlu versi baru" (AC-6.21)', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await enterCode(tester, kVectorFutureVersion);
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);

    expect(find.text('Perlu versi baru'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('trial kedaluwarsa → aktivasi lifetime: SELURUH data yang '
      'dibuat selama masa coba tetap ada (AC-6.12)', (tester) async {
    // Data dibuat "selama masa coba".
    final now = DateTime(2026, 8, 12).millisecondsSinceEpoch;
    final productId = await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: 'Kopi Sachet',
            sellPrice: 2000,
            stock: const Value(10),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            invoiceNumber: 'INV-1',
            subtotal: 2000,
            total: 2000,
            paidAmount: const Value(2000),
            paymentMethod: 'tunai',
            status: 'lunas',
            createdAt: now,
          ),
        );
    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            productId: productId,
            type: 'out',
            qtyChange: -1,
            stockAfter: 9,
            createdAt: now,
          ),
        );

    Future<List<int>> counts() async => [
      (await db.select(db.products).get()).length,
      (await db.select(db.sales).get()).length,
      (await db.select(db.stockMovements).get()).length,
    ];

    final before = await counts();

    store = InMemoryLicenseStore(token: kVectorTrialExpired);
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);
    expect(find.text('Masa coba 3 hari sudah berakhir'), findsOneWidget);

    // Beli → masukkan kode lifetime lewat layar aktivasi.
    await tester.tap(find.text('Masukkan Kode Aktivasi'));
    await settle(tester);
    await enterCode(tester, kVectorLifetime);
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);

    expect(await counts(), before);
    expect(store.readToken(), kVectorLifetime);

    await disposeApp(tester);
  });

  testWidgets('kode BUKAN sekali pakai: kode yang sama boleh dimasukkan '
      'lagi setelah pasang ulang (K-6.6)', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);
    await enterCode(tester, kVectorLifetime);
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);
    expect(find.byKey(MainShell.dockKey), findsOneWidget);
    await disposeApp(tester);

    // "Pasang ulang": penyimpanan kosong lagi, kode yang sama dipakai lagi.
    store = InMemoryLicenseStore();
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);
    await enterCode(tester, kVectorLifetime);
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);
    expect(find.byKey(MainShell.dockKey), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('trial TIDAK bisa direset dengan memasang ulang: kode trial '
      'lama tetap kedaluwarsa (AC-6.11)', (tester) async {
    store = InMemoryLicenseStore();
    useTallViewport(tester);
    await tester.pumpWidget(buildApp());
    await settle(tester);

    await enterCode(tester, kVectorTrialExpired);
    await tester.tap(find.text('AKTIFKAN'));
    await settle(tester);

    // Kodenya SAH (tanda tangannya benar) tapi kedaluwarsanya absolut,
    // jadi hasilnya layar "masa coba berakhir", bukan aplikasi terbuka.
    expect(find.byKey(MainShell.dockKey), findsNothing);
    expect(find.text('Masa coba 3 hari sudah berakhir'), findsOneWidget);

    await disposeApp(tester);
  });
}
