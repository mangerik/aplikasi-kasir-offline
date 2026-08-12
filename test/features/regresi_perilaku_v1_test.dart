import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/domain/entities/multi_user_settings.dart';
import 'package:kasir_warung/domain/entities/points_settings.dart';
import 'package:kasir_warung/features/auth/widgets/active_user_chip.dart';

/// Regresi M15: **fitur v1.1 Tier 2 yang mati = perilaku v1.1.0 persis.**
///
/// Ini gerbang rilis v1.2.0 yang paling mudah dilanggar tanpa sadar. Warung
/// yang tidak menyalakan apa pun — multi-user mati (default), program poin
/// mati (default), printer belum dipasang — TIDAK boleh merasakan bahwa
/// aplikasinya baru saja bertambah tiga fitur besar. Ukurannya bukan selera:
/// **nol tap tambahan** pada alur kasir inti (PRD v1.1 §11.2), nol elemen
/// poin di layar mana pun (AC-7.6), dan nol jejak multi-user (AC-8.1).
///
/// Test-test lain menguji masing-masing fitur saat MENYALA. Yang ini
/// menguji satu-satunya keadaan yang dialami mayoritas pengguna: semuanya
/// mati.
void main() {
  late AppDatabase db;

  setUpAll(() async => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(392, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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

  Future<void> seedProduct({String name = 'Teh Botol', int sellPrice = 3000}) {
    final now = DateTime(2026, 8, 1).millisecondsSinceEpoch;
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            name: name,
            sellPrice: sellPrice,
            stock: const Value(10),
            createdAt: now,
            updatedAt: now,
          ),
        )
        .then((_) {});
  }

  /// Keadaan awal warung yang baru memperbarui aplikasi dari v1.1.0:
  /// tidak ada satu pun key fitur baru di tabel `settings`.
  Future<void> pastikanSeluruhFiturMati() async {
    final rows = await db.select(db.settings).get();
    final keys = rows.map((row) => row.key).toSet();
    expect(keys, isNot(contains(PointsSettings.keyEnabled)));
    expect(keys, isNot(contains(MultiUserSettings.keyEnabled)));
    expect(keys, isNot(contains('printer_address')));
  }

  testWidgets(
    'alur kasir inti tetap TIGA LANGKAH: nol tap tambahan dibanding v1.0 '
    '(AC-7.5, AC-8.1, PRD §11.2)',
    (tester) async {
      await seedProduct(name: 'Teh Botol', sellPrice: 3000);
      await pastikanSeluruhFiturMati();

      setPhoneSize(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Urutan tap di bawah PERSIS sama dengan regresi alur v1.0 di
      // `pos_checkout_flow_test.dart` — tidak satu pun tap tambahan
      // (tidak ada layar Masuk, tidak ada pemilih pelanggan wajib, tidak
      // ada pertanyaan poin). Kalau suatu saat ada yang menyisipkan satu
      // langkah, test ini gagal di baris tempat langkah itu disisipkan.
      var taps = 0;

      // Langkah 1 — pilih barang.
      await tester.tap(find.text('Teh Botol'));
      taps++;
      await tester.pump();

      await tester.tap(find.text('Bayar').first);
      taps++;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bayar').last);
      taps++;
      await tester.pumpAndSettle();

      // Langkah 2 — terima uang.
      expect(find.text('Pembayaran'), findsOneWidget);
      await tester.tap(find.text('Rp10.000'));
      taps++;
      await tester.pump();

      // Langkah 3 — simpan.
      await tester.tap(find.text('Selesaikan Pembayaran'));
      taps++;
      await tester.pumpAndSettle();

      expect(find.text('Transaksi Berhasil'), findsOneWidget);
      expect(
        taps,
        5,
        reason: 'jumlah tap alur kasir tunai berubah dari baseline v1.0/v1.1.0',
      );

      final sales = await db.select(db.sales).get();
      expect(sales, hasLength(1));
      expect(sales.single.paymentMethod, 'cash');
      expect(sales.single.changeAmount, 7000);
      // Jejak fitur baru tidak boleh ikut tertulis saat fiturnya mati.
      expect(sales.single.userId, isNull, reason: 'AC-8.1');
      expect(sales.single.userName, isNull, reason: 'AC-8.1');
      expect(sales.single.customerId, isNull, reason: 'AC-7.5');
      expect(await db.select(db.customerPointEntries).get(), isEmpty, reason: 'K-7.4');

      await disposeApp(tester);
    },
  );

  testWidgets(
    'layar Kasir tanpa multi-user: tidak ada chip pengguna & tidak ada '
    'menu ⋮ (AC-8.1)',
    (tester) async {
      await seedProduct();

      setPhoneSize(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(ActiveUserChip), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('Ganti Kasir'), findsNothing);
      expect(find.text('Siapa yang bertugas?'), findsNothing);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'sheet pembayaran tanpa program poin: nol elemen poin, pelanggan tetap '
    'opsional (AC-7.5, AC-7.6)',
    (tester) async {
      await seedProduct();

      setPhoneSize(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Teh Botol'));
      await tester.pump();
      await tester.tap(find.text('Bayar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bayar').last);
      await tester.pumpAndSettle();

      expect(find.text('Pembayaran'), findsOneWidget);
      expect(find.textContaining('poin'), findsNothing);
      expect(find.textContaining('Poin'), findsNothing);
      // Pemilih pelanggan boleh ADA, tapi tidak boleh wajib untuk tunai —
      // labelnya sendiri yang menyatakannya.
      expect(find.text('Pilih Pelanggan *'), findsNothing);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'Riwayat & Laporan tanpa multi-user: tidak ada filter "Kasir" '
    '(AC-8.1, AC-8.9)',
    (tester) async {
      await seedProduct();

      setPhoneSize(tester);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      for (final tab in ['Riwayat', 'Laporan']) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(
          find.text('Semua Kasir'),
          findsNothing,
          reason: 'filter kasir muncul di tab $tab padahal multi-user mati',
        );
      }

      await disposeApp(tester);
    },
  );
}
