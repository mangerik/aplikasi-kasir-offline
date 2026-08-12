import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/constants/app_theme.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/database_provider.dart';
import 'package:kasir_warung/data/repositories/settings_repository_impl.dart';
import 'package:kasir_warung/features/settings/widgets/backup_reminder_banner.dart';

/// Gerbang rilis AC-10.6 — **pengingat backup > 7 hari** sebelum pembaruan
/// yang menaikkan `schemaVersion`.
///
/// Kenapa ini diuji di M15 dan bukan di milestone yang membangun banner-nya:
/// AC-10.6 bukan janji tentang layar, melainkan tentang **urutan rilis**.
/// Yang mengingatkan pengguna untuk backup sebelum migrasi berjalan adalah
/// aplikasi versi LAMA (v1.1.0) — aplikasi baru tidak punya kesempatan itu,
/// karena saat ia pertama kali dibuka migrasinya sudah selesai. Jadi yang
/// harus dibuktikan sebelum v1.2.0 dilepas adalah: banner yang sudah beredar
/// di v1.1.0 memang menyala pada ambang yang benar.
///
/// Ambangnya sengaja diuji di kedua sisi. Banner yang menyala terlalu sering
/// akan diabaikan justru pada hari ia paling penting.
void main() {
  late AppDatabase db;

  setUpAll(() async => DateFormatter.init());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> setLastBackup(DateTime when) {
    return SettingsRepositoryImpl(db).setValue(
      'last_backup_at',
      DateFormatter.toEpochMillis(when).toString(),
    );
  }

  Future<void> pump(WidgetTester tester, {ThemeMode mode = ThemeMode.light}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const Scaffold(
            body: SingleChildScrollView(child: BackupReminderBanner()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('belum pernah backup → pengingat tampil', (tester) async {
    await pump(tester);

    expect(find.text('Data belum pernah dicadangkan'), findsOneWidget);
    expect(find.textContaining('catatan penjualan ikut hilang'), findsOneWidget);
  });

  testWidgets('backup 8 hari lalu → pengingat tampil dengan jumlah harinya '
      '(AC-10.6)', (tester) async {
    await setLastBackup(DateTime.now().subtract(const Duration(days: 8)));
    await pump(tester);

    expect(find.text('Waktunya backup lagi'), findsOneWidget);
    expect(find.textContaining('Sudah 8 hari'), findsOneWidget);
  });

  testWidgets('backup tepat 7 hari lalu → BELUM mengingatkan (ambang "> 7")',
      (tester) async {
    await setLastBackup(
      DateTime.now().subtract(const Duration(days: 7, hours: 1)),
    );
    await pump(tester);

    expect(find.text('Waktunya backup lagi'), findsNothing);
    expect(find.text('Data belum pernah dicadangkan'), findsNothing);
  });

  testWidgets('backup kemarin → tidak ada pengingat sama sekali', (tester) async {
    await setLastBackup(DateTime.now().subtract(const Duration(days: 1)));
    await pump(tester);

    expect(find.byType(BackupReminderBanner), findsOneWidget);
    expect(find.text('Waktunya backup lagi'), findsNothing);
  });

  testWidgets('pengingat terbaca di mode gelap juga', (tester) async {
    await setLastBackup(DateTime.now().subtract(const Duration(days: 30)));
    await pump(tester, mode: ThemeMode.dark);

    expect(find.text('Waktunya backup lagi'), findsOneWidget);
    final theme = Theme.of(tester.element(find.byType(BackupReminderBanner)));
    expect(theme.brightness, Brightness.dark);
  });
}
