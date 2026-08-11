import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/settings_repository_impl.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/store_profile.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../domain/usecases/remove_pin_usecase.dart';
import '../../../domain/usecases/set_pin_usecase.dart';
import '../../../domain/usecases/verify_pin_usecase.dart';

/// Repository Pengaturan (lihat architecture.md §6 tabel Provider).
///
/// Dipakai lintas fitur sejak Milestone 3 sebagai hook PIN sebelum void
/// transaksi (`features/transactions/utils/pin_gate.dart`) — implementasi
/// PENUH layar Pengaturan (profil toko, threshold stok, PIN, backup) ada
/// di Milestone 5.
final Provider<SettingsRepository> settingsRepoProvider = Provider<SettingsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SettingsRepositoryImpl(database);
});

/// Profil toko (plan.md Milestone 5 poin 1) — dibaca dari
/// `settings.store_name/store_address/store_phone`. `FutureProvider` biasa
/// (bukan Stream) karena hanya berubah lewat aksi eksplisit "Simpan" di
/// layar Pengaturan — layar/widget yang menampilkannya (mis.
/// `ReceiptWidget`) memanggil `ref.invalidate(storeProfileProvider)`
/// setelah simpan berhasil.
final FutureProvider<StoreProfile> storeProfileProvider = FutureProvider<StoreProfile>((
  ref,
) async {
  final repo = ref.watch(settingsRepoProvider);
  final results = await Future.wait([
    repo.getValue('store_name'),
    repo.getValue('store_address'),
    repo.getValue('store_phone'),
  ]);
  return StoreProfile(name: results[0], address: results[1], phone: results[2]);
});

/// Threshold default stok menipis global (plan.md Milestone 5 poin 2,
/// key `settings.low_stock_default`) — fallback ke
/// [Product.defaultLowStockThreshold] bila belum pernah diisi pengguna.
final FutureProvider<double> lowStockDefaultProvider = FutureProvider<double>((ref) async {
  final raw = await ref.watch(settingsRepoProvider).getValue('low_stock_default');
  if (raw == null) return Product.defaultLowStockThreshold;
  return double.tryParse(raw) ?? Product.defaultLowStockThreshold;
});

/// `true` bila kunci PIN sedang aktif (plan.md Milestone 5 poin 6) — dipakai
/// layar Pengaturan (tombol Aktifkan/Ubah/Hapus PIN) dan gerbang navigasi
/// tab Laporan/Pengaturan (`MainShell`).
final FutureProvider<bool> pinActiveProvider = FutureProvider<bool>((ref) {
  return ref.watch(verifyPinUsecaseProvider).isPinActive();
});

final Provider<SetPinUsecase> setPinUsecaseProvider = Provider<SetPinUsecase>((ref) {
  return SetPinUsecase(ref.watch(settingsRepoProvider));
});

final Provider<VerifyPinUsecase> verifyPinUsecaseProvider = Provider<VerifyPinUsecase>((ref) {
  return VerifyPinUsecase(ref.watch(settingsRepoProvider));
});

final Provider<RemovePinUsecase> removePinUsecaseProvider = Provider<RemovePinUsecase>((ref) {
  return RemovePinUsecase(ref.watch(settingsRepoProvider), ref.watch(verifyPinUsecaseProvider));
});

/// Waktu backup terakhir (plan.md Milestone 5 poin 7, key
/// `settings.last_backup_at` — epoch millis UTC teks) — `null` bila belum
/// pernah backup sama sekali.
final FutureProvider<DateTime?> lastBackupAtProvider = FutureProvider<DateTime?>((ref) async {
  final raw = await ref.watch(settingsRepoProvider).getValue('last_backup_at');
  if (raw == null) return null;
  final millis = int.tryParse(raw);
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
});
