import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/held_cart.dart';
import '../../domain/repositories/held_cart_repository.dart';
import '../db/app_database.dart' as db;

/// Implementasi [HeldCartRepository] di atas Drift/SQLite.
///
/// Catatan penamaan: kelas baris hasil generate Drift untuk tabel
/// `HeldCarts` bernama `HeldCart` — sama dengan entity domain [HeldCart].
/// Seluruh tipe dari `app_database.dart` diakses lewat prefix `db.` (sama
/// seperti `ProductRepositoryImpl`/`CategoryRepositoryImpl`, lihat
/// docs/laporan-m1.md §2.2).
class HeldCartRepositoryImpl implements HeldCartRepository {
  HeldCartRepositoryImpl(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<HeldCart>> watchAll() {
    final statement = _db.select(_db.heldCarts)
      ..orderBy([(h) => OrderingTerm(expression: h.createdAt, mode: OrderingMode.desc)]);
    return statement.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<int> hold({
    String? label,
    required List<CartItem> items,
    required int transactionDiscount,
  }) async {
    final now = DateFormatter.toEpochMillis(DateTime.now());
    final cartJson = jsonEncode({
      'items': items.map((item) => item.toJson()).toList(),
      'transactionDiscount': transactionDiscount,
    });
    final trimmedLabel = label?.trim();
    return _db.into(_db.heldCarts).insert(
          db.HeldCartsCompanion.insert(
            label: Value(
              (trimmedLabel == null || trimmedLabel.isEmpty) ? null : trimmedLabel,
            ),
            cartJson: cartJson,
            createdAt: now,
          ),
        );
  }

  @override
  Future<HeldCart?> getById(int id) async {
    final row = await (_db.select(
      _db.heldCarts,
    )..where((h) => h.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.heldCarts)..where((h) => h.id.equals(id))).go();
  }

  HeldCart _toEntity(db.HeldCart row) {
    final decoded = jsonDecode(row.cartJson) as Map<String, dynamic>;
    final rawItems = decoded['items'] as List<dynamic>;
    final items = rawItems
        .map((raw) => CartItem.fromJson(raw as Map<String, dynamic>))
        .toList();
    final transactionDiscount = decoded['transactionDiscount'] as int? ?? 0;
    return HeldCart(
      id: row.id,
      label: row.label,
      items: items,
      transactionDiscount: transactionDiscount,
      createdAt: DateFormatter.fromEpochMillis(row.createdAt),
    );
  }
}
