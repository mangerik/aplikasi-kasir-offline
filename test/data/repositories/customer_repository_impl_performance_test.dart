import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/customer_repository_impl.dart';

/// Uji performa pelanggan (PRD v1.1 AC-7.14 & AC-7.15).
///
/// Pola sama dengan `report_repository_impl_performance_test.dart`: data
/// disuntik lewat SQL massal (bukan lewat repository) supaya penyiapan
/// tidak ikut memakan waktu uji, lalu yang diukur HANYA query yang dipakai
/// layar sungguhan.
///
/// Ambangnya sengaja longgar dibanding target PRD — mesin CI/laptop
/// pengembang jauh lebih lambat dan lebih ramai daripada HP saat dipakai
/// berjualan. Yang dijaga uji ini adalah **kelas kompleksitasnya**: begitu
/// ada yang mengganti query berindeks dengan pemuatan seluruh tabel ke
/// Dart, angkanya akan meledak jauh melewati ambang ini.
void main() {
  late AppDatabase db;
  late CustomerRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CustomerRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  Future<void> seedCustomers(int count) async {
    await db.transaction(() async {
      for (var i = 0; i < count; i++) {
        await db.customStatement(
          'INSERT INTO customers (name, phone, points, is_active, created_at, '
          'updated_at) VALUES (?1, ?2, 0, 1, 1000, 1000)',
          ['Pelanggan ${i.toString().padLeft(5, '0')}', '0812${i + 100000}'],
        );
      }
    });
  }

  Future<void> seedSales(int customerId, int count) async {
    await db.transaction(() async {
      for (var i = 0; i < count; i++) {
        await db.customStatement(
          'INSERT INTO sales (invoice_number, subtotal, discount, total, '
          'payment_method, paid_amount, change_amount, customer_name, '
          'customer_id, status, created_at) '
          "VALUES (?1, 10000, 0, 10000, 'cash', 10000, 0, 'Pelanggan', ?2, "
          "'completed', ?3)",
          ['INV-$i', customerId, 1_700_000_000_000 + i],
        );
      }
    });
  }

  test(
    'AC-7.14: pencarian pada 2.000 pelanggan tetap cepat',
    () async {
      await seedCustomers(2000);

      final stopwatch = Stopwatch()..start();
      final results = await repo.search(query: 'Pelanggan 019');
      stopwatch.stop();

      expect(results, isNotEmpty);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason: 'pencarian pelanggan harus jauh di bawah setengah detik '
            '(target PRD di perangkat: < 100 ms)',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'AC-7.14: daftar halaman pertama pada 2.000 pelanggan tetap cepat',
    () async {
      await seedCustomers(2000);

      final stopwatch = Stopwatch()..start();
      final page = await repo.search(limit: 30);
      stopwatch.stop();

      expect(page, hasLength(30));
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'AC-7.15: detail pelanggan dengan 5.000 transaksi memuat halaman '
    'pertama saja',
    () async {
      await seedCustomers(1);
      final id = (await repo.search()).single.id;
      await seedSales(id, 5000);

      final summaryWatch = Stopwatch()..start();
      final summary = await repo.getSummary(id);
      summaryWatch.stop();
      expect(summary.transactionCount, 5000);
      expect(
        summaryWatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'ringkasan wajib agregasi SQL, bukan memuat 5.000 baris',
      );

      final pageWatch = Stopwatch()..start();
      final page = await repo.getSales(id, limit: 20, offset: 0);
      pageWatch.stop();
      expect(page, hasLength(20));
      expect(
        pageWatch.elapsedMilliseconds,
        lessThan(500),
        reason: 'riwayat belanja wajib dipaginasi lewat LIMIT/OFFSET',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('query daftar pelanggan memakai index, bukan full scan', () async {
    await seedCustomers(200);

    final plan = await db.customSelect(
      'EXPLAIN QUERY PLAN SELECT id FROM customers WHERE is_active = 1 '
      'ORDER BY name COLLATE NOCASE ASC LIMIT ?1',
      variables: [Variable.withInt(30)],
    ).get();
    final detail = plan.map((row) => row.read<String>('detail')).join(' | ');

    expect(
      detail.toLowerCase(),
      contains('idx_customers_name_nocase'),
      reason: 'pengurutan nama wajib memakai index parsial M12 supaya tidak '
          'ada SORT atas seluruh tabel',
    );
  });
}
