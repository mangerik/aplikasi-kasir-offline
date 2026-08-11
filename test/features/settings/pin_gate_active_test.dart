import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/app.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/core/utils/pin_hasher.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';

/// Widget test end-to-end untuk gerbang PIN (plan.md Milestone 5 poin 6):
/// tab Laporan HARUS meminta PIN lewat [PinEntryScreen] (`checkPinGate`)
/// begitu `settings.pin_hash` terisi, menolak PIN salah, lalu mengizinkan
/// PIN yang benar. Terpisah dari `pin_gate_inactive_test.dart` — lihat
/// catatan di file itu soal singleton `appRouter` antar `testWidgets`.
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

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit).last);
      await tester.pump(const Duration(milliseconds: 20));
    }
    // Digit terakhir memicu `PinKeypad.onCompleted` -> validasi ASYNC
    // (`VerifyPinUsecase`, query Drift) sebelum layar bereaksi (error text
    // atau `Navigator.pop`) — `pumpAndSettle()` langsung setelah `tap()`
    // TIDAK cukup karena belum ada frame terjadwal persis di titik itu
    // (heuristik "settled"-nya keburu berhenti). Pump beberapa kali dengan
    // durasi eksplisit dulu untuk memberi waktu Future itu benar-benar
    // selesai sebelum melanjutkan.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('tab Laporan meminta PIN saat kunci aktif, menolak PIN salah, menerima PIN benar', (
    tester,
  ) async {
    final salt = PinHasher.generateSalt();
    await db.into(db.settings).insert(SettingsCompanion.insert(key: 'pin_salt', value: salt));
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: 'pin_hash', value: PinHasher.hash('123456', salt)));

    await tester.pumpWidget(
      ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const KasirApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laporan').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    // Belum berpindah tab — layar verifikasi PIN muncul dulu (menutupi
    // `NavigationBar` tab Kasir di belakangnya, jadi TIDAK dicek lewat
    // `find.byType(NavigationBar)` di sini — widget itu jadi "offstage").
    expect(find.text('Verifikasi PIN'), findsOneWidget);

    // PIN salah -> tetap di layar verifikasi dengan pesan error.
    await typePin(tester, '000000');
    expect(find.text('PIN salah, coba lagi.'), findsOneWidget);
    expect(find.text('Verifikasi PIN'), findsOneWidget);

    // PIN benar -> layar tertutup, pindah ke tab Laporan.
    await typePin(tester, '123456');
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi PIN'), findsNothing);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
