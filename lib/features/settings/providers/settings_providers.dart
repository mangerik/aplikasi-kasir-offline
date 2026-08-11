import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/settings_repository_impl.dart';
import '../../../domain/repositories/settings_repository.dart';

/// Repository Pengaturan (lihat architecture.md §6 tabel Provider).
///
/// Dipakai lintas fitur di Milestone 3 sebagai hook PIN sebelum void
/// transaksi (`features/transactions/utils/pin_gate.dart`) — implementasi
/// PENUH layar Pengaturan menyusul di Milestone 5.
final Provider<SettingsRepository> settingsRepoProvider = Provider<SettingsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SettingsRepositoryImpl(database);
});
