import 'package:drift/drift.dart';

import '../../core/utils/date_formatter.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_point_entry.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/repository_exceptions.dart';
import '../db/app_database.dart' as db;
import '../db/point_ledger.dart';

/// Implementasi [CustomerRepository] di atas Drift/SQLite (PRD v1.1 §7).
///
/// Dua aturan yang membentuk seluruh isi berkas ini:
///
/// 1. **Agregasi di SQL, bukan di Dart.** Sisa hutang, total belanja, dan
///    tanggal transaksi terakhir dihitung lewat subquery berkorelasi yang
///    memakai index `idx_sales_customer` — bukan dengan memuat transaksi
///    ke memori (AC-7.14, AC-7.15), pola yang sama dengan
///    `ReportRepositoryImpl`.
/// 2. **Saldo poin hanya boleh berubah lewat [PointLedger].** Tidak ada
///    satu pun `UPDATE customers SET points = …` di luar sana (AC-7.11).
class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl(this._db);

  final db.AppDatabase _db;

  static const String _debtUnpaid = 'debt_unpaid';
  static const String _voided = 'voided';

  /// Tiga angka ringkasan yang selalu ikut tiap baris daftar pelanggan.
  static const String _listAggregates =
      "(SELECT COALESCE(SUM(s.total), 0) FROM sales s "
      " WHERE s.customer_id = c.id AND s.status = 'debt_unpaid') AS total_debt, "
      "(SELECT COUNT(*) FROM sales s "
      " WHERE s.customer_id = c.id AND s.status = 'debt_unpaid') AS debt_count, "
      "(SELECT MAX(s.created_at) FROM sales s "
      " WHERE s.customer_id = c.id) AS last_at";

  @override
  Future<List<CustomerListItem>> search({
    String query = '',
    bool onlyWithDebt = false,
    bool includeInactive = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final trimmed = query.trim();
    final conditions = <String>[];
    final variables = <Variable>[];

    if (!includeInactive) conditions.add('is_active = 1');
    if (trimmed.isNotEmpty) {
      variables.add(Variable.withString('%${_escapeLike(trimmed)}%'));
      final n = variables.length;
      conditions.add(
        "(name LIKE ?$n ESCAPE '\\' COLLATE NOCASE "
        "OR IFNULL(phone, '') LIKE ?$n ESCAPE '\\' COLLATE NOCASE)",
      );
    }
    if (onlyWithDebt) {
      conditions.add(
        "EXISTS (SELECT 1 FROM sales s WHERE s.customer_id = customers.id "
        "AND s.status = '$_debtUnpaid')",
      );
    }

    // Daftar berfilter hutang diurutkan dari nominal terbesar (prioritas
    // penagihan); daftar biasa diurutkan alfabetis supaya bisa dipindai.
    final orderBy = onlyWithDebt
        ? "(SELECT COALESCE(SUM(s.total), 0) FROM sales s "
              "WHERE s.customer_id = customers.id "
              "AND s.status = '$_debtUnpaid') DESC, name COLLATE NOCASE ASC"
        : 'name COLLATE NOCASE ASC';

    variables
      ..add(Variable.withInt(limit))
      ..add(Variable.withInt(offset));
    final limitIndex = variables.length - 1;

    // Halaman dipilih DULU (subquery `c`), agregasinya dihitung SETELAH
    // itu — supaya subquery berkorelasi hanya jalan untuk baris yang
    // benar-benar ditampilkan, bukan untuk seluruh tabel pelanggan.
    final sql =
        'SELECT c.id AS id, c.name AS name, c.phone AS phone, '
        'c.points AS points, c.is_active AS is_active, $_listAggregates '
        'FROM (SELECT id, name, phone, points, is_active FROM customers '
        '${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')} '}'
        'ORDER BY $orderBy LIMIT ?$limitIndex OFFSET ?${limitIndex + 1}) c '
        'ORDER BY ${onlyWithDebt ? 'total_debt DESC, ' : ''}'
        'c.name COLLATE NOCASE ASC';

    final rows = await _db.customSelect(
      sql,
      variables: variables,
      readsFrom: {_db.customers, _db.sales},
    ).get();
    return rows.map(_toListItem).toList();
  }

  @override
  Future<List<CustomerListItem>> getAllForExport() async {
    final rows = await _db.customSelect(
      'SELECT c.id AS id, c.name AS name, c.phone AS phone, '
      'c.points AS points, c.is_active AS is_active, $_listAggregates '
      'FROM customers c ORDER BY c.name COLLATE NOCASE ASC',
      readsFrom: {_db.customers, _db.sales},
    ).get();
    return rows.map(_toListItem).toList();
  }

  @override
  Future<Map<int, int>> getTotalSpentByCustomer() async {
    final rows = await _db.customSelect(
      'SELECT customer_id AS id, COALESCE(SUM(total), 0) AS total '
      "FROM sales WHERE customer_id IS NOT NULL AND status != '$_voided' "
      'GROUP BY customer_id',
      readsFrom: {_db.sales},
    ).get();
    return {
      for (final row in rows) row.read<int>('id'): row.read<int>('total'),
    };
  }

  @override
  Future<Customer> getById(int id) async {
    final row = await (_db.select(
      _db.customers,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw const PelangganTidakDitemukanException();
    return _toCustomer(row);
  }

  @override
  Future<Customer> create({
    required String name,
    String? phone,
    String? note,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const NamaPelangganWajibException();
    await _assertNameAvailable(cleanName, exceptId: null);

    final now = DateFormatter.toEpochMillis(DateTime.now());
    final id = await _db.into(_db.customers).insert(
          db.CustomersCompanion.insert(
            name: cleanName,
            phone: Value(_orNull(phone)),
            note: Value(_orNull(note)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return getById(id);
  }

  @override
  Future<Customer> update(
    int id, {
    required String name,
    String? phone,
    String? note,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const NamaPelangganWajibException();
    await getById(id);
    await _assertNameAvailable(cleanName, exceptId: id);

    // `sales.customer_name` SENGAJA tidak ikut disentuh — snapshot struk
    // lama tidak boleh berubah gara-gara ganti nama (K-7.1, AC-7.3).
    await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
      db.CustomersCompanion(
        name: Value(cleanName),
        phone: Value(_orNull(phone)),
        note: Value(_orNull(note)),
        updatedAt: Value(DateFormatter.toEpochMillis(DateTime.now())),
      ),
    );
    return getById(id);
  }

  @override
  Future<void> deactivate(int id) async {
    await getById(id);
    final debt = await _unpaidDebtOf(id);
    if (debt > 0) throw PelangganMasihBerhutangException(debt);
    await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
      db.CustomersCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateFormatter.toEpochMillis(DateTime.now())),
      ),
    );
  }

  @override
  Future<void> reactivate(int id) async {
    final customer = await getById(id);
    if (customer.isMerged) {
      throw const GabungPelangganTidakValidException(
        'pelanggan ini sudah digabung ke pelanggan lain dan tidak bisa '
        'diaktifkan kembali.',
      );
    }
    await _assertNameAvailable(customer.name, exceptId: id);
    await (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
      db.CustomersCompanion(
        isActive: const Value(true),
        updatedAt: Value(DateFormatter.toEpochMillis(DateTime.now())),
      ),
    );
  }

  @override
  Future<CustomerSummary> getSummary(int customerId) async {
    final customer = await getById(customerId);
    final row = await _db.customSelect(
      "SELECT "
      "(SELECT COALESCE(SUM(total), 0) FROM sales "
      " WHERE customer_id = ?1 AND status != '$_voided') AS total_spent, "
      "(SELECT COUNT(*) FROM sales "
      " WHERE customer_id = ?1 AND status != '$_voided') AS trx_count, "
      "(SELECT COALESCE(SUM(total), 0) FROM sales "
      " WHERE customer_id = ?1 AND status = '$_debtUnpaid') AS total_debt, "
      "(SELECT COUNT(*) FROM sales "
      " WHERE customer_id = ?1 AND status = '$_debtUnpaid') AS debt_count, "
      "(SELECT MAX(created_at) FROM sales WHERE customer_id = ?1) AS last_at",
      variables: [Variable.withInt(customerId)],
      readsFrom: {_db.sales},
    ).getSingle();

    final lastAt = row.readNullable<int>('last_at');
    return CustomerSummary(
      totalSpent: row.read<int>('total_spent'),
      transactionCount: row.read<int>('trx_count'),
      totalDebt: row.read<int>('total_debt'),
      debtTransactionCount: row.read<int>('debt_count'),
      points: customer.points,
      lastTransactionAt:
          lastAt == null ? null : DateFormatter.fromEpochMillis(lastAt),
    );
  }

  @override
  Future<List<Sale>> getSales(
    int customerId, {
    required int limit,
    required int offset,
  }) async {
    final rows = await (_db.select(_db.sales)
          ..where((s) => s.customerId.equals(customerId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(limit, offset: offset))
        .get();
    return rows.map(_toSale).toList();
  }

  @override
  Future<List<CustomerPointEntry>> getPointEntries(
    int customerId, {
    required int limit,
    required int offset,
  }) async {
    final rows = await _db.customSelect(
      'SELECT e.id AS id, e.customer_id AS customer_id, e.sale_id AS sale_id, '
      'e.type AS type, e.points AS points, e.balance_after AS balance_after, '
      'e.note AS note, e.created_at AS created_at, '
      's.invoice_number AS invoice_number '
      'FROM customer_point_entries e '
      'LEFT JOIN sales s ON s.id = e.sale_id '
      'WHERE e.customer_id = ?1 '
      'ORDER BY e.created_at DESC, e.id DESC LIMIT ?2 OFFSET ?3',
      variables: [
        Variable.withInt(customerId),
        Variable.withInt(limit),
        Variable.withInt(offset),
      ],
      readsFrom: {_db.customerPointEntries, _db.sales},
    ).get();

    return rows
        .map(
          (row) => CustomerPointEntry(
            id: row.read<int>('id'),
            customerId: row.read<int>('customer_id'),
            saleId: row.readNullable<int>('sale_id'),
            type: row.read<String>('type'),
            points: row.read<int>('points'),
            balanceAfter: row.read<int>('balance_after'),
            note: row.readNullable<String>('note'),
            createdAt: DateFormatter.fromEpochMillis(row.read<int>('created_at')),
            invoiceNumber: row.readNullable<String>('invoice_number'),
          ),
        )
        .toList();
  }

  @override
  Future<CustomerMergePreview> previewMerge(List<int> ids) async {
    final unique = ids.toSet().toList();
    if (unique.length < 2) {
      throw const GabungPelangganTidakValidException(
        'pilih minimal dua pelanggan.',
      );
    }
    final placeholders = List.generate(unique.length, (i) => '?${i + 1}').join(',');
    final variables = unique.map(Variable.withInt).toList();

    final row = await _db.customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM sales WHERE customer_id IN ($placeholders)) AS trx, '
      '(SELECT COALESCE(SUM(points), 0) FROM customers '
      ' WHERE id IN ($placeholders)) AS pts, '
      "(SELECT COALESCE(SUM(total), 0) FROM sales "
      " WHERE customer_id IN ($placeholders) AND status = '$_debtUnpaid') AS debt",
      variables: variables,
      readsFrom: {_db.sales, _db.customers},
    ).getSingle();

    return CustomerMergePreview(
      customerCount: unique.length,
      transactionCount: row.read<int>('trx'),
      totalPoints: row.read<int>('pts'),
      totalDebt: row.read<int>('debt'),
    );
  }

  @override
  Future<void> merge({
    required int targetId,
    required List<int> sourceIds,
  }) async {
    final sources = sourceIds.toSet().where((id) => id != targetId).toList();
    if (sources.isEmpty) {
      throw const GabungPelangganTidakValidException(
        'tidak ada pelanggan sumber selain pelanggan yang dipertahankan.',
      );
    }

    await _db.transaction(() async {
      final target = await (_db.select(
        _db.customers,
      )..where((c) => c.id.equals(targetId))).getSingleOrNull();
      if (target == null) throw const PelangganTidakDitemukanException();

      final now = DateFormatter.toEpochMillis(DateTime.now());

      for (final sourceId in sources) {
        final source = await (_db.select(
          _db.customers,
        )..where((c) => c.id.equals(sourceId))).getSingleOrNull();
        if (source == null) throw const PelangganTidakDitemukanException();

        // 1. Seluruh transaksi menunjuk pelanggan hasil gabungan.
        //    `sales.customer_name` sengaja TIDAK ikut diubah (K-7.1).
        await (_db.update(_db.sales)
              ..where((s) => s.customerId.equals(sourceId)))
            .write(db.SalesCompanion(customerId: Value(targetId)));

        // 2. Entri buku besar DIALIHKAN, bukan disalin — tidak ada satu
        //    baris pun yang hilang (AC-7.12).
        await (_db.update(_db.customerPointEntries)
              ..where((e) => e.customerId.equals(sourceId)))
            .write(db.CustomerPointEntriesCompanion(customerId: Value(targetId)));

        // 3. Sumber ditandai nonaktif + `merged_into_id` (K-7.7).
        await (_db.update(_db.customers)
              ..where((c) => c.id.equals(sourceId)))
            .write(
          db.CustomersCompanion(
            points: const Value(0),
            isActive: const Value(false),
            mergedIntoId: Value(targetId),
            updatedAt: Value(now),
          ),
        );
      }

      // 4. Saldo target = jumlah seluruh entri yang kini miliknya. Entri
      //    penanda `merge` sengaja bernilai 0 poin supaya invarian
      //    "saldo == jumlah entri" tetap utuh (AC-7.11).
      final total = await PointLedger.ledgerSum(_db, targetId);
      await (_db.update(_db.customers)..where((c) => c.id.equals(targetId)))
          .write(db.CustomersCompanion(points: Value(total), updatedAt: Value(now)));

      await _db.into(_db.customerPointEntries).insert(
            db.CustomerPointEntriesCompanion.insert(
              customerId: targetId,
              type: PointEntryType.merge,
              points: 0,
              balanceAfter: total,
              note: Value(
                '${sources.length} pelanggan digabung ke sini. '
                'Saldo gabungan $total poin.',
              ),
              createdAt: now,
            ),
          );
    });
  }

  @override
  Future<int> recalculatePointsFromLedger() async {
    return _db.transaction(() async {
      final rows = await _db.customSelect(
        'SELECT c.id AS id, c.points AS cached, '
        '(SELECT COALESCE(SUM(e.points), 0) FROM customer_point_entries e '
        ' WHERE e.customer_id = c.id) AS ledger '
        'FROM customers c',
        readsFrom: {_db.customers, _db.customerPointEntries},
      ).get();

      final now = DateFormatter.toEpochMillis(DateTime.now());
      var fixed = 0;
      for (final row in rows) {
        final cached = row.read<int>('cached');
        final ledger = row.read<int>('ledger');
        if (cached == ledger) continue;
        fixed++;
        final customerId = row.read<int>('id');

        // Buku besar adalah SUMBER KEBENARAN (K-7.2): yang diperbaiki
        // adalah cache-nya, bukan sebaliknya. Karena itu entri jejaknya
        // sengaja bernilai 0 poin — menuliskan selisih sebagai entri
        // sungguhan justru akan menggeser buku besar dan membuat
        // invarian AC-7.11 mengejar dirinya sendiri.
        await (_db.update(_db.customers)
              ..where((c) => c.id.equals(customerId)))
            .write(
          db.CustomersCompanion(points: Value(ledger), updatedAt: Value(now)),
        );
        await _db.into(_db.customerPointEntries).insert(
              db.CustomerPointEntriesCompanion.insert(
                customerId: customerId,
                type: PointEntryType.adjust,
                points: 0,
                balanceAfter: ledger,
                note: Value(
                  'Hitung ulang saldo dari buku besar: saldo tercatat '
                  '$cached, hasil buku besar $ledger.',
                ),
                createdAt: now,
              ),
            );
      }
      return fixed;
    });
  }

  Future<void> _assertNameAvailable(String name, {required int? exceptId}) async {
    final rows = await _db.customSelect(
      'SELECT id FROM customers '
      'WHERE is_active = 1 AND name = ?1 COLLATE NOCASE LIMIT 2',
      variables: [Variable.withString(name)],
      readsFrom: {_db.customers},
    ).get();
    final clash = rows.any((row) => row.read<int>('id') != exceptId);
    if (clash) throw NamaPelangganSudahAdaException(name);
  }

  Future<int> _unpaidDebtOf(int customerId) async {
    final row = await _db.customSelect(
      "SELECT COALESCE(SUM(total), 0) AS total FROM sales "
      "WHERE customer_id = ?1 AND status = '$_debtUnpaid'",
      variables: [Variable.withInt(customerId)],
      readsFrom: {_db.sales},
    ).getSingle();
    return row.read<int>('total');
  }

  static String _escapeLike(String raw) =>
      raw.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  static String? _orNull(String? raw) {
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  CustomerListItem _toListItem(QueryRow row) {
    final lastAt = row.readNullable<int>('last_at');
    return CustomerListItem(
      id: row.read<int>('id'),
      name: row.read<String>('name'),
      phone: row.readNullable<String>('phone'),
      points: row.read<int>('points'),
      totalDebt: row.read<int>('total_debt'),
      debtTransactionCount: row.read<int>('debt_count'),
      lastTransactionAt:
          lastAt == null ? null : DateFormatter.fromEpochMillis(lastAt),
      isActive: row.read<int>('is_active') == 1,
    );
  }

  Customer _toCustomer(db.Customer row) => Customer(
        id: row.id,
        name: row.name,
        phone: row.phone,
        note: row.note,
        points: row.points,
        isActive: row.isActive,
        mergedIntoId: row.mergedIntoId,
        createdAt: DateFormatter.fromEpochMillis(row.createdAt),
        updatedAt: DateFormatter.fromEpochMillis(row.updatedAt),
      );

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
        customerId: row.customerId,
        status: row.status,
        note: row.note,
        createdAt: DateFormatter.fromEpochMillis(row.createdAt),
        voidedAt:
            row.voidedAt == null ? null : DateFormatter.fromEpochMillis(row.voidedAt!),
        debtPaidAt: row.debtPaidAt == null
            ? null
            : DateFormatter.fromEpochMillis(row.debtPaidAt!),
      );
}
