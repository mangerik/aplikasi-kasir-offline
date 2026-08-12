import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/features/settings/providers/theme_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi tema (PRD v1.1 AC-5.2, AC-5.4, K-5.2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith(SharedPreferences prefs) {
    final c = ProviderContainer(
      overrides: [
        themeModeStoreProvider.overrideWithValue(
          SharedPrefsThemeModeStore(prefs),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('serialisasi', () {
    test('bolak-balik ThemeMode <-> teks tersimpan', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromStorage(themeModeToStorage(mode)), mode);
      }
    });

    test('nilai kosong / tak dikenal jatuh ke default Terang (PRD §5.3.B)', () {
      expect(themeModeFromStorage(null), ThemeMode.light);
      expect(themeModeFromStorage(''), ThemeMode.light);
      expect(themeModeFromStorage('amoled'), ThemeMode.light);
      expect(kDefaultThemeMode, ThemeMode.light);
    });

    test('label Bahasa Indonesia sesuai kartu Tampilan', () {
      expect(themeModeLabel(ThemeMode.light), 'Terang');
      expect(themeModeLabel(ThemeMode.dark), 'Gelap');
      expect(themeModeLabel(ThemeMode.system), 'Ikuti Sistem');
    });
  });

  group('persistensi', () {
    test('default Terang saat belum pernah diisi', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(containerWith(prefs).read(themeModeProvider), ThemeMode.light);
    });

    test('pilihan bertahan setelah aplikasi ditutup & dibuka lagi '
        '(AC-5.2)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await containerWith(
        prefs,
      ).read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(prefs.getString(kThemeModePrefKey), 'dark');

      // "Buka ulang aplikasi": container baru dari prefs yang sama.
      expect(containerWith(prefs).read(themeModeProvider), ThemeMode.dark);
    });

    test('Ikuti Sistem juga tersimpan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await containerWith(
        prefs,
      ).read(themeModeProvider.notifier).setMode(ThemeMode.system);
      expect(prefs.getString(kThemeModePrefKey), 'system');
      expect(containerWith(prefs).read(themeModeProvider), ThemeMode.system);
    });

    test('kunci yang dipakai ada di shared_preferences, BUKAN tabel settings '
        '— supaya restore backup tidak menyeret tema HP asal (AC-5.4, '
        'K-5.2)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await containerWith(
        prefs,
      ).read(themeModeProvider.notifier).setMode(ThemeMode.dark);

      expect(prefs.getKeys(), contains(kThemeModePrefKey));
      expect(kThemeModePrefKey, 'theme_mode');
    });
  });

  group('store tanpa penyimpanan (dipakai widget test & fallback)', () {
    test('membaca nilai awal dan menyimpan di memori', () async {
      final store = InMemoryThemeModeStore(ThemeMode.dark);
      expect(store.read(), ThemeMode.dark);
      await store.write(ThemeMode.system);
      expect(store.read(), ThemeMode.system);
    });

    test('aplikasi tetap jalan (Terang) bila main() lupa meng-override', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(themeModeProvider), ThemeMode.light);
    });
  });
}
