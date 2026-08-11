import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/held_cart_repository_impl.dart';
import '../../../domain/entities/held_cart.dart';
import '../../../domain/repositories/held_cart_repository.dart';

/// Repository transaksi ditahan/parkir (lihat architecture.md §6 tabel
/// Provider, plan.md Milestone 2 poin 8).
final Provider<HeldCartRepository> heldCartRepoProvider = Provider<HeldCartRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return HeldCartRepositoryImpl(database);
});

/// Stream reaktif daftar transaksi yang sedang ditahan, dipakai layar
/// `held_carts_screen.dart` dan badge jumlah hold di layar Kasir.
final StreamProvider<List<HeldCart>> heldCartListProvider = StreamProvider<List<HeldCart>>((ref) {
  return ref.watch(heldCartRepoProvider).watchAll();
});
