import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/db/database_provider.dart';
import 'data/services/seed_data_service.dart';

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
    return MaterialApp.router(
      title: 'Kasir Warung',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
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
