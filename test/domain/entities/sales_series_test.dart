import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/domain/entities/sales_series.dart';

/// Aturan ember grafik tren (PRD v1.1 §9.3.A, AC-9.1) — diuji sebagai
/// fungsi murni, tanpa database maupun widget.
///
/// Aturan inilah yang menentukan berapa batang yang digambar; kalau ia
/// salah, seluruh grafik salah tanpa satu pun error yang terlihat.
void main() {
  group('SeriesBucket.dayCount', () {
    test('rentang "hari ini" (00:00 – 23:59:59.999) = 1 hari, bukan 0', () {
      final start = DateTime(2026, 8, 12);
      final end = DateTime(2026, 8, 12, 23, 59, 59, 999);
      expect(SeriesBucket.dayCount(start, end), 1);
    });

    test('7 hari terakhir termasuk hari ini = 7', () {
      expect(
        SeriesBucket.dayCount(DateTime(2026, 8, 6), DateTime(2026, 8, 12, 23, 59)),
        7,
      );
    });

    test('melintasi pergantian bulan & tahun dihitung kalender', () {
      expect(
        SeriesBucket.dayCount(DateTime(2025, 12, 30), DateTime(2026, 1, 2, 23, 59)),
        4,
      );
    });
  });

  group('SeriesBucket.forRange (AC-9.1)', () {
    test('1 hari → per jam', () {
      expect(
        SeriesBucket.forRange(
          DateTime(2026, 8, 12),
          DateTime(2026, 8, 12, 23, 59, 59, 999),
        ),
        SeriesBucket.hour,
      );
    });

    test('2 hari → per hari (batas bawah ember harian)', () {
      expect(
        SeriesBucket.forRange(
          DateTime(2026, 8, 11),
          DateTime(2026, 8, 12, 23, 59),
        ),
        SeriesBucket.day,
      );
    });

    test('7 hari → per hari', () {
      expect(
        SeriesBucket.forRange(DateTime(2026, 8, 6), DateTime(2026, 8, 12, 23, 59)),
        SeriesBucket.day,
      );
    });

    test('62 hari → masih per hari; 63 hari → sudah per bulan', () {
      final start = DateTime(2026, 1, 1);
      expect(
        SeriesBucket.forRange(start, DateTime(2026, 3, 3, 23, 59)),
        SeriesBucket.day,
        reason: '1 Jan – 3 Mar 2026 = 62 hari',
      );
      expect(
        SeriesBucket.forRange(start, DateTime(2026, 3, 4, 23, 59)),
        SeriesBucket.month,
        reason: '1 Jan – 4 Mar 2026 = 63 hari',
      );
    });

    test('90 hari & 400 hari → per bulan (K-9.4: tidak pernah > ~90 batang)', () {
      expect(
        SeriesBucket.forRange(DateTime(2026), DateTime(2026, 3, 31, 23, 59)),
        SeriesBucket.month,
      );
      expect(
        SeriesBucket.forRange(DateTime(2026), DateTime(2027, 2, 4, 23, 59)),
        SeriesBucket.month,
      );
    });
  });

  group('kunci & langkah ember', () {
    test('keyOf berformat sama persis dengan strftime SQLite', () {
      final moment = DateTime(2026, 8, 3, 7, 45);
      expect(SeriesBucket.hour.keyOf(moment), '2026-08-03 07');
      expect(SeriesBucket.day.keyOf(moment), '2026-08-03');
      expect(SeriesBucket.month.keyOf(moment), '2026-08');
    });

    test('floor memotong ke awal ember', () {
      final moment = DateTime(2026, 8, 3, 7, 45, 12, 345);
      expect(SeriesBucket.hour.floor(moment), DateTime(2026, 8, 3, 7));
      expect(SeriesBucket.day.floor(moment), DateTime(2026, 8, 3));
      expect(SeriesBucket.month.floor(moment), DateTime(2026, 8));
    });

    test('next melewati batas hari/bulan/tahun tanpa aritmetika tangan', () {
      expect(
        SeriesBucket.hour.next(DateTime(2026, 8, 3, 23)),
        DateTime(2026, 8, 4),
      );
      expect(
        SeriesBucket.day.next(DateTime(2026, 1, 31)),
        DateTime(2026, 2),
      );
      expect(
        SeriesBucket.month.next(DateTime(2026, 12)),
        DateTime(2027),
      );
    });
  });

  group('SalesPoint', () {
    test('valueOf memilih metrik sesuai peralih Omzet/Laba', () {
      final point = SalesPoint(
        bucket: SeriesBucket.day,
        start: DateTime(2026, 8, 3),
        omzet: 50000,
        grossProfit: 12000,
        transactionCount: 3,
      );
      expect(point.valueOf(profit: false), 50000);
      expect(point.valueOf(profit: true), 12000);
    });

    test('endExclusive adalah awal ember berikutnya', () {
      final point = SalesPoint(
        bucket: SeriesBucket.hour,
        start: DateTime(2026, 8, 3, 7),
        omzet: 0,
        grossProfit: 0,
        transactionCount: 0,
      );
      expect(point.endExclusive, DateTime(2026, 8, 3, 8));
    });
  });
}
