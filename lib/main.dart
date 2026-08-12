import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/date_formatter.dart';
import 'features/settings/providers/theme_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib dipanggil sebelum widget apa pun memakai DateFormatter (format
  // tanggal Indonesia, lihat core/utils/date_formatter.dart).
  await DateFormatter.init();

  // Preferensi tema dibaca SEBELUM runApp() (PRD v1.1 AC-5.5): kalau dibaca
  // setelahnya, frame pertama lahir bertema terang lalu berganti gelap —
  // "kedip putih" yang persis ingin dihindari mode gelap. `shared_preferences`
  // dipilih justru karena bisa dimuat di sini tanpa membuka database.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        themeModeStoreProvider.overrideWithValue(
          SharedPrefsThemeModeStore(prefs),
        ),
      ],
      child: const KasirApp(),
    ),
  );
}
