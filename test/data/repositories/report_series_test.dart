import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/date_formatter.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/report_repository_impl.dart';
import 'package:kasir_warung/domain/entities/sales_series.dart';

/// Agregasi SQL grafik penjualan (PRD v1.1 §9.5, M14).
///
/// Fokusnya: **angka grafik tidak boleh berbeda dari kartu ringkasan**.
/// Grafik yang cantik tapi angkanya meleset lebih buruk daripada tidak ada
/// grafik sama sekali — pemilik warung akan berhenti percaya keduanya.
void main() {
  late AppDatabase db;
  late ReportRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReportRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  var invoiceCounter = 0;

  /// Insert transaksi LANGSUNG supaya `createdAt` & `status` terkendali
  /// presisi (pola yang sama dengan `report_repository_impl_test.dart`).
  Future<int> insertSale({
    required DateTime at,
    int total = 10000,
    String status = 'completed',
    String paymentMethod = 'cash',
    int? userId,
  }) {
    invoiceCounter++;
    return db.into(db.sales).insert(
          SalesCompanion.insert(
            invoiceNumber: 'INV-$invoiceCounter',
            subtotal: total,
            total: total,
            paymentMethod: paymentMethod,
            status: status,
            userId: Value(userId),
            createdAt: DateFormatter.toEpochMillis(at),
          ),
        );
  }

  Future<void> insertItem({
    required int saleId,
    required int lineTotal,
    int? costPrice,
    double qty = 1,
  }) async {
    await db.into(db.saleItems).insert(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productName: 'Produk',
            unit: 'pcs',
            qty: qty,
            sellPrice: lineTotal,
            costPrice: Value(costPrice),
            lineTotal: lineTotal,
          ),
        );
  }

  group('getSalesSeries — bentuk deret', () {
    test('rentang 1 hari menghasilkan 24 batang per jam, termasuk jam kosong '
        '(AC-9.1 & AC-9.11)', () async {
      final day = DateTime(2026, 8, 12);
      await insertSale(at: DateTime(2026, 8, 12, 7, 30), total: 15000);
      await insertSale(at: DateTime(2026, 8, 12, 7, 45), total: 5000);
      await insertSale(at: DateTime(2026, 8, 12, 19, 10), total: 30000);

      final series = await repo.getSalesSeries(
        start: day,
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        bucket: SeriesBucket.hour,
      );

      expect(series, hasLength(24));
      expect(series.first.start, DateTime(2026, 8, 12));
      expect(series.last.start, DateTime(2026, 8, 12, 23));
      expect(series[7].omzet, 20000);
      expect(series[7].transactionCount, 2);
      expect(series[19].omzet, 30000);
      // Jam kosong TETAP hadir bernilai nol — bukan hilang dari deret.
      expect(series[0].omzet, 0);
      expect(series[0].transactionCount, 0);
    });

    test('rentang 7 hari menghasilkan 7 batang harian berurutan (AC-9.1)',
        () async {
      await insertSale(at: DateTime(2026, 8, 6, 9), total: 1000);
      await insertSale(at: DateTime(2026, 8, 12, 21), total: 2000);

      final series = await repo.getSalesSeries(
        start: DateTime(2026, 8, 6),
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        bucket: SeriesBucket.day,
      );

      expect(series, hasLength(7));
      expect(series.first.start, DateTime(2026, 8, 6));
      expect(series.last.start, DateTime(2026, 8, 12));
      expect(series.first.omzet, 1000);
      expect(series.last.omzet, 2000);
      expect(series[3].omzet, 0);
    });

    test('rentang 90 & 400 hari dikelompokkan per bulan (AC-9.1, K-9.4)',
        () async {
      await insertSale(at: DateTime(2026, 1, 15), total: 7000);
      await insertSale(at: DateTime(2026, 3, 20), total: 3000);

      final ninety = await repo.getSalesSeries(
        start: DateTime(2026),
        end: DateTime(2026, 3, 31, 23, 59, 59, 999),
        bucket: SeriesBucket.month,
      );
      expect(ninety, hasLength(3), reason: 'Januari, Februari, Maret');
      expect(ninety.first.omzet, 7000);
      expect(ninety[1].omzet, 0);
      expect(ninety.last.omzet, 3000);

      final fourHundred = await repo.getSalesSeries(
        start: DateTime(2026),
        end: DateTime(2027, 2, 4, 23, 59, 59, 999),
        bucket: SeriesBucket.month,
      );
      expect(fourHundred, hasLength(14));
      expect(fourHundred.last.start, DateTime(2027, 2));
      // K-9.4: batang tidak pernah membeludak walau rentangnya lebih dari
      // setahun.
      expect(fourHundred.length, lessThanOrEqualTo(90));
    });

    test('deret hanya berisi ember di dalam rentang — transaksi di luar '
        'rentang tidak bocor', () async {
      await insertSale(at: DateTime(2026, 8, 5, 12), total: 99999);
      await insertSale(at: DateTime(2026, 8, 13, 12), total: 88888);
      await insertSale(at: DateTime(2026, 8, 8, 12), total: 1000);

      final series = await repo.getSalesSeries(
        start: DateTime(2026, 8, 6),
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        bucket: SeriesBucket.day,
      );

      expect(series.fold<int>(0, (sum, p) => sum + p.omzet), 1000);
    });
  });

  group('getSalesSeries — kebenaran angka', () {
    test('jumlah seluruh batang SAMA PERSIS dengan omzet kartu ringkasan '
        '(AC-9.2)', () async {
      final start = DateTime(2026, 8, 1);
      final end = DateTime(2026, 8, 20, 23, 59, 59, 999);
      // Data yang cukup berantakan untuk menangkap salah kelompok:
      // beberapa hari kosong, beberapa hari padat, nominal ganjil.
      const totals = [12345, 7, 999999, 250, 84000, 31, 4200, 6, 77777];
      for (var i = 0; i < totals.length; i++) {
        await insertSale(
          at: DateTime(2026, 8, 1 + i * 2, 6 + i, 13 * i % 60),
          total: totals[i],
        );
      }

      final series =
          await repo.getSalesSeries(start: start, end: end, bucket: SeriesBucket.day);
      final summary = await repo.getSummary(start: start, end: end);

      expect(
        series.fold<int>(0, (sum, point) => sum + point.omzet),
        summary.totalOmzet,
      );
      expect(
        series.fold<int>(0, (sum, point) => sum + point.transactionCount),
        summary.transactionCount,
      );
      // Hitungan manual dari fixture, bukan hanya "sama dengan query lain".
      expect(summary.totalOmzet, totals.reduce((a, b) => a + b));
    });

    test('transaksi voided tidak menyumbang tinggi batang mana pun (AC-9.3)',
        () async {
      final day = DateTime(2026, 8, 12);
      await insertSale(at: DateTime(2026, 8, 12, 10), total: 10000);
      await insertSale(
        at: DateTime(2026, 8, 12, 10, 30),
        total: 500000,
        status: 'voided',
      );

      final series = await repo.getSalesSeries(
        start: day,
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        bucket: SeriesBucket.hour,
      );

      expect(series[10].omzet, 10000);
      expect(series[10].transactionCount, 1);
      expect(series.fold<int>(0, (sum, p) => sum + p.omzet), 10000);
    });

    test('transaksi hutang belum lunas IKUT dihitung — konsisten dengan '
        'kartu ringkasan yang hanya mengecualikan voided', () async {
      final day = DateTime(2026, 8, 12);
      await insertSale(
        at: DateTime(2026, 8, 12, 9),
        total: 25000,
        status: 'debt_unpaid',
        paymentMethod: 'debt',
      );

      final series = await repo.getSalesSeries(
        start: day,
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        bucket: SeriesBucket.hour,
      );
      final summary = await repo.getSummary(
        start: day,
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
      );

      expect(series[9].omzet, 25000);
      expect(series.fold<int>(0, (s, p) => s + p.omzet), summary.totalOmzet);
    });

    test('laba per ember memakai aturan yang sama dengan kartu ringkasan: '
        'item tanpa harga modal TIDAK dianggap modal nol', () async {
      final day = DateTime(2026, 8, 12);
      final withCost = await insertSale(at: DateTime(2026, 8, 12, 8), total: 10000);
      await insertItem(saleId: withCost, lineTotal: 10000, costPrice: 6000, qty: 1);

      final withoutCost = await insertSale(at: DateTime(2026, 8, 12, 9), total: 5000);
      await insertItem(saleId: withoutCost, lineTotal: 5000, qty: 1);

      final series = await repo.getSalesSeries(
        start: day,
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        bucket: SeriesBucket.hour,
      );
      final summary = await repo.getSummary(
        start: day,
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
      );

      expect(series[8].grossProfit, 4000, reason: '10000 - 6000 * 1');
      expect(series[9].grossProfit, 0, reason: 'tanpa harga modal → 0');
      expect(
        series.fold<int>(0, (sum, p) => sum + p.grossProfit),
        summary.grossProfit,
      );
    });

    test('laba tidak menggandakan omzet walau satu transaksi punya banyak '
        'item (jebakan JOIN)', () async {
      final day = DateTime(2026, 8, 12);
      final sale = await insertSale(at: DateTime(2026, 8, 12, 8), total: 30000);
      await insertItem(saleId: sale, lineTotal: 10000, costPrice: 6000);
      await insertItem(saleId: sale, lineTotal: 20000, costPrice: 11000);

      final series = await repo.getSalesSeries(
        start: day,
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        bucket: SeriesBucket.hour,
      );

      expect(series[8].omzet, 30000, reason: 'bukan 60000');
      expect(series[8].transactionCount, 1, reason: 'bukan 2');
      expect(series[8].grossProfit, 13000);
    });
  });

  group('filter kasir (AC-9.14)', () {
    setUp(() async {
      await db.into(db.users).insert(
            UsersCompanion.insert(
              name: 'Pemilik',
              role: 'owner',
              pinHash: 'h',
              pinSalt: 's',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db.into(db.users).insert(
            UsersCompanion.insert(
              name: 'Rina',
              role: 'cashier',
              pinHash: 'h',
              pinSalt: 's',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    });

    test('grafik & kartu ringkasan menyaring kasir yang sama', () async {
      final start = DateTime(2026, 8, 12);
      final end = DateTime(2026, 8, 12, 23, 59, 59, 999);
      await insertSale(at: DateTime(2026, 8, 12, 8), total: 10000, userId: 1);
      await insertSale(at: DateTime(2026, 8, 12, 9), total: 25000, userId: 2);
      await insertSale(at: DateTime(2026, 8, 12, 10), total: 5000, userId: 2);

      final all = await repo.getSalesSeries(
        start: start,
        end: end,
        bucket: SeriesBucket.hour,
      );
      final rina = await repo.getSalesSeries(
        start: start,
        end: end,
        bucket: SeriesBucket.hour,
        userId: 2,
      );
      final rinaSummary = await repo.getSummary(start: start, end: end, userId: 2);

      expect(all.fold<int>(0, (s, p) => s + p.omzet), 40000);
      expect(rina.fold<int>(0, (s, p) => s + p.omzet), rinaSummary.totalOmzet);
      expect(rinaSummary.totalOmzet, 30000);
      expect(rina[8].omzet, 0, reason: 'transaksi Pemilik tidak ikut');
    });

    test('jam ramai ikut tersaring per kasir', () async {
      await insertSale(at: DateTime(2026, 8, 12, 8), total: 10000, userId: 1);
      await insertSale(at: DateTime(2026, 8, 12, 17), total: 25000, userId: 2);

      final rina = await repo.getHourlyDistribution(
        start: DateTime(2026, 8, 12),
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
        userId: 2,
      );

      expect(rina[8].omzet, 0);
      expect(rina[17].omzet, 25000);
    });
  });

  group('getHourlyDistribution', () {
    test('selalu 24 baris jam 0–23 walau database kosong (AC-9.11)', () async {
      final hours = await repo.getHourlyDistribution(
        start: DateTime(2026, 8, 12),
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
      );

      expect(hours, hasLength(24));
      expect(hours.map((h) => h.hour).toList(), List.generate(24, (i) => i));
      expect(hours.every((h) => h.omzet == 0 && h.transactionCount == 0), isTrue);
    });

    test('mengagregasi jam yang sama dari BEBERAPA hari sekaligus '
        '(PRD §9.3.B: atas seluruh rentang, bukan satu hari)', () async {
      await insertSale(at: DateTime(2026, 8, 10, 17, 5), total: 10000);
      await insertSale(at: DateTime(2026, 8, 11, 17, 40), total: 20000);
      await insertSale(at: DateTime(2026, 8, 12, 17, 59), total: 30000);
      await insertSale(at: DateTime(2026, 8, 12, 6, 0), total: 1000);
      await insertSale(
        at: DateTime(2026, 8, 12, 17, 30),
        total: 999999,
        status: 'voided',
      );

      final hours = await repo.getHourlyDistribution(
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
      );

      expect(hours[17].omzet, 60000, reason: 'voided dikecualikan (AC-9.3)');
      expect(hours[17].transactionCount, 3);
      expect(hours[6].omzet, 1000);
      expect(hours[0].omzet, 0);
    });
  });

  group('batas hari mengikuti zona waktu perangkat (AC-9.4)', () {
    test('transaksi 23.30 waktu LOKAL masuk ke hari itu, bukan hari '
        'berikutnya', () async {
      // Dibangun sebagai DateTime LOKAL: apa pun zona waktu mesin yang
      // menjalankan test, 23.30 tanggal 12 harus jatuh di ember tanggal 12.
      await insertSale(at: DateTime(2026, 8, 12, 23, 30), total: 11000);
      await insertSale(at: DateTime(2026, 8, 13, 0, 15), total: 22000);

      final series = await repo.getSalesSeries(
        start: DateTime(2026, 8, 12),
        end: DateTime(2026, 8, 13, 23, 59, 59, 999),
        bucket: SeriesBucket.day,
      );

      expect(series, hasLength(2));
      expect(series[0].start, DateTime(2026, 8, 12));
      expect(series[0].omzet, 11000);
      expect(series[1].omzet, 22000);
    });

    test('jam 23 lokal tidak pernah tercatat sebagai jam lain', () async {
      await insertSale(at: DateTime(2026, 8, 12, 23, 30), total: 11000);

      final hours = await repo.getHourlyDistribution(
        start: DateTime(2026, 8, 12),
        end: DateTime(2026, 8, 12, 23, 59, 59, 999),
      );

      expect(hours[23].omzet, 11000);
      expect(hours.where((h) => h.omzet > 0), hasLength(1));
    });

    test('geseran zona yang disuntikkan SAMA PERSIS dengan modifier '
        "'localtime' untuk setiap baris (K-9.8)", () async {
      // K-9.8 mengganti `'localtime'` per baris dengan satu geseran angka
      // demi anggaran 300 ms AC-9.5. Yang membuat penggantian itu boleh
      // dilakukan adalah kesetaraan hasilnya — dan kesetaraan itu diperiksa
      // di sini, bukan diasumsikan.
      for (var i = 0; i < 400; i++) {
        // Setiap 3 jam sepanjang 50 hari: menyapu SELURUH jam dalam sehari,
        // termasuk jam-jam di sekitar tengah malam di zona mana pun.
        await insertSale(
          at: DateTime(2026, 6, 1).add(Duration(hours: i * 3)),
          total: 1000 + i,
        );
      }

      final offsetRow = await db.customSelect(
        "SELECT (strftime('%s', ?1 / 1000, 'unixepoch', 'localtime') - (?1 / 1000)) "
        'AS off FROM sales LIMIT 1',
        variables: [
          Variable.withInt(DateFormatter.toEpochMillis(DateTime(2026, 6, 1))),
        ],
      ).getSingle();
      final offsetMillis = offsetRow.read<int>('off') * 1000;

      for (final format in ['%Y-%m-%d %H', '%Y-%m-%d', '%Y-%m', '%H']) {
        final mismatch = await db.customSelect(
          'SELECT COUNT(*) AS diff FROM sales WHERE '
          "strftime('$format', created_at / 1000, 'unixepoch', 'localtime') != "
          "strftime('$format', (created_at + $offsetMillis) / 1000, 'unixepoch')",
        ).getSingle();
        expect(
          mismatch.read<int>('diff'),
          0,
          reason: "format '$format' harus identik antara localtime & geseran",
        );
      }
    });

    test('rumus pengelompokan benar untuk WIB (+7), WITA (+8) & WIT (+9)',
        () async {
      // Zona waktu proses test tidak bisa diubah dari dalam Dart, jadi
      // ketiga zona Indonesia diuji dengan menjalankan RUMUS YANG SAMA
      // memakai offset eksplisit sebagai pengganti `'localtime'`. Yang
      // dibuktikan di sini adalah bagian yang benar-benar rawan: konversi
      // `created_at / 1000` + `'unixepoch'` + geseran zona. Bahwa produksi
      // memakai `'localtime'` (yaitu offset perangkat) dijaga oleh dua
      // test di atas dan oleh test "SQL memuat 'localtime'" di bawah.
      //
      // 12 Agustus 2026 pukul 16.30 UTC =
      //   23.30 WIB (12 Agu) · 00.30 WITA (13 Agu) · 01.30 WIT (13 Agu).
      final moment = DateTime.utc(2026, 8, 12, 16, 30);
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              invoiceNumber: 'TZ-1',
              subtotal: 1000,
              total: 1000,
              paymentMethod: 'cash',
              status: 'completed',
              createdAt: moment.millisecondsSinceEpoch,
            ),
          );

      Future<String> keyAt(String offset) async {
        final row = await db.customSelect(
          "SELECT strftime('%Y-%m-%d %H', created_at / 1000, 'unixepoch', ?1) "
          'AS k FROM sales LIMIT 1',
          variables: [Variable.withString(offset)],
        ).getSingle();
        return row.read<String>('k');
      }

      expect(await keyAt('+7 hours'), '2026-08-12 23', reason: 'WIB');
      expect(await keyAt('+8 hours'), '2026-08-13 00', reason: 'WITA');
      expect(await keyAt('+9 hours'), '2026-08-13 01', reason: 'WIT');
      // Tanpa geseran zona sama sekali (UTC), tanggalnya memang berbeda —
      // inilah bug yang `'localtime'` cegah.
      expect(await keyAt('+0 hours'), '2026-08-12 16');
    });
  });

  test("query grafik WAJIB memakai 'localtime' & 'unixepoch' (AC-9.4)", () {
    // Gerbang, bukan uji perilaku: dua test perilaku di atas hanya
    // membedakan benar/salah bila mesin yang menjalankannya TIDAK berzona
    // UTC. Di CI berzona UTC keduanya lolos walau `'localtime'` dihapus —
    // dan cacatnya baru terlihat di HP pengguna, dalam bentuk angka
    // grafik yang beda dari kartu ringkasan.
    final source =
        File('lib/data/repositories/report_repository_impl.dart').readAsStringSync();
    expect(source, contains("'unixepoch'"));
    // Sejak K-9.8, `'localtime'` dipakai SEKALI untuk membaca geseran zona
    // perangkat (`_localOffsetMillis`) alih-alih per baris. Hilangnya kata
    // ini berarti zona perangkat tidak lagi dibaca sama sekali.
    expect(source, contains("'localtime'"));
    expect(source, contains('_localOffsetMillis'));
    expect(
      RegExp(r"strftime\('%H'").hasMatch(source),
      isTrue,
      reason: 'distribusi jam ramai memakai strftime, bukan hitung di Dart',
    );
  });

  test('index grafik idx_sales_status_created ada tanpa menaikkan '
      'schemaVersion (K-9.6)', () async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?1",
      variables: [Variable.withString('idx_sales_status_created')],
    ).get();

    expect(rows, hasLength(1));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 3);
  });
}
