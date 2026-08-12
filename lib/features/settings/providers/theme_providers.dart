import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci penyimpanan preferensi tema di `shared_preferences`.
///
/// **Sengaja BUKAN di tabel `settings`** (PRD v1.1 K-5.2): tema adalah
/// preferensi perangkat & mata penggunanya, bukan data toko. Kalau ia ikut
/// masuk database, backup dari HP bertema gelap akan memaksakan tema gelap
/// ke HP tujuan saat restore (AC-5.4) — perilaku yang mengejutkan. Alasan
/// kedua: `shared_preferences` bisa dimuat di `main()` **sebelum**
/// `runApp()` tanpa membuka database, yang justru dibutuhkan supaya frame
/// pertama sudah bertema benar (AC-5.5, tidak ada kedip putih).
const String kThemeModePrefKey = 'theme_mode';

/// Default aplikasi = **Terang** (PRD §5.3.B) — pengguna v1.0 tidak boleh
/// mendapat kejutan visual saat memperbarui aplikasi.
const ThemeMode kDefaultThemeMode = ThemeMode.light;

/// Tempat preferensi tema dibaca & ditulis.
///
/// Dibuat sebagai abstraksi (bukan langsung `SharedPreferences`) karena
/// pembacaannya harus **sinkron**: `themeModeProvider` dipakai untuk frame
/// pertama, jadi tidak boleh ada `await` di jalur itu. `main()` yang
/// menyediakan implementasi yang sudah dimuat lebih dulu.
abstract interface class ThemeModeStore {
  /// Baca preferensi tersimpan. Sinkron, tanpa I/O.
  ThemeMode read();

  /// Simpan pilihan baru.
  Future<void> write(ThemeMode mode);
}

/// Implementasi produksi: `SharedPreferences` yang sudah dimuat di `main()`.
class SharedPrefsThemeModeStore implements ThemeModeStore {
  const SharedPrefsThemeModeStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  ThemeMode read() => themeModeFromStorage(_prefs.getString(kThemeModePrefKey));

  @override
  Future<void> write(ThemeMode mode) =>
      _prefs.setString(kThemeModePrefKey, themeModeToStorage(mode));
}

/// Implementasi tanpa penyimpanan — dipakai sebagai **default provider**.
///
/// Konsekuensinya: kalau `main()` lupa meng-override, aplikasi tetap jalan
/// dengan tema Terang dan pilihan pengguna hanya tidak bertahan. Itu jauh
/// lebih baik daripada `throw` yang membuat setiap widget test (dan semua
/// test M0–M6 yang membangun `KasirApp` tanpa tahu-menahu soal tema) mati
/// hanya karena fitur tampilan.
class InMemoryThemeModeStore implements ThemeModeStore {
  InMemoryThemeModeStore([this._mode = kDefaultThemeMode]);

  ThemeMode _mode;

  @override
  ThemeMode read() => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}

/// Sumber preferensi tema. Di-override di `main()` dengan
/// [SharedPrefsThemeModeStore] yang sudah memuat nilainya sebelum
/// `runApp()`.
final Provider<ThemeModeStore> themeModeStoreProvider = Provider<ThemeModeStore>(
  (ref) => InMemoryThemeModeStore(),
);

/// Mode tema aktif: Terang / Gelap / Ikuti Sistem.
///
/// Dibaca `MaterialApp.router` lewat `themeMode:`; perubahannya berlaku
/// seketika ke seluruh layar tanpa restart (AC-5.1).
final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(themeModeStoreProvider).read();

  /// Ganti mode & simpan. Kegagalan menyimpan (storage penuh, dsb.) tidak
  /// boleh membatalkan perubahan tampilan — pengguna sudah menekan tombol,
  /// yang dilihatnya harus berubah.
  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(themeModeStoreProvider).write(mode);
  }
}

/// `ThemeMode` → teks yang disimpan (`light` | `dark` | `system`).
String themeModeToStorage(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

/// Teks tersimpan → `ThemeMode`. Nilai tak dikenal / belum pernah diisi
/// jatuh ke [kDefaultThemeMode].
ThemeMode themeModeFromStorage(String? raw) => switch (raw) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  _ => kDefaultThemeMode,
};

/// Label Bahasa Indonesia untuk tiap mode (dipakai kartu "Tampilan").
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Terang',
  ThemeMode.dark => 'Gelap',
  ThemeMode.system => 'Ikuti Sistem',
};
