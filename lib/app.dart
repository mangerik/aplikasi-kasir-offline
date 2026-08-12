import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_palette.dart';
import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/db/database_provider.dart';
import 'data/services/seed_data_service.dart';
import 'features/settings/providers/theme_providers.dart';

/// Root widget aplikasi: `MaterialApp.router` + tema + navigasi
/// (lihat architecture.md §3).
class KasirApp extends ConsumerStatefulWidget {
  const KasirApp({super.key});

  @override
  ConsumerState<KasirApp> createState() => _KasirAppState();
}

class _KasirAppState extends ConsumerState<KasirApp> {
  @override
  void initState() {
    super.initState();
    // Seed data contoh hanya berjalan di kDebugMode dan hanya jika tabel
    // produk masih kosong (lihat SeedDataService). Dijalankan di
    // background, tidak memblokir frame pertama.
    final db = ref.read(databaseProvider);
    SeedDataService(db).seedIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    // Mode tema (PRD v1.1 §5.3.C): nilainya sudah dimuat dari
    // shared_preferences sebelum runApp(), jadi frame pertama langsung benar.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Kasir Warung',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      // Status bar & tombol navigasi sistem ikut dibalik (AC-5.9).
      // `AppBarTheme.systemOverlayStyle` hanya berlaku di layar yang PUNYA
      // AppBar; pembungkus di sini menutup sisanya (layar PIN, layar sukses
      // transaksi, sheet penuh) supaya tidak ada ikon gelap di atas pita
      // gelap.
      builder: (context, child) {
        final palette = context.palette;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: palette.isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: palette.isDark
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarColor: palette.background,
            systemNavigationBarIconBrightness: palette.isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
