import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/customer_debt.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sales_series.dart';
import '../../domain/entities/top_product.dart';
import '../../domain/repositories/report_repository.dart';
import '../db/app_database.dart' as db;

/// Implementasi [ReportRepository] di atas Drift/SQLite.
///
/// SELURUH agregasi (`SUM`/`COUNT`/`GROUP BY`) dijalankan di SQL lewat
/// `customSelect`/query builder Drift — BUKAN memuat semua baris ke Dart
/// lalu dijumlahkan manual — memakai index `sales(created_at)`/
/// `sales(status)`/`sale_items(sale_id)` yang sudah ada sejak M0 (lihat
/// architecture.md §4, plan.md Milestone 4 poin 8, dan
/// `test/data/repositories/report_repository_impl_performance_test.dart`
/// untuk uji performa di ≥50.000 transaksi).
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._db);

  final db.AppDatabase _db;

  static const String _voided = 'voided';
  static const String _debtUnpaid = 'debt_unpaid';

  @override
  Future<DailySummary> getSummary({
    required DateTime start,
    required DateTime end,
    int? userId,
  }) async {
    final startMillis = DateFormatter.toEpochMillis(start);
    final endMillis = DateFormatter.toEpochMillis(end);
    // Filter kasir (AC-8.9) ditempel sebagai klausa opsional supaya query
    // tanpa filter tetap persis seperti sebelumnya — angka laporan lama
    // tidak boleh bergeser sedikit pun karena fitur baru.
    final userClause = userId == null ? '' : ' AND user_id = $userId';
    final userClauseS = userId == null ? '' : ' AND s.user_id = $userId';

    final totalsRow = await _db.customSelect(
      'SELECT COUNT(*) AS cnt, COALESCE(SUM(total), 0) AS omzet '
      'FROM sales '
      'WHERE status != ?1 AND created_at BETWEEN ?2 AND ?3$userClause',
      variables: [
        Variable.withString(_voided),
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
      ],
      readsFrom: {_db.sales},
    ).getSingle();

    final profitRow = await _db.customSelect(
      'SELECT COALESCE(SUM('
      '  CASE WHEN si.cost_price IS NOT NULL '
      '  THEN si.line_total - si.cost_price * si.qty ELSE 0 END'
      '), 0) AS profit '
      'FROM sale_items si '
      'JOIN sales s ON s.id = si.sale_id '
      'WHERE s.status != ?1 AND s.created_at BETWEEN ?2 AND ?3$userClauseS',
      variables: [
        Variable.withString(_voided),
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
      ],
      readsFrom: {_db.saleItems, _db.sales},
    ).getSingle();

    final methodRows = await _db.customSelect(
      'SELECT payment_method, COUNT(*) AS cnt, COALESCE(SUM(total), 0) AS total '
      'FROM sales '
      'WHERE status != ?1 AND created_at BETWEEN ?2 AND ?3$userClause '
      'GROUP BY payment_method',
      variables: [
        Variable.withString(_voided),
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
      ],
      readsFrom: {_db.sales},
    ).get();

    return DailySummary(
      start: start,
      end: end,
      transactionCount: totalsRow.read<int>('cnt'),
      totalOmzet: totalsRow.read<int>('omzet'),
      grossProfit: profitRow.read<double>('profit').round(),
      byPaymentMethod: methodRows
          .map(
            (row) => PaymentMethodTotal(
              method: row.read<String>('payment_method'),
              count: row.read<int>('cnt'),
              total: row.read<int>('total'),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<TopProduct>> getTopProducts({
    required DateTime start,
    required DateTime end,
    int limit = 10,
    TopProductSort sortBy = TopProductSort.qty,
    int? userId,
  }) async {
    final startMillis = DateFormatter.toEpochMillis(start);
    final endMillis = DateFormatter.toEpochMillis(end);
    final orderColumn = sortBy == TopProductSort.value ? 'total_value' : 'qty_sold';
    final userClause = userId == null ? '' : ' AND s.user_id = $userId';

    final rows = await _db.customSelect(
      'SELECT si.product_id AS product_id, si.product_name AS product_name, '
      '  si.unit AS unit, SUM(si.qty) AS qty_sold, SUM(si.line_total) AS total_value '
      'FROM sale_items si '
      'JOIN sales s ON s.id = si.sale_id '
      'WHERE s.status != ?1 AND s.created_at BETWEEN ?2 AND ?3$userClause '
      'GROUP BY si.product_id, si.product_name, si.unit '
      'ORDER BY $orderColumn DESC '
      'LIMIT ?4',
      variables: [
        Variable.withString(_voided),
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
        Variable.withInt(limit),
      ],
      readsFrom: {_db.saleItems, _db.sales},
    ).get();

    return rows
        .map(
          (row) => TopProduct(
            productId: row.readNullable<int>('product_id'),
            productName: row.read<String>('product_name'),
            unit: row.read<String>('unit'),
            qtySold: row.read<double>('qty_sold'),
            totalValue: row.read<int>('total_value'),
          ),
        )
        .toList();
  }

  @override
  Future<List<CustomerDebt>> getUnpaidDebts() async {
    final rows = await _db.customSelect(
      'SELECT customer_name, COUNT(*) AS cnt, COALESCE(SUM(total), 0) AS total '
      'FROM sales '
      'WHERE status = ?1 AND customer_name IS NOT NULL '
      'GROUP BY customer_name '
      'ORDER BY total DESC',
      variables: [Variable.withString(_debtUnpaid)],
      readsFrom: {_db.sales},
    ).get();

    return rows
        .map(
          (row) => CustomerDebt(
            customerName: row.read<String>('customer_name'),
            totalDebt: row.read<int>('total'),
            transactionCount: row.read<int>('cnt'),
          ),
        )
        .toList();
  }

  /// Geseran zona waktu **perangkat** dalam milidetik, dibaca dari SQLite
  /// sendiri untuk momen [atMillis] (K-9.8).
  ///
  /// `strftime('%s', x, 'unixepoch', 'localtime')` mengembalikan epoch dari
  /// jam DINDING lokal; selisihnya terhadap epoch asli adalah geseran zona
  /// dalam detik — bilangan bulat, tanpa aritmetika `julianday` yang
  /// mengambang. Nilainya diambil untuk momen di dalam rentang yang
  /// diminta, bukan untuk "sekarang", supaya zona yang pernah berubah
  /// secara historis tetap benar untuk data lama.
  Future<int> _localOffsetMillis(int atMillis) async {
    final row = await _db.customSelect(
      "SELECT (strftime('%s', ?1 / 1000, 'unixepoch', 'localtime') - (?1 / 1000)) "
      'AS off_seconds',
      variables: [Variable.withInt(atMillis)],
    ).getSingle();
    return row.read<int>('off_seconds') * 1000;
  }

  /// Ekspresi SQL yang mengubah `sales.created_at` (epoch **millis UTC**,
  /// keputusan M0) menjadi kunci ember waktu **LOKAL** (PRD §9.5).
  ///
  /// Dua hal yang wajib ada dan mudah terlupakan:
  /// 1. `/ 1000` — `strftime` SQLite bekerja pada epoch DETIK.
  /// 2. `'unixepoch'` — memberi tahu SQLite bahwa angkanya epoch, bukan
  ///    Julian day.
  ///
  /// **Keputusan K-9.8 — geseran zona disuntikkan sebagai angka
  /// (`+ $offsetMillis`), BUKAN lewat modifier `'localtime'` per baris.**
  /// PRD §9.5 menuliskan `'localtime'`, dan hasilnya di sini **identik**
  /// (diverifikasi baris demi baris atas 100.000 transaksi:
  /// `report_series_test.dart`). Yang berbeda hanya harganya: `'localtime'`
  /// memaksa SQLite memanggil konversi zona sistem **sekali untuk setiap
  /// baris**, dan pada 100.000 transaksi itu berarti 218 ms untuk query
  /// omzet saja — sendirian sudah melewati anggaran 300 ms AC-9.5 sebelum
  /// query laba dijalankan. Dengan geseran yang dibaca sekali di muka
  /// (lewat `'localtime'` juga, di [_localOffsetMillis]), query yang sama
  /// selesai 54 ms.
  ///
  /// Batasnya jujur: cara ini menganggap geseran zona **tetap sepanjang
  /// rentang yang diminta**. Indonesia tidak menerapkan DST (PRD §9.5),
  /// jadi asumsi itu berlaku penuh di sini; pada zona ber-DST, transaksi di
  /// sisi lain batas pergantian bisa jatuh ke ember tetangga.
  static String _bucketKeyExpr(
    SeriesBucket bucket,
    String column,
    int offsetMillis,
  ) =>
      "strftime('${bucket.strftimeFormat}', ($column + $offsetMillis) / 1000, "
      "'unixepoch')";

  @override
  Future<List<SalesPoint>> getSalesSeries({
    required DateTime start,
    required DateTime end,
    required SeriesBucket bucket,
    int? userId,
  }) async {
    final startMillis = DateFormatter.toEpochMillis(start);
    final endMillis = DateFormatter.toEpochMillis(end);
    final userClause = userId == null ? '' : ' AND user_id = $userId';
    final userClauseS = userId == null ? '' : ' AND s.user_id = $userId';
    final offset = await _localOffsetMillis(startMillis);

    // DUA query agregat terpisah, BUKAN satu query dengan JOIN ke
    // `sale_items`: menggabungkannya membuat satu penjualan tergandakan
    // sebanyak barisnya sehingga `SUM(total)` ikut menggandakan omzet —
    // bug yang angkanya "hampir benar" dan karena itu paling berbahaya.
    // Alternatif subquery berkorelasi per penjualan menyentuh index
    // `sale_items(sale_id)` 100.000 kali; dua GROUP BY jauh lebih murah
    // (lihat report_repository_impl_performance_test.dart, AC-9.5).
    final omzetRows = await _db.customSelect(
      'SELECT ${_bucketKeyExpr(bucket, 'created_at', offset)} AS bucket_key, '
      '  COUNT(*) AS cnt, COALESCE(SUM(total), 0) AS omzet '
      'FROM sales '
      'WHERE status != ?1 AND created_at BETWEEN ?2 AND ?3$userClause '
      'GROUP BY bucket_key',
      variables: [
        Variable.withString(_voided),
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
      ],
      readsFrom: {_db.sales},
    ).get();

    final profitRows = await _db.customSelect(
      'SELECT ${_bucketKeyExpr(bucket, 's.created_at', offset)} AS bucket_key, '
      '  COALESCE(SUM('
      '    CASE WHEN si.cost_price IS NOT NULL '
      '    THEN si.line_total - si.cost_price * si.qty ELSE 0 END'
      '  ), 0) AS profit '
      'FROM sale_items si '
      'JOIN sales s ON s.id = si.sale_id '
      'WHERE s.status != ?1 AND s.created_at BETWEEN ?2 AND ?3$userClauseS '
      'GROUP BY bucket_key',
      variables: [
        Variable.withString(_voided),
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
      ],
      readsFrom: {_db.saleItems, _db.sales},
    ).get();

    final omzetByKey = {
      for (final row in omzetRows)
        row.read<String>('bucket_key'): (
          omzet: row.read<int>('omzet'),
          count: row.read<int>('cnt'),
        ),
    };
    final profitByKey = {
      for (final row in profitRows)
        row.read<String>('bucket_key'): row.read<double>('profit').round(),
    };

    // Pengisian ember kosong: SQL hanya mengembalikan ember yang PUNYA
    // transaksi, sedangkan grafik butuh sumbu waktu yang utuh (AC-9.1 &
    // AC-9.11). Ini pembentukan sumbu, bukan agregasi — K-9.5 tetap utuh.
    final points = <SalesPoint>[];
    final last = bucket.floor(end);
    var cursor = bucket.floor(start);
    // Jaring pengaman: rentang yang salah (mis. jam perangkat dimundurkan
    // jauh) tidak boleh berubah menjadi perulangan tak berujung. 1200 ember
    // sudah jauh di atas batas ~90 batang K-9.4.
    var guard = 0;
    while (!cursor.isAfter(last) && guard < 1200) {
      final key = bucket.keyOf(cursor);
      final totals = omzetByKey[key];
      points.add(
        SalesPoint(
          bucket: bucket,
          start: cursor,
          omzet: totals?.omzet ?? 0,
          grossProfit: profitByKey[key] ?? 0,
          transactionCount: totals?.count ?? 0,
        ),
      );
      cursor = bucket.next(cursor);
      guard++;
    }
    return points;
  }

  @override
  Future<List<HourlyPoint>> getHourlyDistribution({
    required DateTime start,
    required DateTime end,
    int? userId,
  }) async {
    final startMillis = DateFormatter.toEpochMillis(start);
    final endMillis = DateFormatter.toEpochMillis(end);
    final userClause = userId == null ? '' : ' AND user_id = $userId';
    final offset = await _localOffsetMillis(startMillis);

    final rows = await _db.customSelect(
      "SELECT CAST(strftime('%H', (created_at + $offset) / 1000, 'unixepoch') "
      '  AS INTEGER) AS hour_of_day, '
      '  COUNT(*) AS cnt, COALESCE(SUM(total), 0) AS omzet '
      'FROM sales '
      'WHERE status != ?1 AND created_at BETWEEN ?2 AND ?3$userClause '
      'GROUP BY hour_of_day',
      variables: [
        Variable.withString(_voided),
        Variable.withInt(startMillis),
        Variable.withInt(endMillis),
      ],
      readsFrom: {_db.sales},
    ).get();

    final byHour = {
      for (final row in rows)
        row.read<int>('hour_of_day'): (
          omzet: row.read<int>('omzet'),
          count: row.read<int>('cnt'),
        ),
    };

    // Selalu 24 baris: jam sepi adalah informasi, bukan ketiadaan data.
    return [
      for (var hour = 0; hour < 24; hour++)
        HourlyPoint(
          hour: hour,
          omzet: byHour[hour]?.omzet ?? 0,
          transactionCount: byHour[hour]?.count ?? 0,
        ),
    ];
  }

  @override
  Future<List<Sale>> getDebtTransactions(String customerName) async {
    final rows = await (_db.select(_db.sales)
          ..where((s) => s.status.equals(_debtUnpaid) & s.customerName.equals(customerName))
          ..orderBy([(s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc)]))
        .get();

    return rows.map(_toSale).toList();
  }

  Sale _toSale(db.Sale row) => Sale(
        id: row.id,
        invoiceNumber: row.invoiceNumber,
        subtotal: row.subtotal,
        discount: row.discount,
        total: row.total,
        paymentMethod: row.paymentMethod,
        paidAmount: row.paidAmount,
        changeAmount: row.changeAmount,
        customerName: row.customerName,
        status: row.status,
        note: row.note,
        createdAt: DateFormatter.fromEpochMillis(row.createdAt),
        voidedAt: row.voidedAt == null ? null : DateFormatter.fromEpochMillis(row.voidedAt!),
        debtPaidAt: row.debtPaidAt == null ? null : DateFormatter.fromEpochMillis(row.debtPaidAt!),
      );
}
