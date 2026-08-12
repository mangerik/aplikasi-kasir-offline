import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/router/app_router.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/repositories/settings_repository_impl.dart';
import 'package:kasir_warung/data/repositories/user_repository_impl.dart';
import 'package:kasir_warung/domain/entities/app_user.dart';
import 'package:kasir_warung/domain/entities/multi_user_settings.dart';
import 'package:kasir_warung/features/auth/providers/session_store.dart';

/// Gerbang Masuk & penjagaan izin di aplikasi sungguhan
/// (PRD v1.1 §8.3.B, §8.3.C — AC-8.1, AC-8.4, AC-8.15).
void main() {
  late AppDatabase db;
  late UserRepositoryImpl users;
  late SettingsRepositoryImpl settings;

  setUpAll(() async {
    await DateFormatter.init();
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    users = UserRepositoryImpl(db);
    settings = SettingsRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  Future<void> enableMultiUser() =>
      settings.setValue(MultiUserSettings.keyEnabled, '1');

  Widget buildApp(InMemorySessionStore store) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionStoreProvider.overrideWithValue(store),
      ],
      child: const KasirApp(),
    );
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  GoRouter routerOf(WidgetTester tester) {
    final context = tester.element(find.byType(Navigator).first);
    return GoRouter.of(context);
  }

  testWidgets(
    'AC-8.1: multi-user MATI → langsung ke layar Kasir, tanpa layar Masuk',
    (tester) async {
      await tester.pumpWidget(buildApp(InMemorySessionStore()));
      await tester.pumpAndSettle();

      expect(find.text('Siapa yang bertugas?'), findsNothing);
      expect(find.text('Kasir'), findsWidgets);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'multi-user AKTIF & belum masuk → layar Masuk dengan kartu nama '
    '(K-8.2: pilih nama dulu, baru PIN)',
    (tester) async {
      await enableMultiUser();
      await users.createUser(
        name: 'Pak Budi',
        role: UserRole.owner,
        pin: '111111',
      );
      await users.createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '222222',
      );

      await tester.pumpWidget(
        buildApp(InMemorySessionStore(multiUserEnabled: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Siapa yang bertugas?'), findsOneWidget);
      expect(find.text('Pak Budi'), findsOneWidget);
      expect(find.text('Ani'), findsOneWidget);
      expect(find.text('Pemilik'), findsOneWidget);
      // Keypad belum muncul sebelum nama dipilih.
      expect(find.text('7'), findsNothing);

      await tester.tap(find.text('Ani'));
      await tester.pumpAndSettle();

      expect(find.text('Halo, Ani'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'AC-8.15: PIN benar membuka aplikasi; PIN salah tidak membuka apa pun',
    (tester) async {
      await enableMultiUser();
      final ani = await users.createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '222222',
      );
      // Pemilik dengan PIN yang SAMA persis — keduanya harus tetap bisa
      // masuk ke akunnya masing-masing.
      await users.createUser(
        name: 'Pak Budi',
        role: UserRole.owner,
        pin: '222222',
      );

      final store = InMemorySessionStore(multiUserEnabled: true);
      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ani'));
      await tester.pumpAndSettle();

      Future<void> typePin(String pin) async {
        for (final digit in pin.split('')) {
          await tester.tap(find.text(digit).first);
          await tester.pump(const Duration(milliseconds: 130));
        }
        await tester.pumpAndSettle();
      }

      await typePin('999999');
      expect(find.text('PIN salah, coba lagi.'), findsOneWidget);
      expect(store.activeUserId, isNull);

      await typePin('222222');
      await tester.pumpAndSettle();

      expect(store.activeUserId, ani.id);
      expect(find.text('Siapa yang bertugas?'), findsNothing);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'AC-8.4: Kasir yang membuka rute Laporan langsung tetap DITOLAK',
    (tester) async {
      await enableMultiUser();
      final ani = await users.createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '222222',
      );

      await tester.pumpWidget(
        buildApp(
          InMemorySessionStore(multiUserEnabled: true, activeUserId: ani.id),
        ),
      );
      await tester.pumpAndSettle();

      // Sesi tersimpan → langsung masuk tanpa layar Masuk.
      expect(find.text('Siapa yang bertugas?'), findsNothing);

      routerOf(tester).go(AppRoutes.reports);
      await tester.pumpAndSettle();

      expect(find.text('Fitur ini hanya untuk Pemilik'), findsOneWidget);
      expect(find.text('Masuk sebagai Pemilik'), findsOneWidget);

      await disposeApp(tester);
    },
  );

  testWidgets('Pemilik tetap bisa membuka Laporan', (tester) async {
    await enableMultiUser();
    final budi = await users.createUser(
      name: 'Pak Budi',
      role: UserRole.owner,
      pin: '111111',
    );

    await tester.pumpWidget(
      buildApp(
        InMemorySessionStore(multiUserEnabled: true, activeUserId: budi.id),
      ),
    );
    await tester.pumpAndSettle();

    routerOf(tester).go(AppRoutes.reports);
    await tester.pumpAndSettle();

    expect(find.text('Fitur ini hanya untuk Pemilik'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets(
    'akun yang dinonaktifkan tidak muncul di layar Masuk & sesinya dilepas',
    (tester) async {
      await enableMultiUser();
      await users.createUser(
        name: 'Pak Budi',
        role: UserRole.owner,
        pin: '111111',
      );
      final ani = await users.createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '222222',
      );
      await users.setActive(userId: ani.id, isActive: false);

      final store = InMemorySessionStore(
        multiUserEnabled: true,
        activeUserId: ani.id,
      );
      await tester.pumpWidget(buildApp(store));
      await tester.pumpAndSettle();

      expect(find.text('Siapa yang bertugas?'), findsOneWidget);
      expect(find.text('Ani'), findsNothing);
      expect(store.activeUserId, isNull);

      await disposeApp(tester);
    },
  );
}
