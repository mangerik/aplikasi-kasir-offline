import 'package:drift/drift.dart';

import 'customers_table.dart';
import 'sales_table.dart';

/// Buku besar poin pelanggan (PRD v1.1 §7.5, keputusan K-7.2) — pola yang
/// sama persis dengan `stock_movements`: setiap perubahan saldo punya satu
/// baris yang bisa diaudit, dan saldo di `customers.points` hanyalah cache
/// yang bisa dihitung ulang dari sini.
///
/// [type]:
/// - `earn` — poin dari transaksi tersimpan (+).
/// - `redeem` — poin ditukar jadi diskon transaksi (−).
/// - `void_return` — pembatalan transaksi: penarikan poin earn (−) dan
///   pengembalian poin yang sempat ditukar (+), dicatat sebagai dua entri
///   terpisah.
/// - `adjust` — koreksi manual / hasil "hitung ulang saldo dari ledger".
/// - `merge` — penanda penggabungan pelanggan (selalu `points = 0` supaya
///   invarian saldo tidak terganggu; entri asli dialihkan, bukan disalin).
///
/// [points] bilangan bulat (K-7.3): `+dapat` / `−pakai`.
/// [balanceAfter] saldo pelanggan SETELAH entri ini diterapkan.
class CustomerPointEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get customerId => integer().references(Customers, #id)();

  IntColumn get saleId => integer().nullable().references(Sales, #id)();

  TextColumn get type => text()();

  IntColumn get points => integer()();

  IntColumn get balanceAfter => integer()();

  TextColumn get note => text().nullable()();

  /// Epoch millis UTC.
  IntColumn get createdAt => integer()();
}
