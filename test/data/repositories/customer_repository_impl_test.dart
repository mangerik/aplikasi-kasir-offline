import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/customer_repository_impl.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';

/// Uji `CustomerRepositoryImpl` (PRD v1.1 §7) — CRUD, pencarian, ringkasan,
/// dan aturan nonaktif.
void main() {
  late AppDatabase db;
  late CustomerRepositoryImpl repo;
  late SaleRepositoryImpl saleRepo;

  setUpAll(() async => DateFormatter.init());

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CustomerRepositoryImpl(db);
    saleRepo = SaleRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  Future<int> sell({
    required int customerId,
    required String customerName,
    required int price,
    String method = 'cash',
  }) async {
    final result = await saleRepo.saveSale(
      items: [
        CartItem(
          key: 'bebas',
          name: 'Belanja',
          unit: 'pcs',
          qty: 1,
          sellPrice: price,
        ),
      ],
      transactionDiscount: 0,
      paymentMethod: method,
      paidAmount: method == 'cash' ? price : 0,
      customerName: customerName,
      customerId: customerId,
    );
    return result.saleId;
  }

  group('create & update', () {
    test('nama di-trim & tersimpan apa adanya', () async {
      final customer = await repo.create(name: '  Bu Ani  ', phone: ' 0812 ');
      expect(customer.name, 'Bu Ani');
      expect(customer.phone, '0812');
      expect(customer.points, 0);
      expect(customer.isActive, isTrue);
    });

    test('nama kosong ditolak', () async {
      await expectLater(
        repo.create(name: '   '),
        throwsA(isA<NamaPelangganWajibException>()),
      );
    });

    test('nama duplikat (beda kapitalisasi) ditolak untuk pelanggan AKTIF',
        () async {
      await repo.create(name: 'Bu Ani');
      await expectLater(
        repo.create(name: 'bu ani'),
        throwsA(isA<NamaPelangganSudahAdaException>()),
      );
    });

    test('nama yang sama boleh dipakai lagi setelah yang lama dinonaktifkan',
        () async {
      final lama = await repo.create(name: 'Bu Ani');
      await repo.deactivate(lama.id);
      final baru = await repo.create(name: 'Bu Ani');
      expect(baru.id, isNot(lama.id));
    });

    test(
      'AC-7.3: mengganti nama pelanggan TIDAK mengubah sales.customer_name',
      () async {
        final ani = await repo.create(name: 'Bu Ani');
        await sell(customerId: ani.id, customerName: 'Bu Ani', price: 20000);

        await repo.update(ani.id, name: 'Ibu Ani Sejahtera');

        final sales = await db.select(db.sales).get();
        expect(sales.single.customerName, 'Bu Ani');
        expect(sales.single.customerId, ani.id);
        expect((await repo.getById(ani.id)).name, 'Ibu Ani Sejahtera');
      },
    );

    test('getById melempar PelangganTidakDitemukanException', () async {
      await expectLater(
        repo.getById(404),
        throwsA(isA<PelangganTidakDitemukanException>()),
      );
    });
  });

  group('AC-7.13: nonaktifkan', () {
    test('pelanggan berhutang TIDAK bisa dinonaktifkan & pesannya jelas',
        () async {
      final ani = await repo.create(name: 'Bu Ani');
      await sell(
        customerId: ani.id,
        customerName: 'Bu Ani',
        price: 35000,
        method: 'debt',
      );

      await expectLater(
        repo.deactivate(ani.id),
        throwsA(
          isA<PelangganMasihBerhutangException>().having(
            (e) => e.toString(),
            'pesan',
            allOf(contains('masih punya hutang'), contains('Rp35.000')),
          ),
        ),
      );
      expect((await repo.getById(ani.id)).isActive, isTrue);
    });

    test('pelanggan tanpa hutang bisa dinonaktifkan & diaktifkan lagi',
        () async {
      final ani = await repo.create(name: 'Bu Ani');
      await repo.deactivate(ani.id);
      expect((await repo.getById(ani.id)).isActive, isFalse);
      await repo.reactivate(ani.id);
      expect((await repo.getById(ani.id)).isActive, isTrue);
    });

    test('pelanggan hasil gabung tidak bisa diaktifkan kembali (K-7.7)',
        () async {
      final a = await repo.create(name: 'Bu Ani');
      final b = await repo.create(name: 'Ani');
      await repo.merge(targetId: a.id, sourceIds: [b.id]);

      await expectLater(
        repo.reactivate(b.id),
        throwsA(isA<GabungPelangganTidakValidException>()),
      );
    });
  });

  group('pencarian & daftar', () {
    setUp(() async {
      for (final name in ['Bu Ani', 'Andi Warung Sebelah', 'Pak Joko']) {
        await repo.create(name: name, phone: name == 'Pak Joko' ? '08123' : null);
      }
    });

    test('cocokkan nama tanpa peduli kapitalisasi', () async {
      final results = await repo.search(query: 'an');
      expect(
        results.map((c) => c.name).toList(),
        ['Andi Warung Sebelah', 'Bu Ani'],
      );
    });

    test('cocokkan nomor HP juga', () async {
      final results = await repo.search(query: '0812');
      expect(results.single.name, 'Pak Joko');
    });

    test('daftar default hanya pelanggan aktif; includeInactive membukanya',
        () async {
      final joko = await repo.search(query: 'Joko');
      await repo.deactivate(joko.single.id);

      expect(await repo.search(query: 'Joko'), isEmpty);
      expect(
        (await repo.search(query: 'Joko', includeInactive: true)).single.name,
        'Pak Joko',
      );
    });

    test('onlyWithDebt menyaring & mengurutkan dari hutang terbesar', () async {
      final all = await repo.search();
      await sell(
        customerId: all[0].id,
        customerName: all[0].name,
        price: 10000,
        method: 'debt',
      );
      await sell(
        customerId: all[1].id,
        customerName: all[1].name,
        price: 90000,
        method: 'debt',
      );

      final debtors = await repo.search(onlyWithDebt: true);
      expect(debtors, hasLength(2));
      expect(debtors.first.totalDebt, 90000);
      expect(debtors.last.totalDebt, 10000);
    });

    test('paginasi lewat limit/offset', () async {
      final page1 = await repo.search(limit: 2, offset: 0);
      final page2 = await repo.search(limit: 2, offset: 2);
      expect(page1, hasLength(2));
      expect(page2, hasLength(1));
      expect(
        {...page1.map((c) => c.id), ...page2.map((c) => c.id)},
        hasLength(3),
      );
    });

    test('karakter LIKE (% dan _) tidak diperlakukan sebagai wildcard',
        () async {
      await repo.create(name: 'Toko 100% Murah');
      expect((await repo.search(query: '100%')).single.name, 'Toko 100% Murah');
      // Tanpa escape, '%' akan mencocokkan SEMUA pelanggan; dengan escape
      // ia hanya mencocokkan nama yang benar-benar memuat tanda persen.
      expect((await repo.search(query: '%')).single.name, 'Toko 100% Murah');
      expect(await repo.search(query: '_'), isEmpty);
    });
  });

  group('ringkasan', () {
    test('total belanja mengecualikan transaksi voided', () async {
      final ani = await repo.create(name: 'Bu Ani');
      await sell(customerId: ani.id, customerName: 'Bu Ani', price: 30000);
      final voided =
          await sell(customerId: ani.id, customerName: 'Bu Ani', price: 50000);
      await sell(
        customerId: ani.id,
        customerName: 'Bu Ani',
        price: 20000,
        method: 'debt',
      );
      await saleRepo.voidSale(voided);

      final summary = await repo.getSummary(ani.id);
      expect(summary.totalSpent, 50000);
      expect(summary.transactionCount, 2);
      expect(summary.totalDebt, 20000);
      expect(summary.debtTransactionCount, 1);
      expect(summary.lastTransactionAt, isNotNull);
    });

    test('riwayat belanja terpaginasi, terbaru dulu', () async {
      final ani = await repo.create(name: 'Bu Ani');
      for (var i = 0; i < 5; i++) {
        await sell(customerId: ani.id, customerName: 'Bu Ani', price: 1000 * (i + 1));
      }

      final page1 = await repo.getSales(ani.id, limit: 3, offset: 0);
      final page2 = await repo.getSales(ani.id, limit: 3, offset: 3);
      expect(page1, hasLength(3));
      expect(page2, hasLength(2));
      expect(page1.first.total, greaterThanOrEqualTo(page1.last.total));
    });
  });

  group('export', () {
    test('getAllForExport memuat pelanggan nonaktif juga, urut nama', () async {
      final joko = await repo.create(name: 'Pak Joko');
      await repo.create(name: 'Bu Ani');
      await repo.deactivate(joko.id);

      final rows = await repo.getAllForExport();
      expect(rows.map((c) => c.name).toList(), ['Bu Ani', 'Pak Joko']);
      expect(rows.last.isActive, isFalse);
    });

    test('getTotalSpentByCustomer mengecualikan voided', () async {
      final ani = await repo.create(name: 'Bu Ani');
      await sell(customerId: ani.id, customerName: 'Bu Ani', price: 30000);
      final voided =
          await sell(customerId: ani.id, customerName: 'Bu Ani', price: 70000);
      await saleRepo.voidSale(voided);

      expect(await repo.getTotalSpentByCustomer(), {ani.id: 30000});
    });
  });

  group('pratinjau gabung', () {
    test('menghitung transaksi, poin, dan hutang gabungan', () async {
      final a = await repo.create(name: 'Bu Ani');
      final b = await repo.create(name: 'Ani');
      await sell(customerId: a.id, customerName: 'Bu Ani', price: 25000, method: 'debt');
      await sell(customerId: b.id, customerName: 'Ani', price: 15000, method: 'debt');

      final preview = await repo.previewMerge([a.id, b.id]);
      expect(preview.customerCount, 2);
      expect(preview.transactionCount, 2);
      expect(preview.totalDebt, 40000);
    });

    test('kurang dari dua pelanggan ditolak', () async {
      final a = await repo.create(name: 'Bu Ani');
      await expectLater(
        repo.previewMerge([a.id]),
        throwsA(isA<GabungPelangganTidakValidException>()),
      );
      await expectLater(
        repo.merge(targetId: a.id, sourceIds: [a.id]),
        throwsA(isA<GabungPelangganTidakValidException>()),
      );
    });
  });
}
