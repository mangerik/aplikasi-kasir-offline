import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/customer_debt.dart';
import '../../domain/entities/daily_summary.dart';
import '../../domain/entities/sale.dart';
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
