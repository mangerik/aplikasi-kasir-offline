import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/db/point_ledger.dart';
import 'package:kasir_warung/data/repositories/customer_repository_impl.dart';
import 'package:kasir_warung/data/repositories/sale_repository_impl.dart';
import 'package:kasir_warung/data/services/receipt_service.dart';
import 'package:kasir_warung/domain/entities/cart_item.dart';
import 'package:kasir_warung/domain/entities/customer_point_entry.dart';
import 'package:kasir_warung/domain/entities/points_settings.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/usecases/save_sale_usecase.dart';
import 'package:kasir_warung/domain/usecases/void_sale_usecase.dart';

/// Uji program poin end-to-end di atas database sungguhan (PRD v1.1 §7.3.C).
///
/// Fokusnya satu invarian yang tidak boleh pernah goyah:
/// **`customers.points` selalu sama dengan jumlah seluruh entri buku besar**
/// (AC-7.11). Kalau invarian itu pecah, yang terjadi di dunia nyata adalah
/// sengketa dengan pembeli di depan warung — dan pemilik tidak punya cara
/// membuktikan siapa yang benar.
void main() {
  late AppDatabase db;
  late SaleRepositoryImpl saleRepo;
  late CustomerRepositoryImpl customerRepo;
  late SaveSaleUsecase saveSale;
  late VoidSaleUsecase voidSale;

  const points = PointsSettings(
    enabled: true,
    rupiahPerPoint: 10000,
    valuePerPoint: 500,
    minRedeem: 10,
  );

  setUpAll(() async => DateFormatter.init());

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    saleRepo = SaleRepositoryImpl(db);
    customerRepo = CustomerRepositoryImpl(db);
    saveSale = SaveSaleUsecase(saleRepo);
    voidSale = VoidSaleUsecase(saleRepo);
  });

  tearDown(() async => db.close());

  /// Item bebas seharga [price] — cukup untuk menguji poin tanpa perlu
  /// menyiapkan produk & stok.
  CartItem item(int price) => CartItem(
        key: 'bebas_$price',
        name: 'Belanja',
        unit: 'pcs',
        qty: 1,
        sellPrice: price,
      );

  /// Invarian AC-7.11 untuk SELURUH pelanggan.
  Future<void> expectLedgerInvariant() async {
    final customers = await db.select(db.customers).get();
    for (final customer in customers) {
      final ledger = await PointLedger.ledgerSum(db, customer.id);
      expect(
        customer.points,
        ledger,
        reason: 'saldo pelanggan ${customer.name} (${customer.points}) '
            'harus sama dengan jumlah buku besarnya ($ledger)',
      );
      expect(customer.points, greaterThanOrEqualTo(0),
          reason: 'saldo poin tidak boleh negatif');
    }
  }

  group('perolehan poin', () {
    test('AC-7.7: belanja Rp37.000 → tepat 3 poin', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      final result = await saveSale(
        items: [item(37000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 40000,
        customerName: ani.name,
        customerId: ani.id,
        points: points,
      );

      expect(result.pointsEarned, 3);
      expect(result.pointsBalanceAfter, 3);
      expect((await customerRepo.getById(ani.id)).points, 3);
      await expectLedgerInvariant();
    });

    test('AC-7.7: belanja Rp9.999 → 0 poin, tanpa entri buku besar', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      final result = await saveSale(
        items: [item(9999)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 10000,
        customerId: ani.id,
        points: points,
      );

      expect(result.pointsEarned, 0);
      expect(await db.select(db.customerPointEntries).get(), isEmpty);
      await expectLedgerInvariant();
    });

    test('poin dihitung dari total SETELAH diskon transaksi', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      // 50.000 − 15.000 = 35.000 → 3 poin (bukan 5).
      final result = await saveSale(
        items: [item(50000)],
        transactionDiscount: 15000,
        paymentMethod: 'cash',
        paidAmount: 50000,
        customerId: ani.id,
        points: points,
      );
      expect(result.pointsEarned, 3);
    });

    test('K-7.5: transaksi HUTANG juga mendapat poin', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      final result = await saveSale(
        items: [item(25000)],
        transactionDiscount: 0,
        paymentMethod: 'debt',
        paidAmount: 0,
        customerName: ani.name,
        customerId: ani.id,
        points: points,
      );
      expect(result.status, 'debt_unpaid');
      expect(result.pointsEarned, 2);
      await expectLedgerInvariant();
    });

    test('transaksi TANPA pelanggan tidak menyentuh buku besar sama sekali',
        () async {
      await saveSale(
        items: [item(100000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 100000,
        points: points,
      );
      expect(await db.select(db.customerPointEntries).get(), isEmpty);
    });
  });

  group('AC-7.6: program poin MATI', () {
    test('tidak ada entri buku besar & saldo tetap 0', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      final result = await saveSale(
        items: [item(500000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 500000,
        customerId: ani.id,
        // default: PointsSettings() → enabled == false
      );

      expect(result.pointsEarned, 0);
      expect(result.pointsRedeemed, 0);
      expect(await db.select(db.customerPointEntries).get(), isEmpty);
      expect((await customerRepo.getById(ani.id)).points, 0);
    });

    test('struk teks tidak memuat satu pun kata "poin"', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      final result = await saveSale(
        items: [item(500000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 500000,
        customerId: ani.id,
      );

      final receipt = ReceiptService.formatReceiptText(result).toLowerCase();
      expect(receipt.contains('poin'), isFalse);
    });

    test('permintaan tukar poin diabaikan saat program mati', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      final result = await saveSale(
        items: [item(50000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 50000,
        customerId: ani.id,
        pointsRedeemed: 20,
      );
      expect(result.discount, 0);
      expect(result.pointsRedeemed, 0);
    });
  });

  group('penukaran poin', () {
    /// Menyiapkan pelanggan dengan saldo [target] poin lewat penjualan
    /// biasa (bukan menyuntik saldo langsung — jalurnya harus sama dengan
    /// jalur produksi).
    Future<int> customerWithPoints(String name, int target) async {
      final customer = await customerRepo.create(name: name);
      await saveSale(
        items: [item(target * 10000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: target * 10000,
        customerId: customer.id,
        points: points,
      );
      expect((await customerRepo.getById(customer.id)).points, target);
      return customer.id;
    }

    test(
      'AC-7.9: penukaran menghasilkan diskon transaksi yang benar & '
      'mengurangi saldo tepat sejumlah yang ditukar',
      () async {
        final id = await customerWithPoints('Bu Ani', 20);
        // 10 poin x Rp500 = Rp5.000 potongan.
        final result = await saveSale(
          items: [item(30000)],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 30000,
          customerId: id,
          pointsRedeemed: 10,
          points: points,
        );

        expect(result.discount, 5000);
        expect(result.total, 25000);
        expect(result.pointsRedeemed, 10);
        expect(result.pointsRedeemedValue, 5000);
        // 20 − 10 ditukar + 2 didapat dari belanja Rp25.000.
        expect((await customerRepo.getById(id)).points, 12);
        await expectLedgerInvariant();
      },
    );

    test('AC-7.9: struk mencetak baris "Tukar poin"', () async {
      final id = await customerWithPoints('Bu Ani', 20);
      final result = await saveSale(
        items: [item(30000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 30000,
        customerId: id,
        pointsRedeemed: 10,
        points: points,
      );

      final receipt = ReceiptService.formatReceiptText(result);
      expect(receipt, contains('Tukar poin (10 poin)'));
      expect(receipt, contains('Rp5.000'));

      // Struk yang dibagikan ulang dari layar Detail juga memuatnya.
      final reloaded = await saleRepo.getDetail(result.saleId);
      expect(reloaded.pointsRedeemed, 10);
      expect(
        ReceiptService.formatReceiptText(reloaded),
        contains('Tukar poin (10 poin)'),
      );
    });

    test(
      'AC-7.10: poin TIDAK pernah diberikan atas nilai potongan penukaran',
      () async {
        final id = await customerWithPoints('Bu Ani', 40);
        // Belanja 40.000, tukar 20 poin (= Rp10.000) → total 30.000.
        // Poin didapat harus 3 (dari 30.000), BUKAN 4 (dari 40.000).
        final result = await saveSale(
          items: [item(40000)],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 30000,
          customerId: id,
          pointsRedeemed: 20,
          points: points,
        );
        expect(result.total, 30000);
        expect(result.pointsEarned, 3);
        await expectLedgerInvariant();
      },
    );

    test('menukar lebih dari saldo ditolak, transaksi TIDAK tersimpan',
        () async {
      final id = await customerWithPoints('Bu Ani', 10);
      await expectLater(
        saveSale(
          items: [item(50000)],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 50000,
          customerId: id,
          pointsRedeemed: 99,
          points: points,
        ),
        throwsA(isA<PoinTidakCukupException>()),
      );

      // Rollback penuh: hanya penjualan penyiap saldo yang tersimpan.
      expect(await db.select(db.sales).get(), hasLength(1));
      expect((await customerRepo.getById(id)).points, 10);
      await expectLedgerInvariant();
    });
  });

  group('AC-7.8: void transaksi', () {
    test('poin ditarik kembali & entri pembatalan merujuk sale_id', () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      final result = await saveSale(
        items: [item(50000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 50000,
        customerId: ani.id,
        points: points,
      );
      expect((await customerRepo.getById(ani.id)).points, 5);

      await voidSale(result.saleId);

      expect((await customerRepo.getById(ani.id)).points, 0);
      final entries = await customerRepo.getPointEntries(
        ani.id,
        limit: 50,
        offset: 0,
      );
      final reversal = entries.where(
        (e) => e.type == PointEntryType.voidReturn && e.saleId == result.saleId,
      );
      expect(reversal, hasLength(1));
      expect(reversal.single.points, -5);
      await expectLedgerInvariant();
    });

    test('poin yang sempat ditukar dikembalikan sebagai entri terpisah',
        () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      await saveSale(
        items: [item(200000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 200000,
        customerId: ani.id,
        points: points,
      );
      expect((await customerRepo.getById(ani.id)).points, 20);

      final redeemSale = await saveSale(
        items: [item(30000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 30000,
        customerId: ani.id,
        pointsRedeemed: 10,
        points: points,
      );
      // 20 − 10 + 2 = 12.
      expect((await customerRepo.getById(ani.id)).points, 12);

      await voidSale(redeemSale.saleId);

      // Saldo kembali seperti sebelum transaksi itu: 20.
      expect((await customerRepo.getById(ani.id)).points, 20);
      final entries = await customerRepo.getPointEntries(
        ani.id,
        limit: 50,
        offset: 0,
      );
      final reversals = entries.where(
        (e) =>
            e.type == PointEntryType.voidReturn && e.saleId == redeemSale.saleId,
      );
      expect(reversals, hasLength(2), reason: 'dua entri terpisah (PRD §7.3.C)');
      expect(reversals.map((e) => e.points).toList()..sort(), [-2, 10]);
      await expectLedgerInvariant();
    });

    test(
      'saldo dipatok 0 (tidak negatif) & entri mencatat selisihnya',
      () async {
        final ani = await customerRepo.create(name: 'Bu Ani');
        final earning = await saveSale(
          items: [item(100000)],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 100000,
          customerId: ani.id,
          points: points,
        );
        expect((await customerRepo.getById(ani.id)).points, 10);

        // Poinnya terlanjur dipakai di transaksi LAIN.
        await saveSale(
          items: [item(9000)],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: 9000,
          customerId: ani.id,
          pointsRedeemed: 10,
          points: points,
        );
        expect((await customerRepo.getById(ani.id)).points, 0);

        // Void transaksi pertama: 10 poin harus ditarik, tapi saldo 0.
        await voidSale(earning.saleId);

        final after = await customerRepo.getById(ani.id);
        expect(after.points, 0);
        final entries = await customerRepo.getPointEntries(
          ani.id,
          limit: 50,
          offset: 0,
        );
        final reversal = entries.firstWhere(
          (e) =>
              e.type == PointEntryType.voidReturn && e.saleId == earning.saleId,
        );
        expect(reversal.points, 0, reason: 'tidak ada saldo yang bisa ditarik');
        expect(reversal.note, contains('dipatok 0'));
        await expectLedgerInvariant();
      },
    );
  });

  group('AC-7.12: penggabungan pelanggan', () {
    test('3 pelanggan digabung: transaksi & poin utuh, saldo dijumlahkan',
        () async {
      final a = await customerRepo.create(name: 'Bu Ani');
      final b = await customerRepo.create(name: 'Ani');
      final c = await customerRepo.create(name: 'Bu Ani Warung');

      for (final entry in [(a.id, 30000), (b.id, 20000), (c.id, 50000)]) {
        await saveSale(
          items: [item(entry.$2)],
          transactionDiscount: 0,
          paymentMethod: 'cash',
          paidAmount: entry.$2,
          customerId: entry.$1,
          points: points,
        );
      }
      final expectedPoints = 3 + 2 + 5;
      final entriesBefore = (await db.select(db.customerPointEntries).get()).length;

      await customerRepo.merge(targetId: a.id, sourceIds: [b.id, c.id]);

      final target = await customerRepo.getById(a.id);
      expect(target.points, expectedPoints);

      final sales = await db.select(db.sales).get();
      expect(sales.every((s) => s.customerId == a.id), isTrue);

      // Tidak ada entri buku besar yang hilang — hanya berpindah pemilik
      // (+1 entri penanda `merge` bernilai 0 poin).
      final entriesAfter = await db.select(db.customerPointEntries).get();
      expect(entriesAfter.length, entriesBefore + 1);
      expect(
        entriesAfter.where((e) => e.customerId != a.id),
        isEmpty,
      );
      expect(
        entriesAfter.where((e) => e.type == PointEntryType.merge).single.points,
        0,
      );

      // Sumber ditandai nonaktif + merged_into_id (K-7.7).
      for (final sourceId in [b.id, c.id]) {
        final source = await customerRepo.getById(sourceId);
        expect(source.isActive, isFalse);
        expect(source.mergedIntoId, a.id);
        expect(source.points, 0);
      }
      await expectLedgerInvariant();
    });

    test('hutang ikut berpindah & totalnya tidak berubah', () async {
      final a = await customerRepo.create(name: 'Bu Ani');
      final b = await customerRepo.create(name: 'bu ani lama');
      for (final entry in [(a.id, 25000), (b.id, 15000)]) {
        await saveSale(
          items: [item(entry.$2)],
          transactionDiscount: 0,
          paymentMethod: 'debt',
          paidAmount: 0,
          customerName: 'x',
          customerId: entry.$1,
          points: points,
        );
      }

      await customerRepo.merge(targetId: a.id, sourceIds: [b.id]);

      final debtors = await customerRepo.search(onlyWithDebt: true);
      expect(debtors, hasLength(1));
      expect(debtors.single.totalDebt, 40000);
      expect(debtors.single.debtTransactionCount, 2);
    });
  });

  test(
    'AC-7.11: invarian saldo == jumlah buku besar bertahan setelah '
    'rangkaian ACAK jual/void/tukar/gabung',
    () async {
      final random = Random(20260812);
      final ids = <int>[];
      for (var i = 0; i < 5; i++) {
        ids.add((await customerRepo.create(name: 'Pelanggan $i')).id);
      }

      final saleIds = <int>[];
      for (var step = 0; step < 60; step++) {
        final action = random.nextInt(10);
        final customerId = ids[random.nextInt(ids.length)];
        final alive = await customerRepo.getById(customerId);
        if (!alive.isActive) continue;

        if (action < 5) {
          // Jual.
          final price = (random.nextInt(12) + 1) * 10000;
          final result = await saveSale(
            items: [item(price)],
            transactionDiscount: 0,
            paymentMethod: random.nextBool() ? 'cash' : 'debt',
            paidAmount: price,
            customerName: alive.name,
            customerId: customerId,
            points: points,
          );
          saleIds.add(result.saleId);
        } else if (action < 7) {
          // Tukar poin bila cukup.
          final balance = alive.points;
          if (balance < points.minRedeem) continue;
          final redeem = points.minRedeem;
          final price = 60000;
          final result = await saveSale(
            items: [item(price)],
            transactionDiscount: 0,
            paymentMethod: 'cash',
            paidAmount: price,
            customerName: alive.name,
            customerId: customerId,
            pointsRedeemed: redeem,
            points: points,
          );
          saleIds.add(result.saleId);
        } else if (action < 9) {
          // Void transaksi acak yang belum pernah di-void.
          if (saleIds.isEmpty) continue;
          final saleId = saleIds[random.nextInt(saleIds.length)];
          try {
            await voidSale(saleId);
          } on TransaksiSudahDibatalkanException {
            // wajar dalam rangkaian acak.
          }
        } else {
          // Gabungkan dua pelanggan aktif.
          final actives = <int>[];
          for (final id in ids) {
            if ((await customerRepo.getById(id)).isActive) actives.add(id);
          }
          if (actives.length < 2) continue;
          await customerRepo.merge(
            targetId: actives.first,
            sourceIds: [actives[1]],
          );
        }

        await expectLedgerInvariant();
      }

      // Dan aksi pemeliharaan tidak menemukan satu pun selisih.
      expect(await customerRepo.recalculatePointsFromLedger(), 0);
      await expectLedgerInvariant();
    },
  );

  test(
    'aksi "hitung ulang saldo dari buku besar" memperbaiki cache yang '
    'melenceng & mencatat koreksinya',
    () async {
      final ani = await customerRepo.create(name: 'Bu Ani');
      await saveSale(
        items: [item(50000)],
        transactionDiscount: 0,
        paymentMethod: 'cash',
        paidAmount: 50000,
        customerId: ani.id,
        points: points,
      );

      // Rusak cache-nya dengan sengaja (mensimulasikan data lama/korup).
      await db.customStatement(
        'UPDATE customers SET points = 999 WHERE id = ?1',
        [ani.id],
      );

      expect(await customerRepo.recalculatePointsFromLedger(), 1);
      expect((await customerRepo.getById(ani.id)).points, 5);

      final entries = await customerRepo.getPointEntries(
        ani.id,
        limit: 10,
        offset: 0,
      );
      expect(entries.first.type, PointEntryType.adjust);
      expect(entries.first.note, contains('Hitung ulang saldo'));
      await expectLedgerInvariant();
    },
  );
}
