import 'package:drift/drift.dart';

import 'app_database.dart' as db;

/// Penulis buku besar poin — SATU-SATUNYA tempat di seluruh aplikasi yang
/// boleh mengubah `customers.points` (K-7.2).
///
/// Dipakai bersama oleh `SaleRepositoryImpl` (earn/redeem saat menyimpan
/// penjualan, void_return saat membatalkan) dan `CustomerRepositoryImpl`
/// (adjust/merge). Alasannya sederhana: bila dua tempat berbeda boleh
/// menulis saldo dengan caranya masing-masing, invarian "saldo == jumlah
/// entri buku besar" (AC-7.11) cuma soal waktu sebelum melenceng.
///
/// SELURUH fungsi di sini WAJIB dipanggil DARI DALAM `db.transaction()`
/// milik pemanggil — kelas ini sengaja tidak membuka transaksi sendiri
/// supaya penulisan poin selalu atomik bersama transaksi yang memicunya.
abstract final class PointLedger {
  /// Menulis satu entri buku besar untuk [customerId] dan memperbarui
  /// cache saldo, lalu mengembalikan saldo baru.
  ///
  /// [points] boleh negatif. Bila hasilnya akan **negatif**, saldo dipatok
  /// 0 dan entri yang tercatat adalah selisih yang benar-benar terpakai —
  /// dengan [note] yang menjelaskan sisanya (PRD §7.3.C). Pematokan
  /// seperti ini menjaga invarian AC-7.11 tetap utuh: yang tertulis di
  /// buku besar selalu persis sama dengan yang tertulis di saldo.
  static Future<int> write(
    db.AppDatabase database, {
    required int customerId,
    required String type,
    required int points,
    int? saleId,
    String? note,
    required int createdAtMillis,
  }) async {
    final customer = await (database.select(
      database.customers,
    )..where((c) => c.id.equals(customerId))).getSingleOrNull();
    if (customer == null) return 0;

    final currentBalance = customer.points;
    var appliedPoints = points;
    var newBalance = currentBalance + points;
    var effectiveNote = note;

    if (newBalance < 0) {
      final diabaikan = -newBalance;
      appliedPoints = -currentBalance;
      newBalance = 0;
      effectiveNote = [
        if (note != null && note.isNotEmpty) note,
        'Saldo dipatok 0: $diabaikan poin tidak bisa ditarik karena sudah '
            'terpakai di transaksi lain.',
      ].join(' ');
    }

    await database.into(database.customerPointEntries).insert(
          db.CustomerPointEntriesCompanion.insert(
            customerId: customerId,
            saleId: Value(saleId),
            type: type,
            points: appliedPoints,
            balanceAfter: newBalance,
            note: Value(effectiveNote),
            createdAt: createdAtMillis,
          ),
        );

    await (database.update(
      database.customers,
    )..where((c) => c.id.equals(customerId))).write(
      db.CustomersCompanion(
        points: Value(newBalance),
        updatedAt: Value(createdAtMillis),
      ),
    );

    return newBalance;
  }

  /// Jumlah seluruh entri buku besar milik [customerId] — sumber kebenaran
  /// saldo (dipakai uji invarian AC-7.11 & aksi "hitung ulang saldo").
  static Future<int> ledgerSum(db.AppDatabase database, int customerId) async {
    final row = await database.customSelect(
      'SELECT COALESCE(SUM(points), 0) AS total FROM customer_point_entries '
      'WHERE customer_id = ?1',
      variables: [Variable.withInt(customerId)],
      readsFrom: {database.customerPointEntries},
    ).getSingle();
    return row.read<int>('total');
  }
}
